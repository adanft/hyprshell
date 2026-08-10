import QtQuick
import "../ControlCenter.js" as ControlCenterLogic
import "../../../theme"
import ".."

Rectangle {
    id: root

    required property var stream
    required property var theme
    required property string icon
    required property string volumeUnavailableIcon
    required property string volumeMutedIcon
    required property string volumeLowIcon
    required property string volumeMediumIcon
    required property string volumeHighIcon
    property bool available: Boolean(root.stream?.audio && Number.isFinite(Number(root.stream.audio.volume)))
    readonly property alias slider: volumeSlider
    readonly property int percent: ControlCenterLogic.audioNodePercent(root.stream) ?? 0
    readonly property bool muted: Boolean(root.stream?.audio?.muted)
    readonly property string volumeStateIcon: {
        const kind = ControlCenterLogic.audioNodeIconKind(root.stream)
        if (kind === "unavailable")
            return root.volumeUnavailableIcon
        if (kind === "muted")
            return root.volumeMutedIcon
        if (kind === "low")
            return root.volumeLowIcon
        if (kind === "medium")
            return root.volumeMediumIcon
        return root.volumeHighIcon
    }

    signal muteRequested(var stream)
    signal volumeRequested(var stream, int value)

    function requestMute() {
        if (root.available)
            root.muteRequested(root.stream)
    }

    function requestVolume(value) {
        if (!root.available)
            return
        const percent = Math.max(0, Math.min(100, Math.round(Number(value) || 0)))
        root.volumeRequested(root.stream, percent)
    }

    height: root.theme.spacing.space12 + playbackStreamHeader.height + root.theme.spacing.space8 + playbackStreamSliderZone.height
            + root.theme.spacing.space12
    radius: root.theme.shape.radius12
    color: Colors.surface
    opacity: root.available ? 1 : root.theme.motion.opacityDisabled

    Accessible.role: Accessible.ListItem
    Accessible.name: [ControlCenterLogic.playbackStreamLabel(root.stream), ", ", root.muted ? "Muted" : root.percent + "%"].join(
        "")

    Item {
        id: playbackStreamHeader
        objectName: "playbackStreamHeader"

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.theme.spacing.space12
        anchors.leftMargin: root.theme.spacing.space12
        anchors.rightMargin: root.theme.spacing.space12
        height: root.theme.spacing.space16 * 2

        Text {
            id: streamIcon
            width: ControlCenterSizing.quickControlIconWidth
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: Colors.on_surface
            horizontalAlignment: Text.AlignHCenter
            font.family: root.theme.typography.iconFontFamily
            font.pixelSize: root.theme.typography.textBase
        }

        Column {
            anchors.left: streamIcon.right
            anchors.right: percentLabel.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: root.theme.spacing.space12
            anchors.rightMargin: root.theme.spacing.space12
            spacing: root.theme.spacing.space2

            Text {
                width: parent.width
                text: ControlCenterLogic.playbackStreamLabel(root.stream)
                color: Colors.on_surface
                font.family: root.theme.typography.textFontFamily
                font.pixelSize: root.theme.typography.textMd
                font.styleName: root.theme.typography.styleSemibold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: ControlCenterLogic.playbackStreamDescription(root.stream)
                color: Colors.on_surface_variant
                font.family: root.theme.typography.textFontFamily
                font.pixelSize: root.theme.typography.textSm
                font.styleName: root.theme.typography.styleRegular
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Text {
            id: percentLabel
            objectName: "playbackStreamPercentLabel"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.percent + "%"
            color: Colors.on_surface_variant
            font.pixelSize: root.theme.typography.textSm
            font.styleName: root.theme.typography.styleRegular
        }
    }

    Item {
        id: playbackStreamSliderZone
        objectName: "playbackStreamSliderZone"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.theme.spacing.space12
        anchors.rightMargin: root.theme.spacing.space12
        anchors.bottomMargin: root.theme.spacing.space12
        height: ControlCenterSizing.quickControlSliderHeight

        Row {
            anchors.fill: parent
            spacing: root.theme.spacing.space6

            Rectangle {
                width: ControlCenterSizing.quickControlSliderHeight
                height: parent.height
                radius: height / 2
                color: root.muted ? Colors.primary : (muteInput.containsMouse || muteInput.activeFocus
                                                           ? Colors.hover : "transparent")

                Text {
                    objectName: "playbackStreamVolumeIcon"
                    anchors.centerIn: parent
                    text: root.volumeStateIcon
                    color: root.muted ? Colors.on_primary : (muteInput.containsMouse || muteInput.activeFocus
                                                                  ? Colors.on_hover : Colors.on_surface)
                    font.family: root.theme.typography.iconFontFamily
                    font.pixelSize: root.theme.typography.textBase
                }

                MouseArea {
                    id: muteInput
                    objectName: "audioPlaybackMuteAction"
                    anchors.fill: parent
                    enabled: root.available
                    hoverEnabled: true
                    activeFocusOnTab: enabled
                    cursorShape: muteInput.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                    Accessible.role: Accessible.Button
                    Accessible.name: [root.muted ? "Unmute" : "Mute", " ", ControlCenterLogic.playbackStreamLabel(
                            root.stream)].join("")

                    onClicked: root.requestMute()
                    Keys.onSpacePressed: root.requestMute()
                    Keys.onReturnPressed: root.requestMute()
                    Keys.onEnterPressed: root.requestMute()
                }
            }

            QuickControlSlider {
                id: volumeSlider
                theme: root.theme
                width: parent.width - ControlCenterSizing.quickControlSliderHeight - parent.spacing
                height: ControlCenterSizing.quickControlSliderHeight
                anchors.verticalCenter: parent.verticalCenter
                trackHeight: ControlCenterSizing.quickControlTrackHeight
                value: root.percent
                available: root.available
                trackColor: Colors.surface_variant
                fillColor: Colors.primary
                handleColor: Colors.on_surface
                handleBorderColor: Colors.primary
                unavailableText: "Playback stream unavailable"
                onLiveValueRequested: value => root.requestVolume(value)
            }
        }
    }
}
