import QtQuick
import Quickshell
import Quickshell.Bluetooth

Scope {
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothAvailable: bluetoothAdapter !== null
    readonly property bool bluetoothPowered: bluetoothAvailable ? bluetoothAdapter.enabled : false
        function toggleBluetoothPowered() {
            if (bluetoothAdapter)
                bluetoothAdapter.enabled = !bluetoothAdapter.enabled
        }

        readonly property int bluetoothConnectedCount: {
        if (!bluetoothAdapter || !bluetoothAdapter.devices)
            return 0
        let count = 0
        bluetoothAdapter.devices.values.forEach(device => {
            if (device && device.connected)
                count++
        })
        return count
    }
}
