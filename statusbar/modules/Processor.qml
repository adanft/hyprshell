import "../components"
import QtQuick
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons {
    }

    readonly property var theme: AppTheme {
    }

    required property var colors
    required property var services
    readonly property color moduleColor: colors.bluetooth

    implicitWidth: content.implicitWidth
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight

    Component.onCompleted: services.enableCpuUsage()

    Component.onDestruction: services.disableCpuUsage()

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        BarText {
            text: root.icons.processor
            color: root.moduleColor
        }

        BarText {
            text: `${Math.round(root.services.cpuUsage)}%`
            color: root.moduleColor
        }

    }

}
