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
    readonly property color moduleColor: services.bluetoothConnectedCount > 0 ? colors.primary : colors.text

    function icon() {
        if (!services.bluetoothPowered)
            return icons.bluetoothOff;

        if (services.bluetoothConnectedCount > 0)
            return icons.bluetoothConnected;

        return icons.bluetoothOn;
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
            text: root.services.bluetoothConnectedCount
            color: root.moduleColor
        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"[float] blueman-manager\")"])
    }

}
