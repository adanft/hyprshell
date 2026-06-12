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

    implicitWidth: content.implicitWidth
    implicitHeight: theme.height
    width: implicitWidth
    height: implicitHeight

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.gap

        BarText {
            text: root.icon()
            color: root.palette.pink
        }

        BarText {
            text: root.services.bluetoothConnectedCount
            color: root.palette.pink
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"[float] blueman-manager\")"])
    }

    function icon() {
        if (!services.bluetoothPowered)
            return icons.bluetoothOff
        if (services.bluetoothConnectedCount > 0)
            return icons.bluetoothConnected
        return icons.bluetoothOn
    }
}
