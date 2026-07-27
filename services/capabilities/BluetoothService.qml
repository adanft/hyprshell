import QtQuick
import Quickshell
import Quickshell.Bluetooth

Scope {
    id: root

    readonly property BluetoothAdapter bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothAvailable: bluetoothAdapter !== null
    readonly property bool bluetoothPowered: bluetoothAvailable ? bluetoothAdapter.enabled : false
    readonly property bool bluetoothDiscovering: bluetoothAvailable ? bluetoothAdapter.discovering : false
    readonly property var bluetoothDevices: bluetoothAdapter?.devices?.values ?? []
    readonly property int bluetoothConnectedCount: bluetoothDevices.filter(device => device && device.connected).length
    readonly property bool bluetoothBusy: bluetoothDevices.some(device => device && (device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting))
        property string bluetoothError: ""
        readonly property int bluetoothOperationTimeoutMs: 18000
        readonly property int bluetoothPairStabilityWindowMs: 1750
        property var bluetoothPendingOperations: ({})
        property int bluetoothPendingRevision: 0

        Timer {
            id: operationTimer
            interval: 250
            repeat: true
            running: Object.keys(root.bluetoothPendingOperations).length > 0
            onTriggered: root.pollBluetoothOperations()
        }

        Timer {
            id: errorClearTimer
            interval: 5000
            repeat: false
            onTriggered: root.bluetoothError = ""
        }

        onBluetoothErrorChanged: {
            if (bluetoothError.length > 0)
                errorClearTimer.restart()
            else
                errorClearTimer.stop()
        }

        function bluetoothDeviceKey(device) {
            return device && (device.address || device.dbusPath) || ""
        }

        function bluetoothDevicePending(device) {
            const key = bluetoothDeviceKey(device)
            return Boolean(key && root.bluetoothPendingOperations[key])
        }

        function replacePending(next) {
            bluetoothPendingOperations = next
            bluetoothPendingRevision += 1
        }

        function operationError(operation) {
            if (operation === "pair") return "Could not pair with device"
            if (operation === "forget") return "Could not forget device"
            if (operation === "disconnect-before-forget") return "Could not disconnect from device"
            return "Could not " + operation + " to device"
        }

        function finishBluetoothOperation(key, errorMessage) {
            const next = Object.assign({}, bluetoothPendingOperations)
            delete next[key]
            replacePending(next)
            if (errorMessage) bluetoothError = errorMessage
            else bluetoothError = ""
        }

        function operationSucceeded(operation, device) {
            if (!device) return operation === "forget"
            if (operation === "connect") return Boolean(device.connected)
            if (operation === "disconnect") return !device.connected
            if (operation === "pair") return Boolean(device.paired)
            if (operation === "disconnect-before-forget") return false
            return !device.paired && !device.trusted
        }

            function chainPairToConnect(key, device, now) {
                const next = Object.assign({}, bluetoothPendingOperations)
                next[key] = { operation: "connect", startedAt: now }
                replacePending(next)
                try {
                    device.connect()
                } catch (error) {
                    finishBluetoothOperation(key, "Could not connect to device")
                }
            }

            function chainDisconnectToForget(key, device, now) {
                const next = Object.assign({}, bluetoothPendingOperations)
                next[key] = { operation: "forget", startedAt: now }
                replacePending(next)
                try {
                    device.forget()
                } catch (error) {
                    finishBluetoothOperation(key, "Could not forget device")
                }
            }

                function pollBluetoothOperations() {
                    const now = Date.now()
                    const devices = bluetoothDevices
                    Object.keys(bluetoothPendingOperations).forEach(key => {
                        const pending = bluetoothPendingOperations[key]
                        const device = devices.find(candidate => bluetoothDeviceKey(candidate) === key)
                        if (pending.operation === "pair" && device) {
                            // Pairing is multi-phase. Never treat the transient
                            // paired/connected state as completion.
                            const pairing = Boolean(device.pairing)
                            const ready = !pairing && Boolean(device.paired) && Boolean(device.bonded)
                            const observed = pending.pairingObserved || pairing
                            let nextPending = pending
                            if (observed !== pending.pairingObserved)
                                nextPending = Object.assign({}, nextPending, { pairingObserved: true })
                            if (pairing || !ready) {
                                if (nextPending.stableSince !== undefined)
                                    nextPending = Object.assign({}, nextPending, { stableSince: undefined })
                                if (observed && !pairing && (!device.paired || !device.bonded)) {
                                    finishBluetoothOperation(key, operationError("pair"))
                                    return
                                }
                            } else if (nextPending.stableSince === undefined) {
                                nextPending = Object.assign({}, nextPending, { stableSince: now })
                            }
                            if (nextPending !== pending) {
                                const updated = Object.assign({}, bluetoothPendingOperations)
                                updated[key] = nextPending
                                replacePending(updated)
                            }
                            if (ready && nextPending.stableSince !== undefined && now - nextPending.stableSince >= bluetoothPairStabilityWindowMs) {
                                if (device.connected)
                                    finishBluetoothOperation(key, "")
                                else
                                    chainPairToConnect(key, device, now)
                            }
                        } else if (pending.operation === "disconnect-before-forget" && device && !device.connected) {
                            chainDisconnectToForget(key, device, now)
                        } else if (operationSucceeded(pending.operation, device)) {
                            finishBluetoothOperation(key, "")
                        } else if (now - pending.startedAt >= bluetoothOperationTimeoutMs) {
                            finishBluetoothOperation(key, operationError(pending.operation))
                        }
                    })
                }

        function startBluetoothOperation(device, operation, invoke) {
            const key = bluetoothDeviceKey(device)
            if (!key || bluetoothDevicePending(device)) return false
            bluetoothError = ""
            const next = Object.assign({}, bluetoothPendingOperations)
                next[key] = operation === "pair"
                    ? { operation: operation, startedAt: Date.now(), pairingObserved: false, stableSince: undefined }
                    : { operation: operation, startedAt: Date.now() }
            replacePending(next)
            try { invoke() } catch (error) { finishBluetoothOperation(key, operationError(operation)); return false }
            return true
        }

    function toggleBluetoothPowered() {
        if (bluetoothAdapter)
            bluetoothAdapter.enabled = !bluetoothAdapter.enabled
    }

    function scanBluetooth() {
        if (bluetoothAdapter && bluetoothPowered)
            bluetoothAdapter.discovering = !bluetoothDiscovering
    }

    function connectBluetoothDevice(device) {
        if (!bluetoothPowered || !device || device.connected || device.blocked || !device.paired && !device.trusted || bluetoothDeviceBusy(device)) return false
        return startBluetoothOperation(device, "connect", () => device.connect())
    }

    function disconnectBluetoothDevice(device) {
        if (!device || !device.connected || bluetoothDeviceBusy(device)) return false
        return startBluetoothOperation(device, "disconnect", () => device.disconnect())
    }

    function pairBluetoothDevice(device) {
        if (!bluetoothPowered || !device || device.paired || device.blocked || bluetoothDeviceBusy(device)) return false
        return startBluetoothOperation(device, "pair", () => device.pair())
    }

    function forgetBluetoothDevice(device) {
        if (!device || bluetoothDeviceBusy(device)) return false
        if (!device.connected)
        return startBluetoothOperation(device, "forget", () => device.forget())
        return startBluetoothOperation(device, "disconnect-before-forget", () => device.disconnect())
    }

    function bluetoothDeviceBusy(device) {
        return Boolean(device && (device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting))
    }
}
