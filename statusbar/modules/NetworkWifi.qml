import "../components"
import QtQuick
import Quickshell.Networking
import "../../theme"

Item {
    id: root

    readonly property var
    icons: Icons {
    }

    readonly property var
    theme: AppTheme {
    }

    required property var colors
    required property var services
    readonly property bool connected: services.wifiUp && services.wifiSignal > 0
    readonly property color moduleColor: connected ? colors.primary : colors.text

    function icon() {
        if (connected)
            return icons.wifiConnected;
        return Networking.wifiEnabled ? icons.wifiEnabled : icons.wifiDisconnected;
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
            text: `${root.services.wifiSignal}%`
            color: root.moduleColor
        }

    }

}
