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

    // How far a workspace holding nothing is faded back from one holding
    // windows. The two wear the same colour; this is the whole difference.
    readonly property real unusedVeil: 0.5

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
            readonly property bool hovered: mouseArea.containsMouse
            readonly property bool unused: !(root.services.workspace.statusOccupiedWorkspaceIds[modelData] ?? false)
            // The accent marks one workspace on the whole desk: the one being
            // typed into. A monitor showing a workspace without holding the
            // keyboard says so by the width of its pill, which no other
            // workspace has, so it needs no colour of its own.
            readonly property bool accented: active && root.monitorFocused

            width: active ? StatusBarSizing.workspaceSlotSize * 2 : StatusBarSizing.workspaceSlotSize
            height: StatusBarSizing.workspaceSlotSize
            radius: root.theme.shape.radiusFull
            color: root.workspaceFill(urgent, accented, hovered, unused)

            Behavior on width {
                NumberAnimation {
                    duration: root.theme.motion.durationShort
                    easing.type: Easing.OutCubic
                }
            }

            // Filling the pill rather than sitting centred inside it. A text
            // box is as tall as the font's line — 14.31px here, not a whole
            // number — so centring it within eighteen puts its top on a
            // fractional pixel and the glyph rasterises onto whichever row that
            // lands nearest. Given the pill itself to align in, the alignment
            // happens against exact edges instead.
            AppText {
                anchors.fill: parent
                text: pill.modelData
                color: root.workspaceNumberColor(pill.urgent, pill.accented, pill.hovered)
                font.family: root.theme.typography.textFontFamily
                font.pixelSize: root.theme.typography.textSm
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
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

    // A workspace at rest wears secondary, and one holding nothing wears the
    // same colour faded back. Emptiness is an amount of one tone rather than a
    // second tone, so the row stays a single colour with some of it dimmed —
    // and how dim is a dial rather than a search for a role that lands right.
    //
    // The surface roles are deliberately not used here. They would put these
    // circles on the same ladder the bar and its menus climb, where a workspace
    // is not a raised surface but a mark on one.
    function workspaceFill(urgent, accented, hovered, unused) {
        if (urgent)
            return Colors.error
        if (hovered)
            return Colors.hover
        if (accented)
            return Colors.primary

        return unused ? Qt.alpha(Colors.secondary, root.unusedVeil) : Colors.secondary
    }

    // The number takes the foreground of whatever it is sitting on, the way the
    // launcher's cards do: a hovered pill carries the same dark tone a hovered
    // app card gives its label. A faded circle keeps its own foreground, since
    // the fade is the circle's to show and the number stays one tone per
    // surface.
    function workspaceNumberColor(urgent, accented, hovered) {
        if (urgent)
            return Colors.on_error
        if (hovered)
            return Colors.on_hover
        if (accented)
            return Colors.on_primary

        return Colors.on_secondary
    }
}
