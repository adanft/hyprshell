import QtQuick
import Quickshell

Column {
    id: root

    required property var audio
    required property var colors
    required property var theme
    required property var icons
    required property var outputQuickVolume
    required property bool outputAvailable
    required property string outputIcon

    signal masterVolumeRequested(int value)

    spacing: root.theme.spacing.space8

    ScriptModel {
        id: audioOutputsModel
        values: root.audio.audioOutputs ?? []
    }

    ScriptModel {
        id: playbackStreamsModel
        values: root.audio.playbackStreams ?? []
    }

    BarText {
        x: root.theme.spacing.space12
        width: parent.width - root.theme.spacing.space24
        text: "Output volume"
        color: root.colors.textSubtle
        font.pixelSize: root.theme.typography.sizeMd
        font.styleName: root.theme.typography.styleRegular
    }

    Rectangle {
        width: parent.width
        height: root.theme.sizing.statusBarNetworkQuickControlHeight
        radius: root.theme.shape.radius12
        color: root.colors.transparent
        border.width: 0

        Row {
            anchors.fill: parent
            anchors.margins: root.theme.spacing.space12
            spacing: root.theme.spacing.space8

            BarText {
                width: root.theme.sizing.statusBarNetworkQuickControlIconWidth
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.outputIcon
                color: outputVolumeSlider.enabled ? root.colors.text : root.colors.textMuted
                font.family: root.theme.typography.iconFontFamily
                font.pixelSize: root.theme.typography.sizeXl
                font.styleName: root.theme.typography.styleRegular
            }

            QuickControlSlider {
                id: outputVolumeSlider
                width: parent.width - root.theme.sizing.statusBarNetworkQuickControlIconWidth - parent.spacing
                height: root.theme.sizing.statusBarNetworkQuickControlSliderHeight
                anchors.verticalCenter: parent.verticalCenter
                trackHeight: root.theme.sizing.statusBarQuickControlTrackHeight
                value: root.outputQuickVolume?.authoritativePercent ?? 0
                available: root.outputAvailable
                trackColor: root.colors.surface
                fillColor: root.colors.primary
                handleColor: root.colors.text
                handleBorderColor: root.colors.primary
                unavailableText: root.outputQuickVolume?.errorText || "Volume unavailable"
                onLiveValueRequested: value => root.masterVolumeRequested(value)
            }
        }
    }

    Column {
        id: outputDevicesSection

        x: root.theme.spacing.space12
        width: parent.width - root.theme.spacing.space24
        spacing: root.theme.spacing.space8

        BarText {
            width: parent.width
            text: "Output devices"
            color: root.colors.textSubtle
            font.pixelSize: root.theme.typography.sizeMd
            font.styleName: root.theme.typography.styleRegular
        }

        Column {
            id: outputDevicesList
            width: parent.width
            spacing: root.theme.spacing.space8

            Repeater {
                model: audioOutputsModel

                AudioOutputDeviceRow {
                    required property var modelData
                    width: outputDevicesList.width
                    device: modelData
                    active: modelData === root.audio.sink
                    icon: root.icons.audioOutput
                    colors: root.colors
                    theme: root.theme
                    onSelectRequested: device => root.audio.selectAudioSink(device)
                }
            }

            ControlEmptyState {
                visible: (root.audio.audioOutputs?.length ?? 0) === 0
                width: parent.width
                colors: root.colors
                theme: root.theme
                title: "No audio outputs"
                description: "Connect an output device to select it here"
            }
        }
    }

    Item {
        id: playbackSectionSpacer
        width: parent.width
        height: root.theme.spacing.space8
    }

    Column {
        id: playbackStreamsSection

        x: root.theme.spacing.space12
        width: parent.width - root.theme.spacing.space24
        spacing: root.theme.spacing.space8

        BarText {
            width: parent.width
            text: "Playback streams"
            color: root.colors.textSubtle
            font.pixelSize: root.theme.typography.sizeMd
            font.styleName: root.theme.typography.styleRegular
        }

        Column {
            id: playbackStreamsList
            width: parent.width
            spacing: root.theme.spacing.space8

            Repeater {
                model: playbackStreamsModel

                AudioPlaybackStreamRow {
                    required property var modelData
                    width: playbackStreamsList.width
                    stream: modelData
                    icon: root.icons.audioStream
                    volumeUnavailableIcon: root.icons.volumeUnavailable
                    volumeMutedIcon: root.icons.volumeMuted
                    volumeLowIcon: root.icons.volumeLow
                    volumeMediumIcon: root.icons.volumeMedium
                    volumeHighIcon: root.icons.volumeHigh
                    colors: root.colors
                    theme: root.theme
                    onMuteRequested: stream => root.audio.togglePlaybackStreamMute(stream)
                    onVolumeRequested: (stream, value) => root.audio.requestPlaybackStreamVolume(stream, value)
                }
            }

            ControlEmptyState {
                visible: (root.audio.playbackStreams?.length ?? 0) === 0
                width: parent.width
                colors: root.colors
                theme: root.theme
                title: "No active playback streams"
                description: "Applications playing audio appear here"
            }
        }
    }
}
