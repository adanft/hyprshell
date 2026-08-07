import QtQuick
import QtTest
import ".."

TestCase {
    id: testCase
    name: "QuickControlSlider"
    when: windowShown
    width: 320
    height: 120

    // Mirrors the tokens QuickControlSlider reads, with the values from
    // theme/Sizing.qml, theme/Spacing.qml, theme/Motion.qml and theme/Colors.qml.
    property var theme: ({
                             sizing: {
                                 statusBarSliderTrackHeight: 5,
                                 statusBarSliderHandleSize: 14
                             },
                             spacing: {
                                 statusBarSliderHitAreaVerticalMargin: 8
                             },
                             motion: {
                                 opacityDisabled: 0.45
                             },
                             colors: {
                                 transparent: "transparent",
                                 text: "#ffffff"
                             }
                         })

    Component {
        id: sliderComponent

        QuickControlSlider {
            width: 200
            height: 32
            liveUpdateInterval: 20
            available: true
            value: 0
            theme: testCase.theme
        }
    }

    SignalSpy {
        id: requestSpy
        signalName: "liveValueRequested"
    }

    SignalSpy {
        id: cancelSpy
        signalName: "interactionCanceled"
    }

    function createSlider(properties) {
        const slider = createTemporaryObject(sliderComponent, testCase, properties || {})
        verify(slider !== null)
        requestSpy.target = slider
        cancelSpy.target = slider
        requestSpy.clear()
        cancelSpy.clear()
        return slider
    }

    function test_dragUpdatesDraftAndFlushesLiveValue() {
        const slider = createSlider()

        slider.beginInteraction(7)
        verify(slider.draftActive)
        compare(slider.draftValue, 0)

        slider.moveInteraction(100)
        compare(slider.draftValue, 50)
        wait(50)
        verify(requestSpy.count >= 2, "active interaction must emit repeatedly")

        slider.finishInteraction(193)
        compare(slider.draftActive, false)
        compare(requestSpy.signalArguments[requestSpy.count - 1][0], 100)
    }

    function test_cancelDiscardsDraftWithoutWriting() {
        const slider = createSlider({
                                        value: 35
                                    })

        slider.draftActive = true
        slider.draftValue = 80
        slider.cancelInteraction()

        compare(slider.draftActive, false)
        compare(slider.displayedValue, 35)
        compare(slider.visualPosition, 0.35)
        compare(requestSpy.count, 0)
        compare(cancelSpy.count, 1)
    }

    function test_unavailableShowsZeroWithoutInteraction() {
        const slider = createSlider({
                                        available: false,
                                        value: 0
                                    })

        compare(slider.enabled, false)
        compare(slider.visualPosition, 0)
        compare(slider.displayedValue, 0)
        compare(requestSpy.count, 0)
    }
}
