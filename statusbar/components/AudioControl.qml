import ".."
import QtQuick

Item {
    id: root

    readonly property var
    icons: BarIcons {
    }

    readonly property var
    theme: BarTheme {
    }

    required property var palette
    required property var services
    property bool source: false
    readonly property int volume: source ? services.sourceVolume : services.sinkVolume
    readonly property bool muted: source ? services.sourceMuted : services.sinkMuted
    readonly property color textColor: source ? palette.flamingo : palette.lavender

    function iconText() {
        if (muted)
            return source ? icons.microphoneMuted : icons.volumeMuted;

        if (source)
            return icons.microphone;

        if (volume < 34)
            return icons.volumeLow;

        if (volume < 67)
            return icons.volumeMedium;

        return icons.volumeHigh;
    }

    width: content.implicitWidth
    height: theme.height

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.gap

        BarText {
            text: root.iconText()
            color: root.textColor
        }

        BarText {
            visible: !root.muted
            text: `${root.volume}%`
            color: root.textColor
        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.services.toggleMute(root.source)
        onWheel: (wheel) => {
            const delta = wheel.angleDelta.y;
            if (delta === 0)
                return;

            root.services.changeVolume(root.source, delta > 0 ? 1 : -1);
            wheel.accepted = true;
        }
    }

}
