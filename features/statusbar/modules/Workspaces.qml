import QtQuick
import Quickshell.Hyprland
import "../components"
import "../../../theme"
import "../../../shared/components"
import ".."

// A Row and nothing wrapping it. It used to be an Item whose implicit size came
// from an inner Row that was in turn anchored to the centre of that Item: each
// side waiting on the other, which Qt settles inconsistently, so the pills drew
// off-centre and the widest one spilled past the module's own background. A Row
// reports its own size, and the bar centres it from outside.
Row {
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

    // A workspace with nothing in it is the same chip turned down, not a chip in
    // another colour: dimming the whole thing keeps the number's contrast against
    // its own circle instead of fading the two apart.
    readonly property real emptyOpacity: 0.25

    spacing: theme.spacing.space4

    Repeater {
        model: root.services.workspace.statusWorkspaceIdsForMonitor(root.monitor)

        // A rectangle rather than a glyph, because the active one grows to twice
        // its width and a glyph cannot be stretched: the font draws its shape at
        // the proportion the font chose, so widening it would scale the number
        // with it. Square at rest, so the radius makes a circle.
        Rectangle {
            id: pill

            required property int modelData

            readonly property bool active: root.monitor?.activeWorkspace?.id === modelData
            readonly property bool urgent: root.services.workspace.statusUrgentWorkspaceIds[modelData] ?? false
            readonly property bool empty: !(root.services.workspace.statusOccupiedWorkspaceIds[modelData] ?? false)
            readonly property bool hovered: mouseArea.containsMouse
            // Emptiness only speaks when nothing else is: the workspace you are
            // standing on is never dimmed for having no windows yet, and neither
            // is one asking for attention or under the pointer.
            readonly property bool resting: !active && !hovered && !urgent

            width: active ? StatusBarSizing.workspaceSlotSize * 2 : StatusBarSizing.workspaceSlotSize
            height: StatusBarSizing.workspaceSlotSize
            radius: root.theme.shape.radiusFull
            color: root.workspaceFill(urgent, active, root.monitorFocused, hovered)
            opacity: empty && resting ? root.emptyOpacity : 1

            Behavior on width {
                NumberAnimation {
                    duration: root.theme.motion.durationShort
                    easing.type: Easing.OutCubic
                }
            }

            AppText {
                anchors.centerIn: parent
                text: pill.modelData
                color: root.workspaceNumberColor(pill.urgent, pill.active, root.monitorFocused, pill.hovered)
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

    function focusWorkspace(workspaceId) {
        root.services.workspace.focusWorkspace(workspaceId)
    }

    // Every workspace keeps its circle, and a resting one is the theme's blue.
    // Emptiness is not a colour here — it is the same chip at a quarter, applied
    // to the whole pill above.
    function workspaceFill(urgent, active, monitorFocused, hovered) {
        if (urgent)
            return Colors.error
        if (hovered)
            return Colors.hover
        if (active)
            return monitorFocused ? Colors.primary : Colors.tertiary

        return Colors.tertiary
    }

    // The number takes the foreground of whatever it is sitting on, the way the
    // launcher's cards do: a hovered pill carries the same dark tone a hovered
    // app card gives its label.
    function workspaceNumberColor(urgent, active, monitorFocused, hovered) {
        if (urgent)
            return Colors.on_error
        if (hovered)
            return Colors.on_hover
        if (active)
            return monitorFocused ? Colors.on_primary : Colors.on_tertiary

        return Colors.on_tertiary
    }
}
