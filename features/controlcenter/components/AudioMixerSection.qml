import QtQuick
import Quickshell
import "../../../theme"
import "../../../shared/components"
import ".."

Column {
    id: root

    required property var audio
    required property var theme
    required property var icons
    required property var outputQuickVolume
    required property bool outputAvailable
    required property string outputIcon

    signal masterVolumeRequested(int value)

    spacing: root.theme.spacing.space6

    ScriptModel {
        id: audioOutputsModel
        values: root.audio.audioOutputs ?? []
    }

    ScriptModel {
        id: playbackStreamsModel
        values: root.audio.playbackStreams ?? []
    }

    AppText {
        width: parent.width
        text: "Output volume"
        color: Colors.on_surface_variant
        font.pixelSize: root.theme.typography.textMd
        font.styleName: root.theme.typography.styleRegular
    }

    Item {
        width: parent.width
        height: ControlCenterSizing.quickControlHeight

        Row {
            anchors.fill: parent
            spacing: root.theme.spacing.space6

            AppText {
                width: ControlCenterSizing.quickControlIconWidth
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.outputIcon
                color: outputVolumeSlider.enabled ? Colors.on_surface : Colors.on_surface_variant
                font.family: root.theme.typography.iconFontFamily
                font.pixelSize: root.theme.typography.textLg
                font.styleName: root.theme.typography.styleRegular
            }

            QuickControlSlider {
                id: outputVolumeSlider
                theme: root.theme
                width: parent.width - ControlCenterSizing.quickControlIconWidth - parent.spacing
                height: ControlCenterSizing.quickControlSliderHeight
                anchors.verticalCenter: parent.verticalCenter
                trackHeight: ControlCenterSizing.quickControlTrackHeight
                value: root.outputQuickVolume?.authoritativePercent ?? 0
                available: root.outputAvailable
                trackColor: Colors.surface_variant
                fillColor: Colors.primary
                handleColor: Colors.on_surface
                handleBorderColor: Colors.primary
                unavailableText: root.outputQuickVolume?.errorText || "Volume unavailable"
                onLiveValueRequested: value => root.masterVolumeRequested(value)
            }
        }
    }

    Column {
        id: outputDevicesSection

        width: parent.width
        spacing: root.theme.spacing.space6

        AppText {
            width: parent.width
            text: "Output devices"
            color: Colors.on_surface_variant
            font.pixelSize: root.theme.typography.textMd
            font.styleName: root.theme.typography.styleRegular
        }

        Column {
            id: outputDevicesList
            width: parent.width
            spacing: root.theme.spacing.space6

            Repeater {
                model: audioOutputsModel

                AudioOutputDeviceRow {
                    required property var modelData
                    width: outputDevicesList.width
                    device: modelData
                    active: modelData === root.audio.sink
                    icon: root.icons.audio.output
                    theme: root.theme
                    onSelectRequested: device => root.audio.selectAudioSink(device)
                }
            }

            ControlEmptyState {
                visible: (root.audio.audioOutputs?.length ?? 0) === 0
                width: parent.width
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

        width: parent.width
        spacing: root.theme.spacing.space6

        AppText {
            width: parent.width
            text: "Playback streams"
            color: Colors.on_surface_variant
            font.pixelSize: root.theme.typography.textMd
            font.styleName: root.theme.typography.styleRegular
        }

        Column {
            id: playbackStreamsList
            width: parent.width
            spacing: root.theme.spacing.space6

            Repeater {
                model: playbackStreamsModel

                AudioPlaybackStreamRow {
                    required property var modelData
                    width: playbackStreamsList.width
                    stream: modelData
                    icon: root.icons.audio.stream
                    volumeUnavailableIcon: root.icons.audio.volumeUnavailable
                    volumeMutedIcon: root.icons.audio.volumeMuted
                    volumeLowIcon: root.icons.audio.volumeLow
                    volumeMediumIcon: root.icons.audio.volumeMedium
                    volumeHighIcon: root.icons.audio.volumeHigh
                    theme: root.theme
                    onMuteRequested: stream => root.audio.togglePlaybackStreamMute(stream)
                    onVolumeRequested: (stream, value) => root.audio.requestPlaybackStreamVolume(stream, value)
                }
            }

            ControlEmptyState {
                visible: (root.audio.playbackStreams?.length ?? 0) === 0
                width: parent.width
                theme: root.theme
                title: "No active playback streams"
                description: "Applications playing audio appear here"
            }
        }
    }
}
