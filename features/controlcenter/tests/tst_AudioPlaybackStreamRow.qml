import QtQuick
import QtTest
import "../components"
import "../../../theme"

TestCase {
    id: testCase
    name: "AudioPlaybackStreamRow"
    when: windowShown
    width: 420
    height: 160

    property var node: ({
                            nickname: "Music",
                            audio: {
                                volume: 0.42,
                                muted: false
                            }
                        })
    property var theme: ({
                             motion: {
                                 opacityDisabled: 0.5
                             },
                             shape: {
                                 radius12: 12,
                                 radius8: 8
                             },
                             spacing: {
                                 space16: 16,
                                 space12: 12,
                                 space8: 8,
                                 space6: 6,
                                 space2: 2,
                                 statusBarSliderHitAreaVerticalMargin: 6
                             },
                             sizing: {
                                 statusBarNetworkQuickControlHeight: 54,
                                 statusBarNetworkQuickControlIconWidth: 22,
                                 statusBarNetworkQuickControlSliderHeight: 32,
                                 statusBarQuickControlTrackHeight: 8,
                                 statusBarSliderHandleSize: 14
                             },
                             typography: {
                                 sizeLg: 16,
                                 sizeMd: 14,
                                 sizeSm: 11,
                                 textFontFamily: "sans",
                                 iconFontFamily: "sans"
                             }
                         })

    Component {
        id: component

        AudioPlaybackStreamRow {
            width: 400
            stream: testCase.node
            icon: "S"
            volumeUnavailableIcon: "U"
            volumeMutedIcon: "M"
            volumeLowIcon: "L"
            volumeMediumIcon: "D"
            volumeHighIcon: "H"
            theme: testCase.theme
        }
    }

    SignalSpy {
        id: muteSpy
        signalName: "muteRequested"
    }
    SignalSpy {
        id: volumeSpy
        signalName: "volumeRequested"
    }

    function row(properties) {
        const value = createTemporaryObject(component, testCase, properties || {})
        verify(value)
        muteSpy.target = value
        volumeSpy.target = value
        muteSpy.clear()
        volumeSpy.clear()
        return value
    }

    function test_exactStreamIntents() {
        const value = row()
        value.requestMute()
        value.requestVolume(140)
        compare(muteSpy.signalArguments[0][0], node)
        compare(volumeSpy.signalArguments[0][0], node)
        compare(volumeSpy.signalArguments[0][1], 100)
    }

    function test_unavailableIsSafe() {
        const value = row({
                              available: false
                          })
        value.requestMute()
        value.requestVolume(50)
        compare(muteSpy.count, 0)
        compare(volumeSpy.count, 0)
    }

    function test_draftsAreLocal() {
        const first = row()
        const second = row({
                               stream: ({
                                            audio: {
                                                volume: 0.8,
                                                muted: false
                                            }
                                        })
                           })
        first.slider.beginInteraction(40)
        verify(first.slider.draftActive)
        verify(!second.slider.draftActive)
    }

    function test_headerAndSliderZonesStaySeparated() {
        const value = row()
        const header = findChild(value, "playbackStreamHeader")
        const sliderZone = findChild(value, "playbackStreamSliderZone")
        verify(header)
        verify(sliderZone)
        verify(header.y + header.height <= sliderZone.y)
        verify(sliderZone.y + sliderZone.height < value.height)
    }

    function test_volumeIconIsMuteActionAndPercentStaysReadOnly() {
        let value = row()
        compare(findChild(value, "playbackStreamVolumeIcon").text, "D")
        compare(findChild(value, "playbackStreamPercentLabel").text, "42%")
        const input = findChild(value, "audioPlaybackMuteAction")
        input.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(muteSpy.count, 1)

        value = row({
                        stream: ({
                                     nickname: "Music",
                                     audio: {
                                         volume: 0.42,
                                         muted: true
                                     }
                                 })
                    })
        compare(findChild(value, "playbackStreamVolumeIcon").text, "M")
        compare(findChild(value, "playbackStreamPercentLabel").text, "42%")
        value = row({
                        stream: ({
                                     nickname: "Music",
                                     audio: {
                                         volume: 0,
                                         muted: false
                                     }
                                 })
                    })
        compare(findChild(value, "playbackStreamVolumeIcon").text, "M")
        value = row({
                        stream: ({
                                     nickname: "Music",
                                     audio: {
                                         volume: 0.2,
                                         muted: false
                                     }
                                 })
                    })
        compare(findChild(value, "playbackStreamVolumeIcon").text, "L")
        value = row({
                        stream: ({
                                     nickname: "Music",
                                     audio: {
                                         volume: 0.9,
                                         muted: false
                                     }
                                 })
                    })
        compare(findChild(value, "playbackStreamVolumeIcon").text, "H")
        value = row({
                        stream: ({
                                     nickname: "Music",
                                     audio: null
                                 })
                    })
        compare(findChild(value, "playbackStreamVolumeIcon").text, "U")
    }
}
