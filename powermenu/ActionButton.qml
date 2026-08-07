import "../theme"
import QtQuick

Rectangle {
    id: button

    readonly property var theme: AppTheme

    property string icon: ""
    property bool selected: false
    property color primary: theme.colors.primary
    readonly property bool active: selected || mouseArea.containsMouse

    signal activated
    signal hovered

    width: theme.sizing.powerMenuActionSize
    height: theme.sizing.powerMenuActionSize
    radius: theme.shape.powerMenuActionRadius
    color: active ? theme.colors.surfaceInverse : theme.colors.surface
    border.width: theme.shape.powerMenuActionBorderWidth
    border.color: active ? primary : theme.colors.background

    Text {
        anchors.centerIn: parent
        text: icon
        color: active ? primary : theme.colors.background
        font.family: theme.typography.iconFontFamily
        font.pixelSize: theme.typography.heroIconFontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: button.hovered()
        onClicked: button.activated()
    }
}
