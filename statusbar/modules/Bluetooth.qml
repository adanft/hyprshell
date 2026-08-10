import "../components"
import QtQuick
import "../../theme"
import "../../shared/components"

Item {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var services

    signal openRequested
    readonly property bool moduleDisabled: !services.bluetooth.bluetoothAvailable
                                           || !services.bluetooth.bluetoothPowered
    readonly property color moduleColor: moduleDisabled ? Colors.outline :
                                                          (services.bluetooth.bluetoothConnectedCount > 0 ?
                                                           Colors.primary : Colors.on_surface)

    function icon() {
        if (!services.bluetooth.bluetoothPowered)
            return icons.bluetoothOff

        if (services.bluetooth.bluetoothConnectedCount > 0)
            return icons.bluetoothConnected

        return icons.bluetoothOn
    }

    implicitWidth: content.implicitWidth
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        BarText {
            text: root.icon()
            color: root.moduleColor
        }

        BarText {
            text: root.services.bluetooth.bluetoothConnectedCount
            color: root.moduleColor
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.services.bluetooth.bluetoothAvailable
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        Accessible.name: "Open Bluetooth controls"
        Accessible.description: root.services.bluetooth.bluetoothPowered ? "On" : "Off"
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.services.bluetooth.toggleBluetoothPowered()
            else
                root.openRequested()
        }
        Keys.onSpacePressed: root.openRequested()
        Keys.onReturnPressed: root.openRequested()
        Keys.onEnterPressed: root.openRequested()
    }
}
