//! The use case: run one pairing exchange from question to answer.
//!
//! Everything this needs from the world arrives through the constructor as a
//! trait object, so the only things it can touch are the ones it was handed.
//! There is no global state, no singleton and no way for it to reach `BlueZ` or
//! a socket on its own.
//!
//! It does use `tokio` for the wait itself. That is a deliberate line: the
//! domain stays free of any runtime, while orchestrating a timeout without one
//! would mean reinventing it. What matters for coupling is that no adapter is
//! named here, and swapping the transport changes nothing in this file.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use tokio::sync::{Mutex, oneshot};

use crate::domain::model::{Answer, Device, Question, Refusal, Request, Token};
use crate::domain::ports::{AnswerSink, DeviceDirectory, Presenter, Tokens};

/// How long the device's own name is worth waiting for. Short, because this is
/// spent before the person sees anything and `BlueZ` is already holding its call.
const NAMING_PATIENCE: Duration = Duration::from_secs(2);

/// How long showing the question is allowed to take.
///
/// Showing happens before the patience timer starts, so a presenter that never
/// returns puts the whole exchange outside the limit this file exists to hold —
/// and `BlueZ` waits out every second of it with a method call still open. The
/// adapter bounds its own writing too, but the guarantee belongs here: the use
/// case must not depend on a transport being well behaved to keep its promise.
const SHOWING_PATIENCE: Duration = Duration::from_secs(10);

/// A question that has been shown and is waiting on a person.
struct Pending {
    /// Kept so a late or malformed answer can be checked against what was
    /// actually asked, rather than trusted because it carried a live token.
    question: Question,
    reply: oneshot::Sender<Answer>,
}

pub struct Coordinator {
    presenter: Arc<dyn Presenter>,
    directory: Arc<dyn DeviceDirectory>,
    tokens: Arc<dyn Tokens>,
    /// How long a person is given before the exchange is refused. `BlueZ` has a
    /// limit of its own, but relying on someone else's timeout to bound your
    /// own waiting is how a process ends up holding a reply forever.
    patience: Duration,
    waiting: Mutex<HashMap<Token, Pending>>,
    /// One token per device for the announcements that carry no answer, so a
    /// passkey being typed digit by digit updates a dialog in place instead of
    /// stacking six of them.
    announcements: Mutex<HashMap<String, Token>>,
}

impl Coordinator {
    pub fn new(
        presenter: Arc<dyn Presenter>,
        directory: Arc<dyn DeviceDirectory>,
        tokens: Arc<dyn Tokens>,
        patience: Duration,
    ) -> Self {
        Self {
            presenter,
            directory,
            tokens,
            patience,
            waiting: Mutex::new(HashMap::new()),
            announcements: Mutex::new(HashMap::new()),
        }
    }

    /// Ask, and wait for the answer.
    ///
    /// Every path out of here is a decision. There is no path that simply
    /// returns, because `BlueZ` is holding a method call open until this does.
    pub async fn ask(&self, device_path: &str, question: Question) -> Result<Answer, Refusal> {
        debug_assert!(
            question.expects_answer(),
            "announcements must go through `announce`, which holds no reply"
        );

        let token = self.tokens.next();
        let request = Request {
            token,
            device: self.named(device_path).await,
            question: question.clone(),
        };

        let (reply, answer) = oneshot::channel();
        self.waiting
            .lock()
            .await
            .insert(token, Pending { question, reply });

        // Shown before waited on, and refused the moment showing fails or
        // stalls: an unattended question is a refusal, never a silence. A
        // presenter that hangs is treated exactly like one that errored,
        // because to the person in front of the screen they are the same thing.
        if !matches!(
            tokio::time::timeout(SHOWING_PATIENCE, self.presenter.present(&request)).await,
            Ok(Ok(()))
        ) {
            self.waiting.lock().await.remove(&token);
            return Err(Refusal::Unattended);
        }

        match tokio::time::timeout(self.patience, answer).await {
            Ok(Ok(Answer::Reject)) => Err(Refusal::Declined),
            Ok(Ok(answer)) => Ok(answer),
            // The sender is dropped when the entry is removed, which is what
            // withdrawing looks like from this side.
            Ok(Err(_)) => Err(Refusal::Withdrawn),
            Err(_) => {
                self.waiting.lock().await.remove(&token);
                self.presenter.withdraw(token).await;
                Err(Refusal::TimedOut)
            }
        }
    }

    /// Show something `BlueZ` is not waiting on.
    ///
    /// Failure is not reported because there is nobody to report it to: `BlueZ`
    /// has already moved on, and refusing a pairing because a progress update
    /// could not be drawn would be absurd.
    pub async fn announce(&self, device_path: &str, question: Question) {
        debug_assert!(
            !question.expects_answer(),
            "a question with an answer must go through `ask`"
        );

        let token = {
            let mut announcements = self.announcements.lock().await;
            *announcements
                .entry(device_path.to_owned())
                .or_insert_with(|| self.tokens.next())
        };

        let request = Request {
            token,
            device: self.named(device_path).await,
            question,
        };
        let _ = self.presenter.present(&request).await;
    }

    /// The device's name, or its path if asking takes too long.
    ///
    /// The lookup runs before the question is shown and therefore before the
    /// patience timer starts, so an unbounded one puts the dialog beyond the
    /// limit this whole exchange claims to hold to. A label is never worth
    /// that: past the deadline the path is shown instead.
    async fn named(&self, device_path: &str) -> Device {
        tokio::time::timeout(NAMING_PATIENCE, self.directory.lookup(device_path))
            .await
            .unwrap_or_else(|_| Device::unnamed(device_path))
    }

    /// Deliver what a person decided.
    ///
    /// Unknown tokens are refused rather than ignored so the interface learns
    /// that its dialog is stale instead of believing it was applied.
    pub async fn answer(&self, token: Token, answer: Answer) -> Result<(), Refusal> {
        let mut waiting = self.waiting.lock().await;

        // Checked before it is taken. Removing first and validating afterwards
        // destroyed the exchange the refusal was meant to protect: the sender
        // went with the entry, the waiting `ask` saw a dropped channel and gave
        // up, and the answer the person actually meant could never land.
        let pending = waiting.get(&token).ok_or(Refusal::Withdrawn)?;
        if !pending.question.accepts(&answer) {
            return Err(Refusal::Mismatched);
        }

        let pending = waiting.remove(&token).ok_or(Refusal::Withdrawn)?;
        drop(waiting);
        pending.reply.send(answer).map_err(|_| Refusal::Withdrawn)
    }

    /// Take everything back.
    ///
    /// `BlueZ` calls Cancel when the other end gives up, and shutdown has to
    /// leave nothing on screen that can no longer be answered.
    pub async fn withdraw_all(&self) {
        let abandoned: Vec<Token> = {
            let mut waiting = self.waiting.lock().await;
            let tokens = waiting.keys().copied().collect();
            // Dropping the senders is what releases whoever is waiting in
            // `ask`, so this clear is the cancellation, not just bookkeeping.
            waiting.clear();
            tokens
        };
        let announced: Vec<Token> = {
            let mut announcements = self.announcements.lock().await;
            let tokens = announcements.values().copied().collect();
            announcements.clear();
            tokens
        };

        for token in abandoned.into_iter().chain(announced) {
            self.presenter.withdraw(token).await;
        }
    }
}

/// The way in, for anything that collects answers from a person. Implemented
/// here rather than depended on, so a transport can be written against the
/// trait and never learn that this type exists.
#[async_trait::async_trait]
impl AnswerSink for Coordinator {
    async fn answer(&self, token: Token, answer: Answer) -> Result<(), Refusal> {
        Self::answer(self, token, answer).await
    }

    async fn abandon(&self) {
        Self::withdraw_all(self).await;
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Mutex as StdMutex;
    use std::sync::atomic::{AtomicU64, Ordering};

    use async_trait::async_trait;

    use super::*;
    use crate::domain::model::{Device, Secret};
    use crate::domain::ports::Unattended;

    #[derive(Default)]
    struct SpyPresenter {
        shown: StdMutex<Vec<Request>>,
        withdrawn: StdMutex<Vec<Token>>,
        attached: bool,
    }

    impl SpyPresenter {
        fn attached() -> Arc<Self> {
            Arc::new(Self {
                attached: true,
                ..Self::default()
            })
        }

        fn detached() -> Arc<Self> {
            Arc::new(Self::default())
        }
    }

    #[async_trait]
    impl Presenter for SpyPresenter {
        async fn present(&self, request: &Request) -> Result<(), Unattended> {
            if !self.attached {
                return Err(Unattended);
            }
            self.shown.lock().unwrap().push(request.clone());
            Ok(())
        }

        async fn withdraw(&self, token: Token) {
            self.withdrawn.lock().unwrap().push(token);
        }
    }

    struct StubDirectory;

    #[async_trait]
    impl DeviceDirectory for StubDirectory {
        async fn lookup(&self, path: &str) -> Device {
            Device {
                path: path.to_owned(),
                name: "Pixel 7".to_owned(),
                address: "AA:BB:CC:DD:EE:FF".to_owned(),
            }
        }
    }

    #[derive(Default)]
    struct CountingTokens(AtomicU64);

    impl Tokens for CountingTokens {
        fn next(&self) -> Token {
            Token::new(self.0.fetch_add(1, Ordering::Relaxed))
        }
    }

    fn coordinator(presenter: Arc<SpyPresenter>, patience: Duration) -> Arc<Coordinator> {
        Arc::new(Coordinator::new(
            presenter,
            Arc::new(StubDirectory),
            Arc::new(CountingTokens::default()),
            patience,
        ))
    }

    #[tokio::test]
    async fn an_unattended_question_is_refused_at_once() {
        let coordinator = coordinator(SpyPresenter::detached(), Duration::from_secs(30));
        let outcome = coordinator
            .ask(
                "/org/bluez/hci0/dev_AA",
                Question::Confirm { passkey: 483_920 },
            )
            .await;
        assert_eq!(outcome, Err(Refusal::Unattended));
    }

    #[tokio::test]
    async fn an_accepted_confirmation_comes_back_as_an_answer() {
        let presenter = SpyPresenter::attached();
        let coordinator = coordinator(presenter.clone(), Duration::from_secs(30));
        let asking = {
            let coordinator = coordinator.clone();
            tokio::spawn(async move {
                coordinator
                    .ask("/dev_AA", Question::Confirm { passkey: 1 })
                    .await
            })
        };

        let token = loop {
            if let Some(request) = presenter.shown.lock().unwrap().first() {
                break request.token;
            }
            tokio::task::yield_now().await;
        };
        coordinator.answer(token, Answer::Accept).await.unwrap();

        assert_eq!(asking.await.unwrap(), Ok(Answer::Accept));
    }

    #[tokio::test]
    async fn a_declined_confirmation_is_a_refusal_not_an_answer() {
        let presenter = SpyPresenter::attached();
        let coordinator = coordinator(presenter.clone(), Duration::from_secs(30));
        let asking = {
            let coordinator = coordinator.clone();
            tokio::spawn(async move { coordinator.ask("/dev_AA", Question::Authorize).await })
        };

        let token = loop {
            if let Some(request) = presenter.shown.lock().unwrap().first() {
                break request.token;
            }
            tokio::task::yield_now().await;
        };
        coordinator.answer(token, Answer::Reject).await.unwrap();

        assert_eq!(asking.await.unwrap(), Err(Refusal::Declined));
    }

    #[tokio::test]
    async fn silence_becomes_a_timeout_and_the_dialog_is_taken_back() {
        let presenter = SpyPresenter::attached();
        let coordinator = coordinator(presenter.clone(), Duration::from_millis(20));
        let outcome = coordinator.ask("/dev_AA", Question::Authorize).await;

        assert_eq!(outcome, Err(Refusal::TimedOut));
        assert_eq!(presenter.withdrawn.lock().unwrap().len(), 1);
    }

    #[tokio::test]
    async fn an_answer_of_the_wrong_shape_is_rejected() {
        let presenter = SpyPresenter::attached();
        let coordinator = coordinator(presenter.clone(), Duration::from_secs(30));
        let asking = {
            let coordinator = coordinator.clone();
            tokio::spawn(async move {
                coordinator
                    .ask("/dev_AA", Question::Confirm { passkey: 1 })
                    .await
            })
        };

        let token = loop {
            if let Some(request) = presenter.shown.lock().unwrap().first() {
                break request.token;
            }
            tokio::task::yield_now().await;
        };

        assert_eq!(
            coordinator
                .answer(token, Answer::Pin(Secret::new("0000")))
                .await,
            Err(Refusal::Mismatched)
        );

        // And the exchange is still there to be answered properly. This is the
        // assertion the comment used to claim while the code did the opposite:
        // the refusal took the entry with it, so the real answer arrived at
        // nothing.
        coordinator.answer(token, Answer::Accept).await.unwrap();
        assert_eq!(asking.await.unwrap(), Ok(Answer::Accept));
    }

    #[tokio::test]
    async fn losing_the_interface_releases_whoever_is_waiting_at_once() {
        let presenter = SpyPresenter::attached();
        // Long enough that a passing test proves the release, not the timeout.
        let coordinator = coordinator(presenter.clone(), Duration::from_mins(10));
        let asking = {
            let coordinator = coordinator.clone();
            tokio::spawn(async move { coordinator.ask("/dev_AA", Question::Authorize).await })
        };

        while presenter.shown.lock().unwrap().is_empty() {
            tokio::task::yield_now().await;
        }
        AnswerSink::abandon(coordinator.as_ref()).await;

        assert_eq!(asking.await.unwrap(), Err(Refusal::Withdrawn));
    }

    #[tokio::test]
    async fn a_name_that_never_arrives_does_not_hold_the_question_back() {
        struct SilentDirectory;

        #[async_trait]
        impl DeviceDirectory for SilentDirectory {
            async fn lookup(&self, _path: &str) -> Device {
                // Longer than any patience a person would sit through, standing
                // in for a BlueZ that has stopped answering.
                tokio::time::sleep(Duration::from_hours(1)).await;
                unreachable!()
            }
        }

        let presenter = SpyPresenter::attached();
        let coordinator = Arc::new(Coordinator::new(
            presenter.clone(),
            Arc::new(SilentDirectory),
            Arc::new(CountingTokens::default()),
            Duration::from_mins(10),
        ));

        let asking = {
            let coordinator = coordinator.clone();
            tokio::spawn(async move { coordinator.ask("/dev_AA", Question::Authorize).await })
        };

        // Shown well inside the naming deadline, carrying the path as its label
        // rather than waiting on a name that is never coming.
        tokio::time::timeout(Duration::from_secs(10), async {
            while presenter.shown.lock().unwrap().is_empty() {
                tokio::task::yield_now().await;
            }
        })
        .await
        .expect("the question must be shown without the name");

        assert_eq!(presenter.shown.lock().unwrap()[0].device.name, "dev_AA");
        asking.abort();
    }

    #[tokio::test]
    async fn a_presenter_that_never_returns_does_not_hold_bluez_open() {
        struct StalledPresenter;

        #[async_trait]
        impl Presenter for StalledPresenter {
            async fn present(&self, _request: &Request) -> Result<(), Unattended> {
                // A shell that is connected but has stopped reading: no error
                // ever arrives, so without a bound of our own this never ends.
                tokio::time::sleep(Duration::from_hours(1)).await;
                unreachable!()
            }

            async fn withdraw(&self, _token: Token) {}
        }

        let coordinator = Arc::new(Coordinator::new(
            Arc::new(StalledPresenter),
            Arc::new(StubDirectory),
            Arc::new(CountingTokens::default()),
            Duration::from_mins(10),
        ));

        // Well inside the patience the exchange claims, so a pass proves the
        // showing deadline fired rather than the answering one.
        let outcome = tokio::time::timeout(
            Duration::from_mins(1),
            coordinator.ask("/dev_AA", Question::Authorize),
        )
        .await
        .expect("showing must be bounded, or BlueZ waits forever");

        assert_eq!(outcome, Err(Refusal::Unattended));
    }

    #[tokio::test]
    async fn an_unknown_token_is_refused() {
        let coordinator = coordinator(SpyPresenter::attached(), Duration::from_secs(30));
        assert_eq!(
            coordinator.answer(Token::new(404), Answer::Accept).await,
            Err(Refusal::Withdrawn)
        );
    }

    #[tokio::test]
    async fn repeated_announcements_for_one_device_reuse_a_token() {
        let presenter = SpyPresenter::attached();
        let coordinator = coordinator(presenter.clone(), Duration::from_secs(30));

        for entered in 0..3u16 {
            coordinator
                .announce(
                    "/dev_AA",
                    Question::DisplayPasskey {
                        passkey: 483_920,
                        entered,
                    },
                )
                .await;
        }

        let shown = presenter.shown.lock().unwrap();
        assert_eq!(shown.len(), 3);
        assert_eq!(
            shown[0].token, shown[2].token,
            "the dialog must be replaced"
        );
    }

    #[tokio::test]
    async fn withdrawing_releases_whoever_is_waiting() {
        let presenter = SpyPresenter::attached();
        let coordinator = coordinator(presenter.clone(), Duration::from_secs(30));
        let asking = {
            let coordinator = coordinator.clone();
            tokio::spawn(async move { coordinator.ask("/dev_AA", Question::Authorize).await })
        };

        while presenter.shown.lock().unwrap().is_empty() {
            tokio::task::yield_now().await;
        }
        coordinator.withdraw_all().await;

        assert_eq!(asking.await.unwrap(), Err(Refusal::Withdrawn));
    }
}
