//! Getting the agent noticed, and taking it back down.
//!
//! Registration is separate from the agent object because they answer different
//! questions: the object is what `BlueZ` calls, this is how `BlueZ` learns it
//! exists. Keeping them apart means the object can be exercised without a bus.

use zbus::Connection;
use zbus::zvariant::ObjectPath;

/// `KeyboardDisplay` is the capability that covers every question an agent can
/// be asked. Anything narrower silently removes cases: `NoInputNoOutput` limits
/// pairing to devices that need no interaction at all, which is the situation
/// this whole program exists to fix.
const CAPABILITY: &str = "KeyboardDisplay";

#[zbus::proxy(
    interface = "org.bluez.AgentManager1",
    default_service = "org.bluez",
    default_path = "/org/bluez"
)]
trait AgentManager {
    fn register_agent(&self, agent: &ObjectPath<'_>, capability: &str) -> zbus::Result<()>;
    fn request_default_agent(&self, agent: &ObjectPath<'_>) -> zbus::Result<()>;
    fn unregister_agent(&self, agent: &ObjectPath<'_>) -> zbus::Result<()>;
}

pub struct Registrar {
    proxy: AgentManagerProxy<'static>,
    path: ObjectPath<'static>,
}

impl Registrar {
    pub async fn attach(
        connection: &Connection,
        path: ObjectPath<'static>,
    ) -> Result<Self, zbus::Error> {
        let proxy = AgentManagerProxy::new(connection).await?;
        proxy.register_agent(&path, CAPABILITY).await?;

        // Being the default is what routes requests here when nothing else
        // claimed them. Failing is survivable — another agent already holds it,
        // and BlueZ will still call us for devices we initiated — so this is a
        // warning rather than a reason to give up.
        if let Err(error) = proxy.request_default_agent(&path).await {
            tracing::warn!(%error, "registered, but not the default agent");
        }

        tracing::info!(
            path = path.as_str(),
            capability = CAPABILITY,
            "agent registered"
        );
        Ok(Self { proxy, path })
    }

    /// Leaving a registration behind means `BlueZ` keeps routing pairing requests
    /// to a name that no longer answers, which looks to a user like Bluetooth
    /// silently breaking.
    pub async fn detach(&self) {
        match self.proxy.unregister_agent(&self.path).await {
            Ok(()) => tracing::info!("agent unregistered"),
            Err(error) => tracing::warn!(%error, "could not unregister the agent"),
        }
    }
}
