import QtQuick
import Quickshell.Hyprland

Row {
    id: root

    required property var palette

    width: 420
    height: 30
    spacing: 6

    Text {
        height: parent.height
        text: Hyprland.activeToplevel ? "󰰤" : ""
        color: root.palette.blue
        font.family: "SF Pro Display, Symbols Nerd Font"
        font.pixelSize: 16
        font.weight: Font.DemiBold
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        width: parent.width - x
        height: parent.height
        text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
        color: root.palette.subtext1
        font.family: "SF Pro Display, Symbols Nerd Font"
        font.pixelSize: 16
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
