import "../components"
import QtQuick
import "../../theme"

Item {
    id: root

    readonly property var
    icons: Icons {
    }

    readonly property var
    theme: AppTheme {
    }

    required property var palette
    required property var services
    readonly property string profile: services.powerProfile

    width: theme.sizing.statusBarIconSize
    height: theme.sizing.statusBarIconSize

    BarText {
        anchors.centerIn: parent
        color: root.profile === "performance" ? root.palette.red : root.profile === "power-saver" ? root.palette.green : root.palette.blue
        text: root.profile === "performance" ? root.icons.powerPerformance : root.profile === "power-saver" ? root.icons.powerSaver : root.icons.powerBalanced
        font.pixelSize: root.theme.typography.sizeXl
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: services.nextPowerProfile()
    }

}
