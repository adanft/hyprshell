//! bagent — the pairing agent Quickshell cannot be.
//!
//! Quickshell exposes no way to serve a D-Bus object, so `org.bluez.Agent1` has
//! nowhere to live inside the shell. This process is that object and nothing
//! more: it answers `BlueZ`, forwards every question to whatever interface is
//! attached to its socket, and forwards the reply back. It draws nothing and
//! decides nothing.
//!
//! This file is the only place that names a concrete adapter. Every other
//! module was handed what it needed through its constructor, which is what
//! makes the socket replaceable without the use case noticing.

mod application;
mod domain;
mod infrastructure;

use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use application::coordinator::Coordinator;
use domain::model::Token;
use domain::ports::Tokens;
use infrastructure::bluez::agent::Agent;
use infrastructure::bluez::directory::BluezDirectory;
use infrastructure::bluez::registrar::Registrar;
use infrastructure::ipc::link::ShellLink;
use zbus::zvariant::ObjectPath;

/// Long enough that a person can pick the phone up and read the code, short
/// enough that a forgotten dialog does not hold a pairing open all afternoon.
const PATIENCE: Duration = Duration::from_mins(2);

const AGENT_PATH: ObjectPath<'static> = ObjectPath::from_static_str_unchecked("/org/hyprshell/bagent");

const SOCKET_NAME: &str = "bagent.sock";

/// Sequential and process-local. Tokens only have to be unique among the
/// exchanges alive right now, so there is nothing to gain from making them
/// unguessable — the socket permissions are what keep strangers out.
#[derive(Default)]
struct Counter(AtomicU64);

impl Tokens for Counter {
    fn next(&self) -> Token {
        Token::new(self.0.fetch_add(1, Ordering::Relaxed))
    }
}

/// The runtime directory is per-user and cleared on logout, which is where a
/// socket that grants pairing rights belongs. Falling back to `/tmp` would put
/// it somewhere every user on the machine can reach, so a missing
/// `XDG_RUNTIME_DIR` is a reason to stop rather than to improvise.
fn socket_path() -> Result<PathBuf, Box<dyn std::error::Error>> {
    let runtime = std::env::var_os("XDG_RUNTIME_DIR")
        .ok_or("XDG_RUNTIME_DIR is not set; refusing to place the socket somewhere shared")?;
    Ok(PathBuf::from(runtime).join(SOCKET_NAME))
}

/// Die when whoever started this process dies.
///
/// The shell launches this and stops it by ending the process, but a parent
/// that is killed rather than asked to stop never gets to do that: the child is
/// reparented to init and keeps running. An orphan here is worse than no agent
/// at all — it stays registered with `BlueZ`, has no shell to ask, and therefore
/// refuses every pairing it is handed.
///
/// `PR_SET_PDEATHSIG` is the kernel's answer, and the only one that holds when
/// the parent dies in a way it cannot handle.
fn die_with_parent() {
    // SAFETY: prctl with PR_SET_PDEATHSIG takes an integer signal number and
    // touches nothing this process owns.
    let result = unsafe { libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGTERM) };
    if result != 0 {
        tracing::warn!("could not ask to be stopped with the parent");
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "bagent=info".into()),
        )
        .init();

    die_with_parent();

    let socket = socket_path()?;

    // Wiring, in dependency order. The link is built first because the use case
    // needs a presenter, and it is only given the sink once the use case exists.
    let link = Arc::new(ShellLink::new(socket));
    let connection = zbus::Connection::system().await?;
    let coordinator = Arc::new(Coordinator::new(
        link.clone(),
        Arc::new(BluezDirectory::new(connection.clone())),
        Arc::new(Counter::default()),
        PATIENCE,
    ));

    // Served before registering: BlueZ may call the moment it knows the path
    // exists, and an agent that is registered but not yet listening would fail
    // the first pairing after every restart.
    connection
        .object_server()
        .at(&AGENT_PATH, Agent::new(coordinator.clone()))
        .await?;
    let registrar = Registrar::attach(&connection, AGENT_PATH).await?;

    let attaching = tokio::spawn(link.run(coordinator.clone()));

    shutdown().await;

    // Order matters on the way out too: stop being the agent first, so BlueZ
    // stops routing questions here, and only then abandon what is on screen.
    registrar.detach().await;
    coordinator.withdraw_all().await;
    attaching.abort();
    tracing::info!("stopped");
    Ok(())
}

/// Either signal means the same thing here, and neither is an error: a user
/// logging out is the ordinary way this process ends.
async fn shutdown() {
    let mut terminate =
        match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            Ok(signal) => signal,
            Err(error) => {
                tracing::error!(%error, "cannot watch for SIGTERM; waiting on Ctrl-C alone");
                let _ = tokio::signal::ctrl_c().await;
                return;
            }
        };

    tokio::select! {
        _ = tokio::signal::ctrl_c() => tracing::info!("interrupted"),
        _ = terminate.recv() => tracing::info!("terminated"),
    }
}
