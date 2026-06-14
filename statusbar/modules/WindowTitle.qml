import QtQuick
import Quickshell.Hyprland
import "../components"
import "../../theme"

Row {
    id: root

    readonly property var icons: Icons {}
    readonly property var theme: AppTheme {}
    required property var palette

    readonly property var activeToplevel: {
        const toplevel = Hyprland.activeToplevel
        return (toplevel?.workspace?.name?.startsWith("special:") || Hyprland.focusedWorkspace?.toplevels.values.length > 0) ? toplevel : null
    }

    width: theme.sizing.statusBarWindowTitleWidth
    height: theme.sizing.statusBarHeight
    spacing: theme.spacing.space6

    BarText {
        height: parent.height
        text: root.activeToplevel ? root.icons.window : ""
        color: root.palette.blue
        font.family: root.theme.typography.iconFontFamily
        font.pixelSize: root.theme.typography.sizeXl
    }

    BarText {
        width: parent.width - x
        height: parent.height
        text: root.activeToplevel?.title ?? ""
        color: root.palette.subtext1
        font.family: root.theme.typography.textFontFamily
        elide: Text.ElideRight
    }
}
