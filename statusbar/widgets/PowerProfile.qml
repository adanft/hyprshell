import QtQuick

Pill {
    id: root

    required property var services

    readonly property string profile: services.powerProfile

    textColor: profile === "performance" ? palette.red : profile === "power-saver" ? palette.green : palette.blue
    text: profile === "performance" ? "󰠠" : profile === "power-saver" ? "󱤆" : "󰚀"
    horizontalPadding: 10

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: services.nextPowerProfile()
    }
}
