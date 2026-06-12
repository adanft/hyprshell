import QtQuick
import Quickshell
import ".."
import "../components"

Item {
    id: root

    readonly property var icons: BarIcons {}
    readonly property var theme: BarTheme {}
    required property var palette
    required property var services

    readonly property bool connected: services.wifiUp && services.wifiSignal > 0

    implicitWidth: content.implicitWidth
    implicitHeight: theme.height
    width: implicitWidth
    height: implicitHeight

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.gap

        BarText {
            text: root.connected ? root.icons.wifiConnected : root.icons.wifiDisconnected
            color: root.palette.red
        }

        BarText {
            visible: root.connected
            text: `${root.services.wifiSignal}%`
            color: root.palette.red
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["alacritty", "--class", "floating", "-e", "nmtui"])
    }
}
