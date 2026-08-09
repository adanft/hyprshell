import "../components"
import QtQuick
import Quickshell.Networking
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var services

    signal openRequested
    readonly property bool connected: services.network.wifiUp && services.network.wifiSignal > 0
    readonly property bool moduleDisabled: !Networking.wifiHardwareEnabled || !Networking.wifiEnabled
    readonly property color moduleColor: moduleDisabled ? Colors.outline : (connected ? Colors.primary :
                                                                            Colors.on_surface)

    function icon() {
        if (connected)
            return icons.wifiConnected
        return Networking.wifiEnabled ? icons.wifiEnabled : icons.wifiDisconnected
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
            visible: root.connected
            text: `${root.services.network.wifiSignal}%`
            color: root.moduleColor
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: Networking.wifiHardwareEnabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        Accessible.name: "Open Wi-Fi controls"
        Accessible.description: Networking.wifiEnabled ? "On" : "Off"
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.services.network.toggleWifiEnabled()
            else
                root.openRequested()
        }
        Keys.onSpacePressed: root.openRequested()
        Keys.onReturnPressed: root.openRequested()
        Keys.onEnterPressed: root.openRequested()
    }
}
