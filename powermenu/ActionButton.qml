import "../theme"
import QtQuick

Rectangle {
    id: button

    readonly property var
    theme: AppTheme {
    }

    property string icon: ""
    property bool selected: false
    property color accent: theme.colors.mauve
    readonly property bool active: selected || mouseArea.containsMouse

    signal activated()
    signal hovered()

    width: theme.sizing.powerMenuActionSize
    height: theme.sizing.powerMenuActionSize
    radius: theme.shape.powerMenuActionRadius
    color: active ? theme.colors.crust : theme.colors.mantle
    border.width: theme.shape.powerMenuActionBorderWidth
    border.color: active ? accent : theme.colors.base

    Text {
        anchors.centerIn: parent
        text: icon
        color: active ? accent : theme.colors.base
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
