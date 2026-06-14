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

    width: theme.powerMenuActionSize
    height: theme.powerMenuActionSize
    radius: theme.powerMenuActionRadius
    color: active ? theme.colors.crust : theme.colors.mantle
    border.width: theme.powerMenuActionBorderWidth
    border.color: active ? accent : theme.colors.base

    Text {
        anchors.centerIn: parent
        text: icon
        color: active ? accent : theme.colors.base
        font.family: theme.iconFontFamily
        font.pixelSize: theme.powerMenuActionIconFontSize
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
