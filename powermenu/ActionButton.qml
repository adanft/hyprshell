import "../theme"
import QtQuick

Rectangle {
    id: button

    readonly property var
    theme: AppTheme {
    }

    property string icon: ""
    property bool selected: false
    property color accent: "#cba6f7"
    readonly property bool active: selected || mouseArea.containsMouse
    readonly property color backgroundColor: active ? theme.powerMenuActionBackgroundColor : theme.powerMenuActionInactiveBackgroundColor
    readonly property color inactiveColor: theme.powerMenuActionInactiveColor

    signal activated()
    signal hovered()

    width: theme.powerMenuActionSize
    height: theme.powerMenuActionSize
    radius: theme.powerMenuActionRadius
    color: backgroundColor
    border.width: theme.powerMenuActionBorderWidth
    border.color: active ? accent : inactiveColor

    Text {
        anchors.centerIn: parent
        text: icon
        color: active ? accent : inactiveColor
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
