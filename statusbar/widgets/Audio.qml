import QtQuick

Pill {
    id: root

    required property var services
    property bool source: false
    property bool grouped: false

    readonly property int volume: source ? services.sourceVolume : services.sinkVolume
    readonly property bool muted: source ? services.sourceMuted : services.sinkMuted

    textColor: source ? palette.flamingo : palette.lavender
    backgroundColor: grouped ? "transparent" : palette.base
    text: muted ? (source ? "" : "") : `${source ? "" : volumeIcon()}  ${volume}%`
    horizontalPadding: 10

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: services.toggleMute(source)
        onWheel: wheel => services.changeVolume(source, wheel.angleDelta.y > 0 ? 5 : -5)
    }

    function volumeIcon() {
        if (volume < 34)
            return ""
        if (volume < 67)
            return ""
        return ""
    }
}
