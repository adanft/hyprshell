import QtQuick
import Quickshell

Pill {
    id: root

    required property var services
    property bool grouped: false

    textColor: palette.pink
    backgroundColor: grouped ? "transparent" : palette.base
    text: `${icon()}  ${services.bluetoothConnectedCount}`
    horizontalPadding: 10

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"[float] blueman-manager\")"])
    }

    function icon() {
        if (!services.bluetoothPowered)
            return "󰂲"
        if (services.bluetoothConnectedCount > 0)
            return "󰂱"
        return "󰂯"
    }
}
