import QtQuick
import Quickshell.Hyprland
import "../components"
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons
    readonly property var theme: AppTheme
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var focusedMonitor: Hyprland.focusedMonitor
    readonly property bool monitorFocused: !!monitor && !!focusedMonitor && (monitor === focusedMonitor || (
                                                                                 monitor.name.length > 0
                                                                                 && monitor.name
                                                                                 === focusedMonitor.name))
    required property var screen
    required property var services

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.centerIn: parent

        Repeater {
            model: root.services.workspace.statusWorkspaceIdsForMonitor(root.monitor)

            BarText {
                required property int modelData

                readonly property bool active: root.monitor?.activeWorkspace?.id === modelData
                readonly property bool urgent: root.services.workspace.statusUrgentWorkspaceIds[modelData] ?? false
                readonly property bool empty: !(root.services.workspace.statusOccupiedWorkspaceIds[modelData] ?? false)

                readonly property bool hovered: mouseArea.containsMouse

                width: root.theme.sizing.statusBarWorkspaceSlotSize
                text: root.icons.workspaceDot
                color: root.workspaceColor(urgent, active, root.monitorFocused, hovered, empty)
                font.family: root.theme.typography.iconFontFamily
                horizontalAlignment: Text.AlignHCenter

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(modelData)
                }
            }
        }
    }

    function focusWorkspace(workspaceId) {
        root.services.workspace.focusWorkspace(workspaceId)
    }

    function workspaceColor(urgent, active, monitorFocused, hovered, empty) {
        if (urgent)
            return Colors.error
        if (hovered)
            return Colors.hover
        if (active)
            return monitorFocused ? Colors.primary : Colors.tertiary

        return empty ? Colors.outline : Colors.on_surface_variant
    }
}
