import QtQuick

Rectangle {
    id: button

    property string icon: ""
    property bool selected: false
    property color accent: "#cba6f7"

    readonly property bool active: selected || mouseArea.containsMouse
    readonly property color backgroundColor: active ? "#11111b" : "#181825"
    readonly property color inactiveColor: "#1e1e2e"

    signal activated()
    signal hovered()

    width: 136
    height: 136
    radius: 36
    color: backgroundColor
    border.width: 6
    border.color: active ? accent : inactiveColor

    Text {
        anchors.centerIn: parent
        text: icon
        color: active ? accent : inactiveColor
        font.family: "Symbols Nerd Font"
        font.pixelSize: 68
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
