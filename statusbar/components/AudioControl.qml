import QtQuick
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var services
    property bool source: false

    signal openRequested
    readonly property bool available: source ? services.audio.microphoneAvailable : Boolean(services.audio.sink?.audio)
    readonly property int volume: source ? services.audio.sourceVolume : services.audio.sinkVolume
    readonly property bool muted: source ? services.audio.sourceMuted : services.audio.sinkMuted
    // Muted and unavailable are one state here: iconText() already collapses
    // them into the same glyph, so the colour follows.
    readonly property bool moduleDisabled: !available || muted
    readonly property color textColor: moduleDisabled ? Colors.outline : Colors.on_surface

    function iconText() {
        if (!available || muted)
            return source ? icons.microphoneMuted : icons.volumeMuted

        if (source)
            return icons.microphone

        if (volume < 34)
            return icons.volumeLow

        if (volume < 67)
            return icons.volumeMedium

        return icons.volumeHigh
    }

    width: content.implicitWidth
    height: theme.sizing.statusBarHeight

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        BarText {
            text: root.iconText()
            color: root.textColor
        }

        BarText {
            visible: root.available
            text: `${root.volume}%`
            color: root.textColor
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.theme.shape.radius8
        color: "transparent"
        border.color: Colors.primary
        border.width: input.activeFocus ? root.theme.shape.focusBorderWidth : 0
    }

    MouseArea {
        id: input
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        Accessible.name: root.source ? "Open microphone controls" : "Open volume controls"
        Accessible.description: root.available ? (root.muted ? "Muted" : `${root.volume}%`) : "Unavailable"
        // Left opens the panel, right silences. The destructive half of a module
        // is the one that needs aiming for, and every module in the bar reads
        // the same way round.
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.services.audio.toggleMute(root.source)
            else
                root.openRequested()
        }
        Keys.onSpacePressed: root.openRequested()
        Keys.onReturnPressed: root.openRequested()
        Keys.onEnterPressed: root.openRequested()
        onWheel: wheel => {
            const delta = wheel.angleDelta.y
            if (!root.available || delta === 0)
                return
            root.services.audio.changeVolume(root.source, delta > 0 ? 1 : -1)
            wheel.accepted = true
        }
    }
}
