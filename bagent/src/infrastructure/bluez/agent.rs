//! The `org.bluez.Agent1` object.
//!
//! This is a translation layer and nothing else. Every method turns D-Bus
//! arguments into a `Question`, hands it to the use case, and turns the outcome
//! back into a D-Bus reply. There is no policy here — no timeout, no decision
//! about what an unattended question means — because that belongs where it can
//! be tested without a bus.
//!
//! The interface XML is generated from these signatures by the macro, so it
//! cannot drift from the implementation the way a hand-written copy can.

use std::sync::Arc;

use zbus::zvariant::OwnedObjectPath;

use super::errors::AgentError;
use crate::application::coordinator::Coordinator;
use crate::domain::model::{Answer, Question, Secret};

pub struct Agent {
    coordinator: Arc<Coordinator>,
}

impl Agent {
    pub fn new(coordinator: Arc<Coordinator>) -> Self {
        Self { coordinator }
    }

    /// Every answered method funnels through here so the mapping from an
    /// `Answer` back to a D-Bus reply exists once.
    async fn ask(
        &self,
        device: &OwnedObjectPath,
        question: Question,
    ) -> Result<Answer, AgentError> {
        self.coordinator
            .ask(device.as_str(), question)
            .await
            .map_err(AgentError::from)
    }
}

#[zbus::interface(name = "org.bluez.Agent1")]
impl Agent {
    /// `BlueZ` is done with this agent. Anything still on screen can no longer be
    /// answered, so it goes.
    async fn release(&self) {
        tracing::info!("BlueZ released the agent");
        self.coordinator.withdraw_all().await;
    }

    async fn request_pin_code(&self, device: OwnedObjectPath) -> Result<String, AgentError> {
        tracing::info!(device = device.as_str(), "PIN requested");
        match self.ask(&device, Question::PinCode).await? {
            // `expose` is the only way out of `Secret`, and this is the one
            // place that is allowed to call it: the wire needs the plain value.
            Answer::Pin(pin) => Ok(pin.expose().to_owned()),
            _ => Err(AgentError::Rejected(
                "answer does not fit the question".into(),
            )),
        }
    }

    /// The other method `BlueZ` does not wait on. The spec has it return void
    /// and take the dialog back with Cancel, so holding the call open until a
    /// person pressed something meant a PIN pairing had no ending but a
    /// timeout — the interface has no Accept to offer for a code it is only
    /// showing.
    async fn display_pin_code(&self, device: OwnedObjectPath, pincode: String) {
        // The PIN itself is deliberately absent from this line.
        tracing::info!(device = device.as_str(), "showing a PIN");
        self.coordinator
            .announce(
                device.as_str(),
                Question::DisplayPinCode {
                    pin: Secret::new(pincode),
                },
            )
            .await;
    }

    async fn request_passkey(&self, device: OwnedObjectPath) -> Result<u32, AgentError> {
        tracing::info!(device = device.as_str(), "passkey requested");
        match self.ask(&device, Question::Passkey).await? {
            Answer::Passkey(passkey) => Ok(passkey),
            _ => Err(AgentError::Rejected(
                "answer does not fit the question".into(),
            )),
        }
    }

    /// The one method `BlueZ` does not wait on. It arrives again for every digit
    /// typed on the other device, so it must return at once or the next
    /// announcement queues up behind this one.
    async fn display_passkey(&self, device: OwnedObjectPath, passkey: u32, entered: u16) {
        tracing::debug!(device = device.as_str(), entered, "passkey progress");
        self.coordinator
            .announce(
                device.as_str(),
                Question::DisplayPasskey { passkey, entered },
            )
            .await;
    }

    async fn request_confirmation(
        &self,
        device: OwnedObjectPath,
        passkey: u32,
    ) -> Result<(), AgentError> {
        tracing::info!(device = device.as_str(), "confirmation requested");
        self.ask(&device, Question::Confirm { passkey })
            .await
            .map(|_| ())
    }

    async fn request_authorization(&self, device: OwnedObjectPath) -> Result<(), AgentError> {
        tracing::info!(device = device.as_str(), "authorization requested");
        self.ask(&device, Question::Authorize).await.map(|_| ())
    }

    async fn authorize_service(
        &self,
        device: OwnedObjectPath,
        uuid: String,
    ) -> Result<(), AgentError> {
        tracing::info!(
            device = device.as_str(),
            uuid,
            "service authorization requested"
        );
        self.ask(&device, Question::AuthorizeService { uuid })
            .await
            .map(|_| ())
    }

    /// The other end gave up. Whatever is on screen is now unanswerable.
    async fn cancel(&self) {
        tracing::info!("BlueZ cancelled the exchange");
        self.coordinator.withdraw_all().await;
    }
}
