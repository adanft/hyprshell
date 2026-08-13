//! How a refusal reaches `BlueZ`.
//!
//! `BlueZ` treats these two differently, so collapsing them into one would change
//! behaviour: `Rejected` is a decision and ends the attempt, `Canceled` says the
//! exchange fell apart and the device may try again. Mapping a timeout to
//! `Rejected` would tell a phone it was turned down when nobody ever looked.

use crate::domain::model::Refusal;

#[derive(Debug, zbus::DBusError)]
#[zbus(prefix = "org.bluez.Error")]
pub enum AgentError {
    /// Required by the derive so transport failures keep their own identity.
    #[zbus(error)]
    ZBus(zbus::Error),
    Rejected(String),
    Canceled(String),
}

impl From<Refusal> for AgentError {
    fn from(refusal: Refusal) -> Self {
        let reason = refusal.to_string();
        match refusal {
            // A decision was made, or could not be made safely. Either way the
            // answer is no and BlueZ should stop asking.
            Refusal::Declined | Refusal::Unattended | Refusal::Mismatched => Self::Rejected(reason),
            // Nothing was decided. The exchange died on the way.
            Refusal::TimedOut | Refusal::Withdrawn => Self::Canceled(reason),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_decision_and_a_collapse_do_not_share_an_error() {
        assert!(matches!(
            AgentError::from(Refusal::Declined),
            AgentError::Rejected(_)
        ));
        assert!(matches!(
            AgentError::from(Refusal::TimedOut),
            AgentError::Canceled(_)
        ));
    }

    #[test]
    fn an_unattended_question_reads_as_a_refusal() {
        // The safe direction: nobody saw it, so nobody approved it.
        assert!(matches!(
            AgentError::from(Refusal::Unattended),
            AgentError::Rejected(_)
        ));
    }
}
