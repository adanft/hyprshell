import "../components"
import QtQuick
import Quickshell.Networking
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var colors
    required property var services
    readonly property bool connected: services.network.wifiUp && services.network.wifiSignal > 0
    readonly property color moduleColor: connected ? colors.primary : colors.text

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
        Accessible.name: Networking.wifiEnabled ? "Disable Wi-Fi" : "Enable Wi-Fi"
        onClicked: root.services.network.toggleWifiEnabled()
        Keys.onSpacePressed: root.services.network.toggleWifiEnabled()
        Keys.onReturnPressed: root.services.network.toggleWifiEnabled()
        Keys.onEnterPressed: root.services.network.toggleWifiEnabled()
    }
}
