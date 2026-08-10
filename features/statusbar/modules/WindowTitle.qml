import QtQuick
import Quickshell.Hyprland
import "../components"
import "../../../theme"
import "../../../shared/components"

Row {
    id: root

    readonly property var icons: Icons
    readonly property var theme: AppTheme

    readonly property var activeToplevel: {
        const toplevel = Hyprland.activeToplevel
        return (toplevel?.workspace?.name?.startsWith("special:") || Hyprland.focusedWorkspace?.toplevels.values.length
                > 0) ? toplevel : null
    }

    width: theme.sizing.statusBarWindowTitleWidth
    height: theme.sizing.statusBarHeight
    spacing: theme.spacing.space6

    AppText {
        height: parent.height
        text: root.activeToplevel ? root.icons.window : ""
        color: Colors.tertiary
        font.family: root.theme.typography.iconFontFamily
        font.pixelSize: root.theme.typography.sizeXl
    }

    AppText {
        width: parent.width - x
        height: parent.height
        text: root.activeToplevel?.title ?? ""
        color: Colors.on_surface_variant
        font.family: root.theme.typography.textFontFamily
        elide: Text.ElideRight
    }
}
