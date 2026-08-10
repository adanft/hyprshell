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

    // An empty workspace fades its circle and keeps its number. Only the fill
    // drops, so the row still reads as the same set of numbers with some of
    // their circles turned down.
    readonly property real emptyFillOpacity: 0.1

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
            color: root.workspaceFill(urgent, active, root.monitorFocused, hovered, empty && resting)

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
                                                 pill.empty && pill.resting)
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
    // An unused one keeps the same blue at a tenth, so the circle is barely
    // there rather than a different colour.
    function workspaceFill(urgent, active, monitorFocused, hovered, unused) {
        if (urgent)
            return Colors.error
        if (hovered)
            return Colors.hover
        if (active)
            return monitorFocused ? Colors.primary : Colors.tertiary

        return unused ? Qt.alpha(Colors.tertiary, root.emptyFillOpacity) : Colors.tertiary
    }

    // The number takes the foreground of whatever it is sitting on, the way the
    // launcher's cards do: a hovered pill carries the same dark tone a hovered
    // app card gives its label.
    //
    // An unused workspace is the exception, and it has to be. on_tertiary is
    // very nearly black, which is right on a filled blue circle and invisible on
    // one at a tenth, so the number there is the blue itself: undimmed, as
    // legible as the others, and still recognisably the same chip.
    function workspaceNumberColor(urgent, active, monitorFocused, hovered, unused) {
        if (urgent)
            return Colors.on_error
        if (hovered)
            return Colors.on_hover
        if (active)
            return monitorFocused ? Colors.on_primary : Colors.on_tertiary

        return unused ? Colors.tertiary : Colors.on_tertiary
    }
}
