import "../components"
import QtQuick
import "../../../theme"
import "../../../shared/components"

Item {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var services
    readonly property color moduleColor: {
        if (services.systemStats.memoryUsage > 90)
            return Colors.error
        if (services.systemStats.memoryUsage > 75)
            return Colors.secondary
        return Colors.on_surface
    }

    implicitWidth: content.implicitWidth
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight

    Component.onCompleted: services.systemStats.enableMemoryUsage()

    Component.onDestruction: services.systemStats.disableMemoryUsage()

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        AppText {
            text: root.icons.memory
            color: root.moduleColor
        }

        AppText {
            text: `${Math.round(root.services.systemStats.memoryUsage)}%`
            color: root.moduleColor
        }
    }
}
