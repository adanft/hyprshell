import "../components"
import QtQuick
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var colors
    required property var services
    readonly property color moduleColor: {
        if (services.systemStats.cpuUsage > 80)
            return colors.danger
        if (services.systemStats.cpuUsage > 60)
            return colors.warning
        return colors.text
    }

    implicitWidth: content.implicitWidth
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight

    Component.onCompleted: services.systemStats.enableCpuUsage()

    Component.onDestruction: services.systemStats.disableCpuUsage()

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        BarText {
            text: root.icons.processor
            color: root.moduleColor
        }

        BarText {
            text: `${Math.round(root.services.systemStats.cpuUsage)}%`
            color: root.moduleColor
        }
    }
}
