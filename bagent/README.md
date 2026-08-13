# bagent

The Bluetooth pairing agent Quickshell cannot be.

Quickshell can consume D-Bus but cannot *serve* an object on it, so
`org.bluez.Agent1` has nowhere to live inside the shell. Without that object
BlueZ has nobody to ask when a device needs a passkey confirmed, a PIN typed or
an incoming pairing authorised, and every one of those pairings fails. This
process is that object and nothing else.

It draws nothing. It decides nothing. It forwards questions to whatever shell
is attached and forwards the answer back.

## What it does not replace

`Quickshell.Bluetooth` keeps doing everything it already does — listing,
connecting, disconnecting, forgetting. This covers only the gap, the same way
DankMaterialShell puts an agent in a Go sidecar and leaves the rest in QML.

## Layout

```
src/
├── domain/          types and the traits the use case needs — no I/O at all
├── application/     the use case: run one exchange from question to answer
└── infrastructure/  adapters: BlueZ on one side, a Unix socket on the other
```

Dependencies point inwards. `domain` names nothing; `application` names only
`domain`; the adapters name both. `main.rs` is the only file that knows which
concrete adapter is in use, which is what makes the socket replaceable without
the use case noticing.

## The socket

`$XDG_RUNTIME_DIR/bagent.sock`. One JSON object per line, both directions.

**The shell listens and this process connects.** That is the way round it has
to be: the shell owns the screen, starts with the session and outlives any
restart of the agent, so an absent agent is a client that has not arrived
rather than a server the shell would have to keep poking — and log a failure
for — every few seconds. It also makes "is anyone watching?" exact: a dropped
connection is the shell going away, observed rather than inferred, and that is
the signal the fail-closed rule rests on.

Anything able to write to this socket can approve a pairing. The socket itself
is created by the shell with whatever mode Quickshell gives it, so the
protection is the runtime directory: `$XDG_RUNTIME_DIR` is `0700` and owned by
the user, and nothing outside it can reach in. A missing `XDG_RUNTIME_DIR`
stops this process rather than falling back to somewhere shared.

### Questions, agent to shell

```json
{"event":"ask","token":7,"device":{"name":"Pixel 7","address":"AA:BB:.."},"kind":"confirm","passkey":483920}
{"event":"withdraw","token":7}
```

| `kind` | Extra fields | What to draw |
|---|---|---|
| `confirm` | `passkey` | The six digits and yes/no. The common case. |
| `authorize` | — | Yes/no for an incoming pairing. |
| `authorize-service` | `uuid` | Yes/no for one service. |
| `display-pin` | `pin` | Show the PIN; it is typed on the other device. Nothing to accept — a `withdraw` closes it. |
| `display-passkey` | `passkey`, `entered` | Show the passkey. Arrives again for every digit typed on the other device — replace the dialog with the same token rather than stacking. |
| `request-pin` | — | Text input; send it back. |
| `request-passkey` | — | Numeric input; send it back. |

`withdraw` means the dialog can no longer be answered: BlueZ took the question
back, or nobody answered in time. Close it.

### Answers, shell to agent

```json
{"command":"accept","token":7}
{"command":"reject","token":7}
{"command":"pin","token":7,"pin":"0000"}
{"command":"passkey","token":7,"passkey":483920}
```

An unknown command or an unexpected field is a parse failure, not a shrug, so a
typo in the shell is loud instead of leaving a dialog waiting forever.

## Behaviour worth knowing before you run it

**With no shell attached, every pairing that needs a human is refused.** That is
deliberate — an agent that stays silent leaves BlueZ waiting and the pairing
hanging — but it means running this while the shell cannot answer is worse than
not running it at all: with no agent registered, BlueZ handles the cases that
need no interaction by itself.

It reconnects on its own, so starting it before the shell is fine; what is not
fine is running it against a shell that has no pairing dialog.

Other rules the agent holds to:

- A question nobody answers within two minutes is refused, and the dialog is
  withdrawn. Relying on BlueZ's own timeout to bound the wait would leave a
  reply held open here.
- Showing is bounded too, and separately. A shell that is connected but has
  stopped reading never errors, so without its own deadline the agent would sit
  inside "show this" with BlueZ's call open and the patience timer not yet
  started. Ten seconds to accept a line of JSON; past that it counts as gone.
- The two display questions — a PIN or a passkey shown here and typed there —
  are announcements, not questions. BlueZ wants them acknowledged at once and
  takes them back with Cancel, so there is nothing to accept and the dialog
  offers no Accept for them.
- A refusal and a collapse are different D-Bus errors. Declined, unattended and
  mismatched become `org.bluez.Error.Rejected`; a timeout or a withdrawal
  becomes `org.bluez.Error.Canceled`. Telling a phone it was turned down when
  nobody ever looked is a lie BlueZ acts on.
- An answer of the wrong shape for the question is refused — a PIN offered to a
  yes-or-no confirmation does not approve it.
- Secrets never reach the log. `Secret` redacts under `Debug` and the plain
  value is reachable only through `expose`, which is one grep away from an
  audit.

## Installing it

```sh
../install.sh                        # into ~/.local/bin
```

System-wide takes two steps, because the build must not run as root: a build
under sudo compiles every dependency with privileges none of them need.

```sh
../install.sh                        # build as yourself
PREFIX=/usr/local sudo ../install.sh # install what you just built
```

The shell launches it **by name**, the way it launches bluetoothctl and grim, so
what matters is that it lands somewhere on PATH. There is no service to enable:
the shell starts it with the Bluetooth adapter and stops it with the adapter,
which is exactly as long as it has anything to answer.

To run it by hand instead — for the log, mostly:

```sh
cargo build --release
RUST_LOG=bagent=debug ./target/release/bagent
```

The adapter must also be pairable, which is separate from having an agent. The
qsrice shell now binds that to the adapter's power, so there is nothing to set
by hand; without it, BlueZ refuses the pairing before any agent is asked.

## Tests

```sh
cargo test
cargo clippy --all-targets -- -W clippy::pedantic
```

The use case is tested against stub adapters, so the pairing rules — fail
closed, time out, refuse a mismatched answer, release whoever is waiting when a
question is withdrawn — are covered without a bus or a socket anywhere.
