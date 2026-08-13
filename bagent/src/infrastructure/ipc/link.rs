//! The line to the shell.
//!
//! The agent is the client and the shell is the server, which is the way round
//! it has to be. The shell is the long-lived thing: it owns the screen, it
//! starts with the session and it is still there when this process is
//! restarted. An agent that listened would force the shell to poll a socket
//! that may never appear, and to log a failure every time it tried.
//!
//! It also makes "is anyone watching?" exact rather than inferred. A dropped
//! connection is the shell going away, observed rather than guessed, and that
//! is the signal the whole fail-closed rule rests on.

use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tokio::net::unix::OwnedWriteHalf;
use tokio::sync::Mutex;

use super::protocol::{Command, Event};
use crate::domain::model::{Answer, Request, Token};
use crate::domain::ports::{AnswerSink, Presenter, Unattended};

/// Long enough that a shell which is not running does not cost a connect
/// attempt every frame, short enough that starting the shell does not leave
/// pairing broken for a noticeable while.
const RETRY: Duration = Duration::from_secs(2);

/// How long a shell gets to accept one line before it counts as gone.
///
/// A shell that has died drops the connection and the write fails at once, but
/// a shell that is merely wedged — a stalled event loop, a socket buffer nobody
/// is draining — leaves the write pending with no error and no end. That is the
/// worse case of the two: the connection still looks alive, so nothing else
/// notices, and the write is holding the one lock every other question needs.
/// A line of JSON is a few hundred bytes, so anything past this is not slowness.
const WRITE_PATIENCE: Duration = Duration::from_secs(5);

pub struct ShellLink {
    path: PathBuf,
    /// `None` whenever no shell is attached, which is exactly the condition
    /// `present` has to refuse on.
    writer: Mutex<Option<OwnedWriteHalf>>,
}

impl ShellLink {
    pub fn new(path: PathBuf) -> Self {
        Self {
            path,
            writer: Mutex::new(None),
        }
    }

    /// Stay attached for as long as the process lives.
    ///
    /// Never returns. Each connection is read to its end, and the end is a
    /// shell that closed or died — neither of which is an error worth stopping
    /// for, because the next one may be seconds away.
    pub async fn run(self: Arc<Self>, sink: Arc<dyn AnswerSink>) -> ! {
        loop {
            match UnixStream::connect(&self.path).await {
                Ok(stream) => {
                    tracing::info!(path = %self.path.display(), "shell attached");
                    self.serve(stream, sink.clone()).await;
                    tracing::info!("shell detached");
                }
                Err(error) => {
                    // Ordinary: the shell is simply not up yet. Reported once
                    // per attempt at debug so a genuinely broken path can still
                    // be found, without a warning every two seconds.
                    tracing::debug!(%error, path = %self.path.display(), "no shell to attach to");
                }
            }
            tokio::time::sleep(RETRY).await;
        }
    }

    async fn serve(&self, stream: UnixStream, sink: Arc<dyn AnswerSink>) {
        let (reader, writer) = stream.into_split();
        *self.writer.lock().await = Some(writer);

        let mut lines = BufReader::new(reader).lines();
        while let Ok(Some(line)) = lines.next_line().await {
            if line.trim().is_empty() {
                continue;
            }
            match serde_json::from_str::<Command>(&line) {
                Ok(command) => {
                    let token = command.token();
                    if let Err(refusal) = sink.answer(token, Answer::from(command)).await {
                        // Routine: a dialog answered after BlueZ gave up.
                        tracing::debug!(%token, %refusal, "answer not applied");
                    }
                }
                // The line is never echoed back. It may carry a PIN, and a
                // malformed one is exactly where quoting it would be tempting.
                Err(error) => tracing::warn!(%error, "unparseable command"),
            }
        }

        // Whoever is waiting on an answer will now be refused rather than left
        // hanging, because `present` starts failing the moment this clears.
        *self.writer.lock().await = None;

        // And told so at once. Clearing the writer only stops new questions
        // reaching a shell that is gone; the ones already asked would otherwise
        // wait out their full patience for an answer that can no longer come,
        // holding BlueZ's call open the whole time for nothing.
        sink.abandon().await;
    }

    async fn send(&self, event: &Event) -> Result<(), Unattended> {
        let line = serde_json::to_string(event).map_err(|error| {
            tracing::error!(%error, "an event could not be encoded");
            Unattended
        })?;

        let mut guard = self.writer.lock().await;
        let writer = guard.as_mut().ok_or(Unattended)?;
        let framed = format!("{line}\n");
        match tokio::time::timeout(WRITE_PATIENCE, writer.write_all(framed.as_bytes())).await {
            Ok(Ok(())) => Ok(()),
            Ok(Err(error)) => {
                // A write that fails is a shell that has gone without the read
                // side noticing yet. Clearing here keeps the two halves from
                // disagreeing about whether anyone is attached.
                tracing::debug!(%error, "write failed; treating the shell as gone");
                *guard = None;
                Err(Unattended)
            }
            Err(_) => {
                // Still connected, still not reading. Unattended is the honest
                // answer — the question cannot be put in front of anyone — and
                // clearing the writer releases the lock for whatever comes next
                // instead of queueing it behind a shell that has stopped.
                tracing::warn!("the shell stopped reading; treating it as gone");
                *guard = None;
                Err(Unattended)
            }
        }
    }
}

#[async_trait]
impl Presenter for ShellLink {
    async fn present(&self, request: &Request) -> Result<(), Unattended> {
        self.send(&Event::ask(request)).await
    }

    async fn withdraw(&self, token: Token) {
        // Nobody attached means nothing to take back.
        let _ = self.send(&Event::withdraw(token)).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::model::{Device, Question, Request, Token};

    fn request() -> Request {
        Request {
            token: Token::new(1),
            device: Device::unnamed("/dev_AA"),
            question: Question::Confirm { passkey: 1 },
        }
    }

    #[tokio::test]
    async fn presenting_with_no_shell_attached_reports_it() {
        let link = ShellLink::new(PathBuf::from("/nonexistent/bagent.sock"));
        assert_eq!(link.present(&request()).await, Err(Unattended));
    }

    #[tokio::test]
    async fn withdrawing_with_no_shell_attached_is_silent() {
        let link = ShellLink::new(PathBuf::from("/nonexistent/bagent.sock"));
        link.withdraw(Token::new(1)).await;
    }
}
