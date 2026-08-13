//! The wire.
//!
//! These types exist so the domain never has to care what JSON looks like. They
//! are a translation, not a re-export: renaming a field here is a protocol
//! decision and must not be able to reach in and rename a domain concept, and a
//! domain type gaining a field must not silently appear on the wire.
//!
//! One JSON object per line, in both directions. A line is a message, which is
//! all the framing this needs and is trivial to consume from QML.

use serde::{Deserialize, Serialize};

use crate::domain::model::{Answer, Device, Question, Request, Secret, Token};

#[derive(Serialize)]
pub struct DeviceView {
    pub name: String,
    pub address: String,
}

impl From<&Device> for DeviceView {
    fn from(device: &Device) -> Self {
        Self {
            name: device.name.clone(),
            address: device.address.clone(),
        }
    }
}

/// What the interface is being asked to draw.
///
/// The variant names are the contract with the QML side, so they are spelled
/// out rather than derived from the Rust identifiers.
#[derive(Serialize)]
#[serde(tag = "kind")]
pub enum QuestionView {
    /// Ask for a PIN and send it back.
    #[serde(rename = "request-pin")]
    RequestPin,
    /// Ask for a passkey and send it back.
    #[serde(rename = "request-passkey")]
    RequestPasskey,
    /// Show this PIN; it is typed on the other device.
    #[serde(rename = "display-pin")]
    DisplayPin { pin: String },
    /// Show this passkey. `entered` is how many digits have landed on the other
    /// device, so a redraw with the same token replaces the dialog.
    #[serde(rename = "display-passkey")]
    DisplayPasskey { passkey: u32, entered: u16 },
    /// Show the code and ask whether it matches.
    #[serde(rename = "confirm")]
    Confirm { passkey: u32 },
    /// Ask whether to allow the pairing at all.
    #[serde(rename = "authorize")]
    Authorize,
    /// Ask whether to allow one service.
    #[serde(rename = "authorize-service")]
    AuthorizeService { uuid: String },
}

impl From<&Question> for QuestionView {
    fn from(question: &Question) -> Self {
        match question {
            Question::PinCode => Self::RequestPin,
            Question::Passkey => Self::RequestPasskey,
            // The one deliberate exposure: this PIN exists to be read aloud off
            // the screen, so it has to cross the wire in the clear.
            Question::DisplayPinCode { pin } => Self::DisplayPin {
                pin: pin.expose().to_owned(),
            },
            Question::DisplayPasskey { passkey, entered } => Self::DisplayPasskey {
                passkey: *passkey,
                entered: *entered,
            },
            Question::Confirm { passkey } => Self::Confirm { passkey: *passkey },
            Question::Authorize => Self::Authorize,
            Question::AuthorizeService { uuid } => Self::AuthorizeService { uuid: uuid.clone() },
        }
    }
}

/// Agent to interface.
#[derive(Serialize)]
#[serde(tag = "event")]
pub enum Event {
    /// Draw this.
    #[serde(rename = "ask")]
    Ask {
        token: u64,
        device: DeviceView,
        #[serde(flatten)]
        question: QuestionView,
    },
    /// Stop drawing it: it timed out, or `BlueZ` took it back.
    #[serde(rename = "withdraw")]
    Withdraw { token: u64 },
}

impl Event {
    pub fn ask(request: &Request) -> Self {
        Self::Ask {
            token: request.token.value(),
            device: DeviceView::from(&request.device),
            question: QuestionView::from(&request.question),
        }
    }

    pub const fn withdraw(token: Token) -> Self {
        Self::Withdraw {
            token: token.value(),
        }
    }
}

/// Interface to agent.
///
/// The command is the decision rather than carrying one, which keeps the line
/// flat. That is not only tidier to write from QML: `deny_unknown_fields` and
/// `flatten` do not work together in serde, so a nested decision would have had
/// to give up the typo check that makes a mistake in the shell loud instead of
/// silently ignored.
#[derive(Deserialize)]
#[serde(tag = "command", rename_all = "kebab-case", deny_unknown_fields)]
pub enum Command {
    /// Yes, for a question that needs nothing else.
    Accept { token: u64 },
    /// No.
    Reject { token: u64 },
    /// Yes, with the PIN that was typed here.
    Pin { token: u64, pin: String },
    /// Yes, with the passkey that was typed here.
    Passkey { token: u64, passkey: u32 },
}

impl Command {
    pub const fn token(&self) -> Token {
        let raw = match self {
            Self::Accept { token }
            | Self::Reject { token }
            | Self::Pin { token, .. }
            | Self::Passkey { token, .. } => *token,
        };
        Token::new(raw)
    }
}

impl From<Command> for Answer {
    fn from(command: Command) -> Self {
        match command {
            Command::Accept { .. } => Self::Accept,
            Command::Reject { .. } => Self::Reject,
            Command::Pin { pin, .. } => Self::Pin(Secret::new(pin)),
            Command::Passkey { passkey, .. } => Self::Passkey(passkey),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::model::Token;

    fn request(question: Question) -> Request {
        Request {
            token: Token::new(42),
            device: Device {
                path: "/org/bluez/hci0/dev_AA".into(),
                name: "Pixel 7".into(),
                address: "AA:BB:CC:DD:EE:FF".into(),
            },
            question,
        }
    }

    #[test]
    fn a_confirmation_carries_the_code_and_the_token() {
        let line = serde_json::to_string(&Event::ask(&request(Question::Confirm {
            passkey: 483_920,
        })))
        .unwrap();
        assert!(line.contains(r#""event":"ask""#));
        assert!(line.contains(r#""kind":"confirm""#));
        assert!(line.contains(r#""passkey":483920"#));
        assert!(line.contains(r#""token":42"#));
        assert!(line.contains("Pixel 7"));
    }

    #[test]
    fn the_object_path_never_reaches_the_interface() {
        let line = serde_json::to_string(&Event::ask(&request(Question::Authorize))).unwrap();
        assert!(!line.contains("/org/bluez"));
    }

    #[test]
    fn an_event_is_a_single_line() {
        let line = serde_json::to_string(&Event::ask(&request(Question::Authorize))).unwrap();
        assert!(!line.contains('\n'), "line framing would break");
    }

    #[test]
    fn an_accept_parses_into_an_answer() {
        let command: Command = serde_json::from_str(r#"{"command":"accept","token":42}"#).unwrap();
        assert_eq!(command.token(), Token::new(42));
        assert_eq!(Answer::from(command), Answer::Accept);
    }

    #[test]
    fn a_pin_parses_into_a_secret() {
        let command: Command =
            serde_json::from_str(r#"{"command":"pin","token":1,"pin":"0000"}"#).unwrap();
        assert_eq!(command.token(), Token::new(1));
        assert_eq!(Answer::from(command), Answer::Pin(Secret::new("0000")));
    }

    #[test]
    fn every_decision_survives_the_trip() {
        for (line, expected) in [
            (r#"{"command":"reject","token":1}"#, Answer::Reject),
            (
                r#"{"command":"passkey","token":1,"passkey":483920}"#,
                Answer::Passkey(483_920),
            ),
        ] {
            let command: Command = serde_json::from_str(line).unwrap();
            assert_eq!(Answer::from(command), expected);
        }
    }

    #[test]
    fn an_unknown_field_is_a_failure_rather_than_a_shrug() {
        // The check that flatten would have cost: a typo in the shell has to be
        // loud, not silently dropped while the dialog waits forever.
        let parsed: Result<Command, _> =
            serde_json::from_str(r#"{"command":"accept","token":1,"typo":true}"#);
        assert!(parsed.is_err());
    }

    #[test]
    fn an_unknown_command_is_refused() {
        let parsed: Result<Command, _> =
            serde_json::from_str(r#"{"command":"approve-everything","token":1}"#);
        assert!(parsed.is_err());
    }
}
