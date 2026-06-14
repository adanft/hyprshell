import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../components"
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons {}
    readonly property var theme: AppTheme {}
    required property var palette

    readonly property var workspaces: [1, 2, 3, 4, 5, 6, 7, 8, 9]
    readonly property int activeWorkspaceId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property var otherMonitorWorkspaceIds: {
        const visible = {}
        for (const monitor of Hyprland.monitors.values) {
            const workspaceId = monitor.activeWorkspace?.id ?? -1
            if (workspaceId > 0 && workspaceId !== root.activeWorkspaceId)
                visible[workspaceId] = true
        }
        return visible
    }
    readonly property var occupiedWorkspaceIds: {
        const occupied = {}
        for (const workspace of Hyprland.workspaces.values)
            occupied[workspace.id] = workspace.toplevels.values.length > 0
        return occupied
    }
    readonly property var urgentWorkspaceIds: {
        const urgent = {}
        for (const workspace of Hyprland.workspaces.values) {
            if (workspace.urgent)
                urgent[workspace.id] = true
        }
        for (const toplevel of Hyprland.toplevels.values) {
            if (toplevel.urgent && toplevel.workspace)
                urgent[toplevel.workspace.id] = true
        }
        return urgent
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.centerIn: parent

        Repeater {
            model: root.workspaces

            BarText {
                required property int modelData

                readonly property bool active: root.activeWorkspaceId === modelData
                readonly property bool onOtherMonitor: root.otherMonitorWorkspaceIds[modelData] ?? false
                readonly property bool urgent: root.urgentWorkspaceIds[modelData] ?? false
                readonly property bool empty: !(root.occupiedWorkspaceIds[modelData] ?? false)
                readonly property bool hovered: mouseArea.containsMouse

                width: root.theme.sizing.statusBarWorkspaceSlotSize
                text: root.icons.workspaceDot
                color: root.workspaceColor(urgent, active, onOtherMonitor, hovered, empty)
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
        if (Hyprland.usingLua === true) {
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspaceId} })`)
            return
        }

        Hyprland.dispatch(`workspace ${workspaceId}`)
    }

    function workspaceColor(urgent, active, onOtherMonitor, hovered, empty) {
        if (urgent)
            return palette.red
        if (active)
            return palette.mauve
        if (onOtherMonitor)
            return palette.blue
        if (hovered)
            return palette.teal
        return empty ? palette.surface1 : palette.overlay1
    }
}
