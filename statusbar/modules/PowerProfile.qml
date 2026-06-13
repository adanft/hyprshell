import ".."
import "../components"
import QtQuick

Item {
    id: root

    readonly property var
    icons: BarIcons {
    }

    readonly property var
    theme: BarTheme {
    }

    required property var palette
    required property var services
    readonly property string profile: services.powerProfile

    width: theme.iconSize
    height: theme.iconSize

    BarText {
        anchors.centerIn: parent
        color: root.profile === "performance" ? root.palette.red : root.profile === "power-saver" ? root.palette.green : root.palette.blue
        text: root.profile === "performance" ? root.icons.powerPerformance : root.profile === "power-saver" ? root.icons.powerSaver : root.icons.powerBalanced
        font.pixelSize: root.theme.iconFontSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: services.nextPowerProfile()
    }

}
