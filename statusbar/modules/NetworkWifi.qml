import "../components"
import QtQuick
import Quickshell
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

    implicitWidth: content.implicitWidth
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        BarText {
            text: root.connected ? root.icons.wifiConnected : root.icons.wifiDisconnected
            color: root.connected ? root.colors.wifiConnected : root.colors.wifiDisconnected
        }

        BarText {
            visible: root.connected
            text: `${root.services.wifiSignal}%`
            color: root.colors.wifiConnected
        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["alacritty", "--class", "floating", "-e", "nmtui"])
    }

}
