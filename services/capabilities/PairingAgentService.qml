import QtQuick
import Quickshell
import Quickshell.Io

// The shell's half of the pairing agent.
//
// Quickshell cannot serve a D-Bus object, so `org.bluez.Agent1` lives in the
// bagent process instead. This is the socket that reaches it: questions arrive
// as events, answers go back as commands, and nothing else here knows that a
// second process exists.
//
// The shell listens and the agent connects, not the other way round. The shell
// is the long-lived side — it owns the screen and outlives any restart of the
// agent — so an agent that is not running is a client that has not arrived,
// rather than a server this shell would have to keep poking and logging a
// failure for every time it tried.
//
// While nothing is attached the agent refuses every pairing that needs a
// person. That is deliberate: a question nobody can see must not be approved.
Scope {
    id: root

    readonly property string pairingSocketPath: `${Quickshell.env("XDG_RUNTIME_DIR") || ""}/bagent.sock`
    readonly property bool pairingAgentConnected: pairingLink !== null

    // Injected rather than reached for. This service has no business knowing
    // how the adapter is discovered, and the composition root is where the two
    // capabilities are allowed to meet.
    required property bool bluetoothPowered

    // Off unless a shell claims it, and only the real one does.
    //
    // The socket lives at a fixed path in the runtime directory, so it is a
    // singleton for the whole session: whoever binds it last owns it. The smoke
    // test and the harnesses instantiate these same services in their own
    // processes, and each one was quietly deleting the running shell's socket
    // to bind its own — taking the agent with it. A resource only one process
    // may hold is not something a service should claim just by existing.
    required property bool pairingAgentEnabled

    // The live connection, or null. Held rather than looked up so an answer
    // always travels back down the socket the question came from.
    property var pairingLink: null

    // The one question currently on the table, or null. Only one is ever held:
    // BlueZ pairs with one device at a time, and a second dialog would give a
    // person two codes with nothing to say which belongs to what.
    property var pairingRequest: null

    signal pairingWithdrawn

    function answerPairing(decision) {
        return sendPairingCommand(decision, {});
    }

    function submitPairingPin(pin) {
        return sendPairingCommand("pin", {
            "pin": String(pin)
        });
    }

    function submitPairingPasskey(passkey) {
        const numeric = Number(passkey);
        if (!Number.isSafeInteger(numeric) || numeric < 0)
            return false;

        return sendPairingCommand("passkey", {
            "passkey": numeric
        });
    }

    // Every answer clears the question on the way out. What the answer means is
    // the agent's to decide, but the dialog is finished either way, and leaving
    // it up invites a second answer to a token that is already spent.
    function sendPairingCommand(decision, extra) {
        const request = root.pairingRequest;
        if (!request || !root.pairingLink)
            return false;

        const command = Object.assign({
            "command": String(decision),
            "token": request.token
        }, extra || {});
        root.pairingLink.write(`${JSON.stringify(command)}\n`);
        root.clearPairingRequest();
        return true;
    }

    function clearPairingRequest() {
        root.pairingRequest = null;
    }

    function applyPairingEvent(text) {
        let event = null;
        try {
            event = JSON.parse(text);
        } catch (error) {
            // A line this shell cannot read is an agent speaking a protocol it
            // was not built against. Answering blindly would be worse than
            // ignoring it.
            return;
        }
        if (!event || typeof event !== "object")
            return;

        if (event.event === "withdraw") {
            if (root.pairingRequest && root.pairingRequest.token === event.token) {
                root.clearPairingRequest();
                root.pairingWithdrawn();
            }
            return;
        }

        if (event.event !== "ask" || !event.kind)
            return;

        // A repeat of the same token is the passkey being typed on the other
        // device: the same dialog with a new digit count, not a new question.
        root.pairingRequest = {
            "token": event.token,
            "kind": String(event.kind),
            "deviceName": String(event.device?.name || ""),
            "deviceAddress": String(event.device?.address || ""),
            "passkey": event.passkey === undefined ? -1 : Number(event.passkey),
            "entered": event.entered === undefined ? 0 : Number(event.entered),
            "pin": String(event.pin || ""),
            "uuid": String(event.uuid || "")
        };
    }

    // The agent runs exactly as long as it is useful, and not one moment more.
    //
    // Without this shell it refuses every pairing, so outliving the shell would
    // leave BlueZ with an agent that says no to everything — worse than having
    // none, because with no agent registered BlueZ handles the cases that need
    // no interaction by itself. As a child process it cannot outlive us.
    //
    // With the adapter off there is nothing for it to answer, so it does not
    // run then either. Stopping sends SIGTERM, which it uses to unregister from
    // BlueZ before it goes; being killed without that would leave BlueZ routing
    // pairing requests at a name that no longer answers.
    Process {
        running: root.pairingAgentEnabled && root.bluetoothPowered
        // By name, the way the shell launches bluetoothctl and grim. A path
        // into this repository's build directory would tie a running shell to
        // a checkout that happens to have been compiled, and would quietly do
        // nothing at all for anyone who installed it.
        command: ["bagent"]

        // Forwarded rather than discarded. A supervised process whose output
        // goes nowhere is a process that cannot be diagnosed: the moment the
        // shell took over launching it, "why did that pairing fail?" stopped
        // having an answer anywhere. It writes to stderr, and there is little
        // of it — a handful of lines per pairing.
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => console.info(`bagent: ${line}`)
        }
    }

    SocketServer {
        active: root.pairingAgentEnabled && root.pairingSocketPath.length > "/bagent.sock".length
        path: root.pairingSocketPath

        handler: Socket {
            parser: SplitParser {
                splitMarker: "\n"
                onRead: data => root.applyPairingEvent(data)
            }

            onConnectionStateChanged: {
                if (connected) {
                    root.pairingLink = this;
                    return;
                }
                if (root.pairingLink === this) {
                    // Whatever was on screen can no longer be answered: the
                    // token lives in a process this shell just lost.
                    root.pairingLink = null;
                    root.clearPairingRequest();
                }
            }
        }
    }
}
