import QtQuick

Rectangle {
    id: pill

    required property var palette
    property alias text: label.text
    property color textColor: palette.subtext1
    property color backgroundColor: palette.base
    property int horizontalPadding: 12

    implicitWidth: label.implicitWidth + horizontalPadding * 2
    implicitHeight: 30
    radius: 999
    color: backgroundColor

    Text {
        id: label
        anchors.centerIn: parent
        color: pill.textColor
        font.family: "SF Pro Display, Symbols Nerd Font"
        font.pixelSize: 16
        font.weight: Font.DemiBold
    }
}
