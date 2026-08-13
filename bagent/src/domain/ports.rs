//! What the use case needs from the world, stated as traits it owns.
//!
//! These live beside the model rather than beside the adapters on purpose. The
//! adapters depend on this file; this file depends on nothing. That is the only
//! reason a QML overlay, a terminal prompt and a test double are
//! interchangeable without the use case noticing.

use async_trait::async_trait;

use super::model::{Answer, Device, Refusal, Request, Token};

/// The way in: what a transport is allowed to do to a running exchange.
///
/// Stated as a trait so the socket never holds the use case itself. Without it
/// the two would have to know each other — the use case needs a presenter, the
/// presenter's transport needs somewhere to deliver answers — and that circle
/// is what usually ends with everything in one file.
#[async_trait]
pub trait AnswerSink: Send + Sync {
    async fn answer(&self, token: Token, answer: Answer) -> Result<(), Refusal>;

    /// The interface is gone, and everything waiting on it is now unanswerable.
    ///
    /// Without this the transport can only fall silent, and silence is
    /// indistinguishable from a person who has not decided yet — so a question
    /// nobody can reach would sit out its whole patience before `BlueZ` heard
    /// anything. Losing the interface is knowledge, and it should travel.
    async fn abandon(&self);
}

/// Something that can put a question in front of a person.
#[async_trait]
pub trait Presenter: Send + Sync {
    /// Show it.
    ///
    /// The error is not incidental: it is how the use case learns that nobody
    /// is watching, which it must treat as a refusal rather than a delay. An
    /// agent that stays silent when the interface is gone leaves `BlueZ` waiting
    /// and the pairing hanging.
    async fn present(&self, request: &Request) -> Result<(), Unattended>;

    /// Take it back, because `BlueZ` withdrew it or it ran out of time. Showing
    /// a dialog whose answer can no longer be delivered is worse than showing
    /// nothing, so this is not optional.
    async fn withdraw(&self, token: Token);
}

/// Nobody was there to see the question.
#[derive(Debug, Clone, Copy, PartialEq, Eq, thiserror::Error)]
#[error("no interface is attached")]
pub struct Unattended;

/// Turns a `BlueZ` object path into a name worth showing.
///
/// Kept separate from `Presenter` because the two change for unrelated reasons:
/// one follows the interface, the other follows `BlueZ`. Folding them together
/// would make a change of dialog toolkit touch the D-Bus code.
#[async_trait]
pub trait DeviceDirectory: Send + Sync {
    /// Never fails. A lookup that cannot reach `BlueZ` still has to produce
    /// something to display, and refusing the pairing because a name could not
    /// be read would be a poor trade.
    async fn lookup(&self, path: &str) -> Device;
}

/// Hands out tokens.
///
/// A trait rather than a counter so a test can hand out predictable tokens and
/// assert on them without reaching into the use case's state.
pub trait Tokens: Send + Sync {
    fn next(&self) -> Token;
}
