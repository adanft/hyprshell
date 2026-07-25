import QtQuick
import "NetworkMenu.js" as NetworkMenuLogic

Rectangle {
    id: root

    required property var stream
    required property var colors
    required property var theme
    required property string icon
    required property string volumeUnavailableIcon
    required property string volumeMutedIcon
    required property string volumeLowIcon
    required property string volumeMediumIcon
    required property string volumeHighIcon
    property bool available: Boolean(root.stream?.audio && Number.isFinite(Number(root.stream.audio.volume)))
    readonly property alias slider: volumeSlider
    readonly property int percent: NetworkMenuLogic.audioNodePercent(root.stream) ?? 0
    readonly property bool muted: Boolean(root.stream?.audio?.muted)
    readonly property string volumeStateIcon: {
        const kind = NetworkMenuLogic.audioNodeIconKind(root.stream);
        if (kind === "unavailable") return root.volumeUnavailableIcon;
        if (kind === "muted") return root.volumeMutedIcon;
        if (kind === "low") return root.volumeLowIcon;
        if (kind === "medium") return root.volumeMediumIcon;
        return root.volumeHighIcon;
    }

    signal muteRequested(var stream)
    signal volumeRequested(var stream, int value)

    function requestMute() {
        if (root.available)
            root.muteRequested(root.stream);
    }

    function requestVolume(value) {
        if (!root.available)
            return;
        const percent = Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
        root.volumeRequested(root.stream, percent);
    }

    height: root.theme.spacing.space12
        + playbackStreamHeader.height
        + root.theme.spacing.space8
        + playbackStreamSliderZone.height
        + root.theme.spacing.space12
    radius: root.theme.shape.radius12
    color: root.colors.surface
    opacity: root.available ? 1 : root.theme.motion.opacityDisabled

    Accessible.role: Accessible.ListItem
    Accessible.name: `${NetworkMenuLogic.playbackStreamLabel(root.stream)}, ${root.muted ? "Muted" : root.percent + "%"}`

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
            width: root.theme.sizing.statusBarNetworkQuickControlIconWidth
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.colors.text
            horizontalAlignment: Text.AlignHCenter
            font.family: root.theme.typography.iconFontFamily
            font.pixelSize: root.theme.typography.sizeLg
        }

        Column {
            anchors.left: streamIcon.right
            anchors.right: percentLabel.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: root.theme.spacing.space8
            anchors.rightMargin: root.theme.spacing.space8
            spacing: root.theme.spacing.space2

            Text {
                width: parent.width
                text: NetworkMenuLogic.playbackStreamLabel(root.stream)
                color: root.colors.text
                font.family: root.theme.typography.textFontFamily
                font.pixelSize: root.theme.typography.sizeMd
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: NetworkMenuLogic.playbackStreamDescription(root.stream)
                color: root.colors.textSubtle
                font.family: root.theme.typography.textFontFamily
                font.pixelSize: root.theme.typography.sizeSm
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
            color: root.colors.textSubtle
            font.pixelSize: root.theme.typography.sizeSm
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
        height: root.theme.sizing.statusBarNetworkQuickControlSliderHeight

        Row {
            anchors.fill: parent
            spacing: root.theme.spacing.space8

            Rectangle {
                width: root.theme.sizing.statusBarNetworkQuickControlSliderHeight
                height: parent.height
                radius: root.theme.shape.radius8
                color: root.muted
                    ? root.colors.primary
                    : (muteInput.containsMouse || muteInput.activeFocus
                        ? root.colors.surfaceHover
                        : root.colors.transparent)

                Text {
                    objectName: "playbackStreamVolumeIcon"
                    anchors.centerIn: parent
                    text: root.volumeStateIcon
                    color: root.muted ? root.colors.surface : root.colors.text
                    font.family: root.theme.typography.iconFontFamily
                    font.pixelSize: root.theme.typography.sizeLg
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
                    Accessible.name: `${root.muted ? "Unmute" : "Mute"} ${NetworkMenuLogic.playbackStreamLabel(root.stream)}`

                    onClicked: root.requestMute()
                    Keys.onSpacePressed: root.requestMute()
                    Keys.onReturnPressed: root.requestMute()
                    Keys.onEnterPressed: root.requestMute()
                }
            }

            QuickControlSlider {
                id: volumeSlider
                width: parent.width - root.theme.sizing.statusBarNetworkQuickControlSliderHeight - parent.spacing
                height: parent.height
                trackHeight: root.theme.sizing.statusBarQuickControlTrackHeight
                value: root.percent
                available: root.available
                trackColor: root.colors.transparent
                fillColor: root.colors.primary
                handleColor: root.colors.text
                handleBorderColor: root.colors.primary
                unavailableText: "Playback stream unavailable"
                onLiveValueRequested: value => root.requestVolume(value)
            }
        }
    }
}
