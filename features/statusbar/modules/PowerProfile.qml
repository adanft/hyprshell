import "../components"
import QtQuick
import "../../../theme"
import "../../../shared/components"

Item {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var services
    readonly property string profile: services.batteryPower.powerProfile

    width: theme.sizing.statusBarIconSize
    height: theme.sizing.statusBarIconSize

    AppText {
        anchors.centerIn: parent
        color: root.profile === "performance" ? Colors.error : root.profile === "power-saver" ? Colors.hover :
                                                                                                      Colors.tertiary
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
