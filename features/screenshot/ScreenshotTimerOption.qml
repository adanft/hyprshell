import "../../shared/components" as Shared
import "../../theme"
import QtQuick

Rectangle {
    id: option

    readonly property var theme: AppTheme

    required property int value
    property bool selected: false
    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool active: selected || hovered

    signal activated

    width: theme.sizing.screenshotToolTimerOptionWidth
    height: theme.sizing.screenshotToolTimerOptionHeight
    radius: theme.shape.screenshotToolTimerOptionRadius
    color: hovered ? Colors.hover : (selected ? Colors.primary : "transparent")

    Shared.AppText {
        anchors.centerIn: parent
        text: String(option.value)
        color: option.hovered ? Colors.on_hover : (option.selected ? Colors.on_primary : Colors.on_surface)
        font.pixelSize: option.theme.typography.textMd
        font.styleName: option.theme.typography.styleMedium
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: option.activated()
    }
}
