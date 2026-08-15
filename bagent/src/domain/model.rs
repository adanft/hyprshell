//! The vocabulary of a pairing exchange.
//!
//! Nothing here knows about D-Bus, sockets, JSON or an async runtime. That is
//! the point: these types are what the rest of the program argues about, so
//! they must not drag a transport in with them.

use std::fmt;

/// Identifies one in-flight exchange.
///
/// The token is what the interface sends back with an answer, so a late reply
/// to a question that has already been withdrawn can be recognized and dropped
/// instead of being applied to whatever came next.
#[derive(Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Debug)]
pub struct Token(u64);

impl Token {
    pub const fn new(value: u64) -> Self {
        Self(value)
    }

    pub const fn value(self) -> u64 {
        self.0
    }
}

impl fmt::Display for Token {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}", self.0)
    }
}

/// A value that must never reach a log.
///
/// This exists because the shape of the bug it prevents is easy to write by
/// accident: a PIN passed to a formatter reads exactly like any other string.
/// `Debug` redacts, so `{:?}` on a whole request is safe, and the plain text is
/// reachable only through `expose`, which is one grep away from an audit.
#[derive(Clone, PartialEq, Eq)]
pub struct Secret(String);

impl Secret {
    pub fn new(value: impl Into<String>) -> Self {
        Self(value.into())
    }

    pub fn expose(&self) -> &str {
        &self.0
    }
}

impl fmt::Debug for Secret {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("<redacted>")
    }
}

/// Who is asking, in terms worth putting in front of a person.
///
/// `BlueZ` identifies a device by object path, which is meaningless to a human.
/// The name is resolved before the question is ever presented so that the
/// interface never has to know what an object path is.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Device {
    pub path: String,
    pub name: String,
    pub address: String,
}

impl Device {
    /// The fallback when `BlueZ` knows nothing but the path yet. An address is a
    /// poor label but it is honest, and it is never empty.
    pub fn unnamed(path: impl Into<String>) -> Self {
        let path = path.into();
        Self {
            name: path.rsplit('/').next().unwrap_or(&path).to_owned(),
            address: String::new(),
            path,
        }
    }
}

/// What `BlueZ` needs a person to settle.
///
/// One variant per `org.bluez.Agent1` method that involves a human. `Release`
/// and `Cancel` are lifecycle, not questions, so they are absent by design.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Question {
    /// A PIN chosen here and typed on the device. The answer carries it.
    PinCode,
    /// A passkey chosen here and typed on the device. The answer carries it.
    Passkey,
    /// A PIN chosen by `BlueZ`, shown here, typed on the device. Nothing is
    /// waiting on it: `BlueZ` takes it back with Cancel once the device is done.
    DisplayPinCode { pin: Secret },
    /// A passkey chosen by `BlueZ`, shown here, typed on the device. `entered`
    /// counts the digits already accepted there, so this arrives repeatedly for
    /// a single pairing and each arrival supersedes the last.
    DisplayPasskey { passkey: u32, entered: u16 },
    /// Both ends show the same six digits and a person says whether they match.
    /// This is what a modern phone asks for.
    Confirm { passkey: u32 },
    /// An incoming pairing with nothing to compare against.
    Authorize,
    /// One service on a device that is already paired.
    AuthorizeService { uuid: String },
}

impl Question {
    /// Whether `BlueZ` is waiting on the answer.
    ///
    /// The two display methods are the exceptions the spec carves out. Both
    /// return void: the agent shows the code, and `BlueZ` calls Cancel when it
    /// should stop being shown. Neither has anything a person could agree to.
    ///
    /// Treating `DisplayPinCode` as answerable was a real bug, not a nicety.
    /// The interface drew it with no Accept — correctly, there is nothing to
    /// accept — while this side held the D-Bus call open waiting for one, so a
    /// PIN pairing could only ever end in a two-minute timeout.
    pub const fn expects_answer(&self) -> bool {
        !matches!(
            self,
            Self::DisplayPasskey { .. } | Self::DisplayPinCode { .. }
        )
    }

    /// The shape of answer this question can accept, so a reply of the wrong
    /// kind is refused where the rule lives rather than at the transport.
    ///
    /// The display variants are absent because they are unanswerable by the
    /// rule above, and listing them here would say otherwise.
    pub const fn accepts(&self, answer: &Answer) -> bool {
        matches!(
            (self, answer),
            // No is always a valid answer to anything.
            (_, Answer::Reject)
                | (Self::PinCode, Answer::Pin(_))
                | (Self::Passkey, Answer::Passkey(_))
                | (
                    Self::Confirm { .. } | Self::Authorize | Self::AuthorizeService { .. },
                    Answer::Accept,
                )
        )
    }
}

/// One question, addressed, with the token its answer must carry.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Request {
    pub token: Token,
    pub device: Device,
    pub question: Question,
}

/// What a person decided.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Answer {
    /// Yes, for the questions that need nothing else.
    Accept,
    /// Yes, with the PIN that was typed.
    Pin(Secret),
    /// Yes, with the passkey that was typed.
    Passkey(u32),
    /// No.
    Reject,
}

/// Why an exchange produced no usable answer.
///
/// Every variant here has to become a specific D-Bus error, because `BlueZ`
/// behaves differently for a refusal than for a timeout. Collapsing them would
/// make a device that was never offered look like one that was turned down.
#[derive(Clone, Debug, PartialEq, Eq, thiserror::Error)]
pub enum Refusal {
    /// No interface was listening, so the question was never seen. Answering
    /// anything else here would approve a pairing nobody was shown.
    #[error("no interface is listening")]
    Unattended,
    /// It was shown and nobody answered in time.
    #[error("no answer within the allowed time")]
    TimedOut,
    /// `BlueZ` or the interface took it back before it was answered.
    #[error("withdrawn before it was answered")]
    Withdrawn,
    /// A person said no.
    #[error("declined")]
    Declined,
    /// An answer arrived that this question cannot use, such as a PIN offered
    /// to a yes-or-no confirmation.
    #[error("answer does not fit the question")]
    Mismatched,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn secret_is_redacted_by_debug() {
        let formatted = format!("{:?}", Secret::new("1234"));
        assert_eq!(formatted, "<redacted>");
        assert!(!formatted.contains("1234"));
    }

    #[test]
    fn a_whole_request_can_be_logged_without_leaking() {
        let request = Request {
            token: Token::new(7),
            device: Device::unnamed("/org/bluez/hci0/dev_AA"),
            question: Question::DisplayPinCode {
                pin: Secret::new("867530"),
            },
        };
        assert!(!format!("{request:?}").contains("867530"));
    }

    #[test]
    fn the_two_display_questions_are_unanswered() {
        assert!(
            !Question::DisplayPasskey {
                passkey: 1,
                entered: 0
            }
            .expects_answer()
        );
        // Showing a PIN is an announcement too. Holding this one open is what
        // made a PIN pairing wait out its whole patience for an Accept the
        // interface had no reason to draw.
        assert!(
            !Question::DisplayPinCode {
                pin: Secret::new("0000")
            }
            .expects_answer()
        );
        assert!(Question::Confirm { passkey: 1 }.expects_answer());
        assert!(Question::PinCode.expects_answer());
        assert!(Question::Authorize.expects_answer());
    }

    #[test]
    fn a_question_refuses_an_answer_of_the_wrong_shape() {
        assert!(!Question::Confirm { passkey: 1 }.accepts(&Answer::Pin(Secret::new("0"))));
        assert!(!Question::PinCode.accepts(&Answer::Accept));
        assert!(Question::PinCode.accepts(&Answer::Pin(Secret::new("0"))));
        assert!(Question::Confirm { passkey: 1 }.accepts(&Answer::Accept));
    }

    #[test]
    fn every_question_can_be_refused() {
        for question in [
            Question::PinCode,
            Question::Passkey,
            Question::Confirm { passkey: 1 },
            Question::Authorize,
        ] {
            assert!(question.accepts(&Answer::Reject));
        }
    }

    #[test]
    fn an_unnamed_device_still_has_something_to_show() {
        let device = Device::unnamed("/org/bluez/hci0/dev_AA_BB");
        assert_eq!(device.name, "dev_AA_BB");
        assert!(!device.name.is_empty());
    }
}
