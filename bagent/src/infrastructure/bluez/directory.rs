//! Turning an object path into a name a person recognizes.
//!
//! `/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF` tells a user nothing. `BlueZ` knows
//! the alias, so this asks. It is a separate adapter because a change in how
//! devices are named has no business touching the pairing flow.

use async_trait::async_trait;
use zbus::Connection;

use crate::domain::model::Device;
use crate::domain::ports::DeviceDirectory;

#[zbus::proxy(interface = "org.bluez.Device1", default_service = "org.bluez")]
trait Device1 {
    #[zbus(property)]
    fn name(&self) -> zbus::Result<String>;
    #[zbus(property)]
    fn alias(&self) -> zbus::Result<String>;
    #[zbus(property)]
    fn address(&self) -> zbus::Result<String>;
}

pub struct BluezDirectory {
    connection: Connection,
}

impl BluezDirectory {
    pub fn new(connection: Connection) -> Self {
        Self { connection }
    }
}

#[async_trait]
impl DeviceDirectory for BluezDirectory {
    /// Alias first because it is what the user renamed the device to; then the
    /// name the device announces; then the address, which is ugly but always
    /// there. A pairing is never refused because a label could not be read.
    async fn lookup(&self, path: &str) -> Device {
        let Ok(builder) = Device1Proxy::builder(&self.connection).path(path.to_owned()) else {
            return Device::unnamed(path);
        };
        let Ok(proxy) = builder.build().await else {
            return Device::unnamed(path);
        };

        let address = proxy.address().await.unwrap_or_default();
        let alias = proxy.alias().await.ok().filter(|alias| !alias.is_empty());
        let name = match alias {
            Some(alias) => Some(alias),
            None => proxy.name().await.ok().filter(|name| !name.is_empty()),
        };

        match name {
            Some(name) => Device {
                path: path.to_owned(),
                name,
                address,
            },
            None if !address.is_empty() => Device {
                path: path.to_owned(),
                name: address.clone(),
                address,
            },
            None => Device::unnamed(path),
        }
    }
}
