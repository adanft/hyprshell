import QtQuick
import Quickshell.Hyprland
import "../components"
import "../../../theme"
import "../../../shared/components"
import ".."

Item {
    id: root

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
        spacing: root.theme.spacing.space4

        Repeater {
            model: root.services.workspace.statusWorkspaceIdsForMonitor(root.monitor)

            // A pill rather than a glyph. The active one has to grow to twice
            // its width, and a glyph cannot be stretched — its shape is drawn by
            // the font at whatever proportion the font chose, so widening it
            // would mean scaling the whole thing, number included. A rectangle
            // takes an exact radius, animates its width, and leaves the number
            // the same size whether it is wearing the wide pill or not.
            Rectangle {
                id: pill

                required property int modelData

                readonly property bool active: root.monitor?.activeWorkspace?.id === modelData
                readonly property bool urgent: root.services.workspace.statusUrgentWorkspaceIds[modelData] ?? false
                readonly property bool empty: !(root.services.workspace.statusOccupiedWorkspaceIds[modelData] ?? false)
                readonly property bool hovered: mouseArea.containsMouse

                width: active ? StatusBarSizing.workspaceSlotSize * 2 : StatusBarSizing.workspaceSlotSize
                height: StatusBarSizing.workspaceSlotSize
                radius: root.theme.shape.radiusFull
                color: root.workspaceFill(urgent, active, root.monitorFocused, hovered)

                Behavior on width {
                    NumberAnimation {
                        duration: root.theme.motion.durationShort
                        easing.type: Easing.OutCubic
                    }
                }

                AppText {
                    anchors.centerIn: parent
                    text: pill.modelData
                    color: root.workspaceNumberColor(pill.urgent, pill.active, root.monitorFocused, pill.hovered,
                                                     pill.empty)
                    font.family: root.theme.typography.textFontFamily
                    font.pixelSize: root.theme.typography.textSm
                    font.styleName: root.theme.typography.styleSemibold
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(pill.modelData)
                }
            }
        }
    }

    function focusWorkspace(workspaceId) {
        root.services.workspace.focusWorkspace(workspaceId)
    }

    // The pill is painted only when the workspace has something to say. A
    // resting workspace stays as its bare number, so the row reads as a set of
    // numbers with one of them lit rather than as a wall of chips.
    function workspaceFill(urgent, active, monitorFocused, hovered) {
        if (urgent)
            return Colors.error
        if (hovered)
            return Colors.hover
        if (active)
            return monitorFocused ? Colors.primary : Colors.tertiary

        return "transparent"
    }

    // On a painted pill the number takes that fill's own foreground, which is
    // the dark tone the launcher's cards use under a hover. Unpainted, it keeps
    // the muted body colour, dimmer again when the workspace holds nothing.
    function workspaceNumberColor(urgent, active, monitorFocused, hovered, empty) {
        if (urgent)
            return Colors.on_error
        if (hovered)
            return Colors.on_hover
        if (active)
            return monitorFocused ? Colors.on_primary : Colors.on_tertiary

        return empty ? Colors.outline : Colors.on_surface_variant
    }
}
