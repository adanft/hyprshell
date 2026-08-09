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
        }
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

    function pairBluetoothDevice(device) {
        const address = device?.address || ""
        if (!bluetoothPowered || !device || !address || device.paired || device.blocked || bluetoothDeviceBusy(device)
                || bluetoothPairProcess.running)
            return false

        bluetoothError = ""
        bluetoothPendingAddress = address
        bluetoothPendingRevision += 1
        bluetoothPairProcess.exec(["sh", "-c",
                                   "timeout 30 bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\" && timeout 30 bluetoothctl connect \"$1\"",
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
