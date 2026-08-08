import "../shared/components" as Shared
import QtQuick
import "../theme" as Theme

Rectangle {
    id: chip

    readonly property var theme: Theme.AppTheme

    required property string icon
    property bool selected: false
    readonly property bool hovered: mouseArea.containsMouse

    signal activated

    width: theme.sizing.wallpaperExtensionFilterWidth
    height: theme.sizing.appLauncherSearchHeight
    radius: theme.shape.wallpaperExtensionFilterRadius
    color: hovered ? theme.colors.secondary : (selected ? theme.colors.primary : theme.colors.surface)

    Shared.AppText {
        anchors.centerIn: parent
        text: chip.icon
        color: (chip.hovered || chip.selected) ? chip.theme.colors.primaryText : chip.theme.colors.text
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
