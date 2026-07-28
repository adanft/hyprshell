import "../components"
import QtQuick
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons {}

    readonly property var theme: AppTheme {}

    required property var colors
    required property var services
    readonly property string profile: services.batteryPower.powerProfile

    width: theme.sizing.statusBarIconSize
    height: theme.sizing.statusBarIconSize

    BarText {
        anchors.centerIn: parent
        color: root.profile === "performance" ? root.colors.danger : root.profile === "power-saver" ? root.colors.success :
                                                                                                      root.colors.info
        text: root.profile === "performance" ? root.icons.powerPerformance : root.profile === "power-saver"
                                               ? root.icons.powerSaver : root.icons.powerBalanced
        font.pixelSize: root.theme.sizing.statusBarIconSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: services.batteryPower.nextPowerProfile()
    }
}
