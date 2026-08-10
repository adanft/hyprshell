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

            width: active ? StatusBarSizing.workspaceSlotSize * 2 : StatusBarSizing.workspaceSlotSize
            height: StatusBarSizing.workspaceSlotSize
            radius: root.theme.shape.radiusFull
            color: root.workspaceFill(urgent, active, root.monitorFocused, hovered, empty)

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

    function focusWorkspace(workspaceId) {
        root.services.workspace.focusWorkspace(workspaceId)
    }

    // Every workspace keeps its circle. The tone is the one its dot used to
    // carry, so the row says the same things it always did — urgent, focused
    // here, focused elsewhere, holding windows, empty — and the number is what
    // was added rather than what replaced it.
    function workspaceFill(urgent, active, monitorFocused, hovered, empty) {
        if (urgent)
            return Colors.error
        if (hovered)
            return Colors.hover
        if (active)
            return monitorFocused ? Colors.primary : Colors.tertiary

        return empty ? Colors.outline : Colors.on_surface_variant
    }

    // The number takes the foreground of whatever it is sitting on, the way the
    // launcher's cards do: a hovered pill carries the same dark tone a hovered
    // app card gives its label. The resting fills have no paired foreground of
    // their own, so the number is cut out of them in the bar's own surface.
    function workspaceNumberColor(urgent, active, monitorFocused, hovered, empty) {
        if (urgent)
            return Colors.on_error
        if (hovered)
            return Colors.on_hover
        if (active)
            return monitorFocused ? Colors.on_primary : Colors.on_tertiary

        return Colors.shadow
    }
}
