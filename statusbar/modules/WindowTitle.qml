import QtQuick
import Quickshell.Hyprland
import ".."
import "../components"

Row {
    id: root

    readonly property var icons: BarIcons {}
    readonly property var theme: BarTheme {}
    required property var palette

    readonly property var activeToplevel: {
        const toplevel = Hyprland.activeToplevel
        return (toplevel?.workspace?.name?.startsWith("special:") || Hyprland.focusedWorkspace?.toplevels.values.length > 0) ? toplevel : null
    }

    width: theme.windowTitleWidth
    height: theme.height
    spacing: theme.gap

    BarText {
        height: parent.height
        text: root.activeToplevel ? root.icons.window : ""
        color: root.palette.blue
        font.family: root.theme.iconFontFamily
        font.pixelSize: root.theme.iconFontSize
    }

    BarText {
        width: parent.width - x
        height: parent.height
        text: root.activeToplevel?.title ?? ""
        color: root.palette.subtext1
        font.family: root.theme.textFontFamily
        elide: Text.ElideRight
    }
}
