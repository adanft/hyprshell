import QtQuick
import "../../../theme"
import "../../../shared/components"

// The microphone panel, shaped like AudioMixerSection: a labelled slider over a
// labelled device list. Both audio sections are components so neither one grows
// back into ControlCenter.
Column {
    id: root

    required property var theme
    required property var services
    readonly property var icons: Icons

    signal inputVolumeRequested(real value)

    spacing: root.theme.spacing.space6

    AppText {
        width: parent.width
        text: "Input volume"
        color: Colors.on_surface_variant
        font.pixelSize: root.theme.typography.textMd
        font.styleName: root.theme.typography.styleRegular
    }

    Item {
        width: parent.width
        height: root.theme.sizing.statusBarNetworkQuickControlHeight

        Row {
            anchors.fill: parent
            spacing: root.theme.spacing.space6

            AppText {
                width: root.theme.sizing.statusBarNetworkQuickControlIconWidth
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.services.audio.sourceMuted ? root.icons.audio.microphoneMuted : root.icons.audio.microphone
                color: microphoneSlider.enabled ? Colors.on_surface : Colors.on_surface_variant
                font.family: root.theme.typography.iconFontFamily
                font.pixelSize: root.theme.typography.textLg
                font.styleName: root.theme.typography.styleRegular
            }

            QuickControlSlider {
                id: microphoneSlider

                theme: root.theme
                width: parent.width - root.theme.sizing.statusBarNetworkQuickControlIconWidth - parent.spacing
                height: root.theme.sizing.statusBarNetworkQuickControlSliderHeight
                anchors.verticalCenter: parent.verticalCenter
                trackHeight: root.theme.sizing.statusBarQuickControlTrackHeight
                value: Math.max(0, root.services.audio.sourceVolume)
                available: root.services.audio.microphoneAvailable
                trackColor: Colors.surface_variant
                fillColor: Colors.primary
                handleColor: Colors.on_surface
                handleBorderColor: Colors.primary
                unavailableText: "Microphone unavailable"
                onLiveValueRequested: value => root.inputVolumeRequested(value)
            }
        }
    }

    AppText {
        width: parent.width
        text: "Input devices"
        color: Colors.on_surface_variant
        font.pixelSize: root.theme.typography.textMd
        font.styleName: root.theme.typography.styleRegular
    }

    Column {
        id: microphoneDevicesSection

        width: parent.width
        spacing: root.theme.spacing.space6

        Repeater {
            model: root.services.audio.audioSources ?? []

            MicrophoneSourceRow {
                required property var modelData

                width: parent.width
                source: modelData
                icon: root.services.audio.sourceMuted ? root.icons.audio.microphoneMuted : root.icons.audio.microphone
                active: modelData === root.services.audio.source
                theme: root.theme
                onSelectRequested: source => root.services.audio.selectAudioSource(source)
            }
        }

        ControlEmptyState {
            visible: (root.services.audio.audioSources?.length ?? 0) === 0
            width: parent.width
            theme: root.theme
            title: root.services.audio.microphoneAvailable ? "No additional microphone inputs"
                                                           : "Microphone unavailable"
            description: root.services.audio.microphoneAvailable
                         ? "The active microphone is already selected"
                         : "Connect an input device to control it here"
        }
    }
}
