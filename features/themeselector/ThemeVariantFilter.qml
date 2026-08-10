import "../../shared/components" as Shared
import QtQuick
import "../../theme" as Theme

Rectangle {
    id: chip

    readonly property var theme: Theme.AppTheme

    required property string icon
    property bool selected: false
    readonly property bool hovered: mouseArea.containsMouse

    signal activated

    width: theme.sizing.themeVariantFilterWidth
    height: theme.sizing.appLauncherSearchHeight
    radius: theme.shape.wallpaperExtensionFilterRadius
    color: hovered ? Theme.Colors.hover : (selected ? Theme.Colors.primary : Theme.Colors.surface)

    Shared.AppText {
        anchors.centerIn: parent
        text: chip.icon
        color: chip.hovered ? Theme.Colors.on_hover : (chip.selected ? Theme.Colors.on_primary : Theme.Colors.on_surface)
        font.family: chip.theme.typography.iconFontFamily
        font.pixelSize: chip.theme.sizing.size24
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.activated()
    }
}
