import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Scope {
    id: root

    readonly property BluetoothAdapter bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothAvailable: bluetoothAdapter !== null
    readonly property bool bluetoothPowered: bluetoothAvailable ? bluetoothAdapter.enabled : false
    readonly property bool bluetoothDiscovering: bluetoothAvailable ? bluetoothAdapter.discovering : false
    readonly property string bluetoothAdapterName: bluetoothAvailable ? bluetoothAdapter.name : ""
    readonly property bool bluetoothDiscoverable: bluetoothAvailable ? bluetoothAdapter.discoverable : false
    readonly property var bluetoothDevices: bluetoothAdapter?.devices?.values ?? []
    readonly property int bluetoothConnectedCount: bluetoothDevices.filter(device => device && device.connected).length
    readonly property bool bluetoothBusy: bluetoothPairProcess.running || bluetoothDevices.some(device => device && (
                                                                                                              device.pairing
                                                                                                              || device.state
                                                                                                              === BluetoothDeviceState.Connecting
                                                                                                              || device.state
                                                                                                              === BluetoothDeviceState.Disconnecting))
    property string bluetoothError: ""
    property string bluetoothPendingAddress: ""
    property int bluetoothPendingRevision: 0
    property bool bluetoothDiscoveryChangePending: false
    property var bluetoothPendingForgetDevice: null
    property int bluetoothPendingForgetElapsed: 0

    Timer {
        id: bluetoothErrorTimer
        interval: 4000
        repeat: false
        onTriggered: root.bluetoothError = ""
    }

    onBluetoothErrorChanged: {
        if (bluetoothError.length > 0)
            bluetoothErrorTimer.restart()
        else
            bluetoothErrorTimer.stop()
    }

    Timer {
        id: bluetoothDiscoveryTransitionTimer
        interval: 1500
        repeat: false
        onTriggered: root.bluetoothDiscoveryChangePending = false
    }

    onBluetoothDiscoveringChanged: {
        bluetoothDiscoveryChangePending = false
        bluetoothDiscoveryTransitionTimer.stop()
    }

    onBluetoothPoweredChanged: {
        if (!bluetoothPowered) {
            bluetoothDiscoveryChangePending = false
            bluetoothDiscoveryTransitionTimer.stop()
            return
        }
        ensureBluetoothPairable()
    }

    Timer {
        id: bluetoothForgetTimer
        interval: 100
        repeat: true
        onTriggered: {
            const device = root.bluetoothPendingForgetDevice
            if (!device) {
                stop()
                return
            }
            if (!device.connected) {
                root.bluetoothPendingForgetDevice = null
                root.bluetoothPendingForgetElapsed = 0
                stop()
                try {
                    device.forget()
                } catch (error) {
                    root.bluetoothError = "Could not forget Bluetooth device"
                }
            } else if (root.bluetoothPendingForgetElapsed >= 4000) {
                root.bluetoothPendingForgetDevice = null
                root.bluetoothPendingForgetElapsed = 0
                stop()
                root.bluetoothError = "Could not disconnect Bluetooth device before forgetting"
            } else {
                root.bluetoothPendingForgetElapsed += interval
            }
        }
    }

    Process {
        id: bluetoothPairProcess

        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.bluetoothError = "Could not pair device"
            root.bluetoothPendingAddress = ""
            root.bluetoothPendingRevision += 1
        }
    }

    function bluetoothDevicePending(device) {
        return Boolean(device && bluetoothPendingAddress.length > 0 && device.address === bluetoothPendingAddress)
    }

    function toggleBluetoothPowered() {
        if (bluetoothAdapter)
            bluetoothAdapter.enabled = !bluetoothAdapter.enabled
    }

    // Pairable is what lets another device start a pairing at all. With it off
    // BlueZ refuses before any agent is asked, so a shell that draws a pairing
    // dialog would simply never be given one to draw. It follows the adapter's
    // power: a Bluetooth that is on but cannot be paired with is a state nobody
    // asks for, and refusing a request is the dialog's job, not this flag's.
    //
    // Re-asserted rather than bound. A binding writes when its own value
    // changes, and this one's value is the adapter's power — so when BlueZ or a
    // bluetoothctl invocation turns pairing off by itself, which they do after
    // a pairing completes, nothing here notices and the next device to try is
    // refused before the agent is ever asked. Watching the flag is the only way
    // to hold it.
    function ensureBluetoothPairable() {
        if (bluetoothAdapter && bluetoothPowered && !bluetoothAdapter.pairable)
            bluetoothAdapter.pairable = true
    }

    Component.onCompleted: ensureBluetoothPairable()

    Connections {
        function onPairableChanged() {
            root.ensureBluetoothPairable()
        }

        target: root.bluetoothAdapter
    }

    // A device that finished pairing is trusted here too.
    //
    // While a device is untrusted BlueZ asks the agent to authorise every
    // single service it wants to use, and a phone offers seventeen. That is the
    // dialog appearing three and five times over: not one question repeated,
    // but one question per profile — handsfree, audio, remote control,
    // phonebook, messages.
    //
    // The outgoing path has always avoided that, because `bluetoothctl trust`
    // sits between pair and connect. A device that paired from the other end
    // had nothing doing the same for it, so this closes the asymmetry: however
    // the pairing started, it ends the same way.
    //
    // Reading `paired` and `trusted` inside the filter is what makes this
    // react: the binding records a dependency on both for every device, so a
    // pairing completing anywhere re-evaluates it.
    readonly property var untrustedPairedDevices: bluetoothDevices.filter(device => device && device.paired
                                                                          && !device.trusted)

    onUntrustedPairedDevicesChanged: {
        for (const device of untrustedPairedDevices) {
            try {
                device.trusted = true
            } catch (error) {
                bluetoothError = "Paired, but could not be trusted"
            }
        }
    }

    // discoverable is writable straight on the adapter, so being seen by other
    // devices is a property to set, not a bluetoothctl call to shell out to.
    function toggleBluetoothDiscoverable() {
        if (bluetoothAdapter && bluetoothPowered)
            bluetoothAdapter.discoverable = !bluetoothAdapter.discoverable
    }

    function scanBluetooth() {
        setBluetoothScanning(!bluetoothDiscovering)
    }

    function setBluetoothScanning(enabled) {
        const desired = Boolean(enabled)
        if (!bluetoothAdapter || !bluetoothPowered || bluetoothDiscovering === desired
                || bluetoothDiscoveryChangePending)
            return false
        bluetoothDiscoveryChangePending = true
        bluetoothDiscoveryTransitionTimer.restart()
        bluetoothAdapter.discovering = desired
        return true
    }

    function connectBluetoothDevice(device) {
        if (!bluetoothPowered || !device || device.connected || device.blocked || (!device.paired && !device.trusted) || bluetoothDeviceBusy(
                    device))
            return false
        try {
            device.connect()
            return true
        } catch (error) {
            bluetoothError = "Could not connect Bluetooth device"
            return false
        }
    }

    function disconnectBluetoothDevice(device) {
        if (!bluetoothPowered || !device || !device.connected || bluetoothDeviceBusy(device))
            return false
        try {
            device.disconnect()
            return true
        } catch (error) {
            bluetoothError = "Could not disconnect Bluetooth device"
            return false
        }
    }

    // The timeout is the window a person has to pick up the phone, unlock it,
    // read six digits and compare them. Thirty seconds never mattered while
    // pairing failed instantly for want of an agent; with one answering, it
    // killed the pairing just as the dialog was about to be answered. It sits
    // above the agent's own limit so the agent is what decides, not this.
    function pairBluetoothDevice(device) {
        const address = device?.address || ""
        if (!bluetoothPowered || !device || !address || device.paired || device.blocked || bluetoothDeviceBusy(device)
                || bluetoothPairProcess.running)
            return false

        bluetoothError = ""
        bluetoothPendingAddress = address
        bluetoothPendingRevision += 1
        bluetoothPairProcess.exec(["sh", "-c",
                                   "timeout 150 bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\" && timeout 150 bluetoothctl connect \"$1\"",
                                   "bluetooth-pair", address,])
        return true
    }

    function forgetBluetoothDevice(device) {
        if (!bluetoothPowered || !device || bluetoothDeviceBusy(device))
            return false
        if (device.connected) {
            try {
                bluetoothPendingForgetDevice = device
                bluetoothPendingForgetElapsed = 0
                device.disconnect()
                bluetoothForgetTimer.start()
                return true
            } catch (error) {
                bluetoothPendingForgetDevice = null
                bluetoothPendingForgetElapsed = 0
                bluetoothError = "Could not disconnect Bluetooth device before forgetting"
                return false
            }
        }
        try {
            device.forget()
            return true
        } catch (error) {
            bluetoothError = "Could not forget Bluetooth device"
            return false
        }
    }

    function bluetoothDeviceBusy(device) {
        return Boolean(device && (bluetoothDevicePending(device) || device.pairing || device.state
                                  === BluetoothDeviceState.Connecting || device.state
                                  === BluetoothDeviceState.Disconnecting))
    }
}
