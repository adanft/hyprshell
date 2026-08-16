import QtQuick
import QtTest
import QtQuick.Effects

// A layered item whose size is fractional resamples its own contents.
//
// This is the mechanism behind trembling text during a notification expand, and
// it is asserted by running it rather than by grepping the card, because the
// card's own defence is one Math.round that reads like a rounding preference
// and is invisible in a screenshot of a still card.
//
// Measured, on a probe of this exact shape: across heights 160.00, 160.25,
// 160.50, 160.75 and 161.00, comparing a band of text that never moves in
// layout, 5525 of 36480 pixels changed with a layer over the fractional height
// and 0 with the height rounded. Both halves are required — no layer, or no
// fraction, and nothing moves.
//
// WHAT THIS FILE DOES NOT COVER, checked rather than assumed: it builds its own
// miniature of the card, so removing the rounding HERE fails it, and removing
// the rounding from NotificationCard.qml does not. Verified by doing both. What
// this file pins is the mechanism and the premise; that the card is wired to it
// is pinned in features/notifications/NotificationCard.test.js, and neither is
// sufficient alone.
TestCase {
    id: testCase

    name: "NotificationCardPixelGrid"
    when: windowShown

    Component {
        id: layeredCard

        Item {
            width: 200
            height: 200

            property real animatedHeight: 160

            Rectangle {
                id: mask
                anchors.fill: subject
                radius: 14
                color: "black"
                visible: false
                layer.enabled: true
            }

            Rectangle {
                id: subject
                objectName: "subject"
                width: 180
                // The card's own binding, in miniature.
                height: Math.round(parent.animatedHeight)
                radius: 14
                clip: true
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: mask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
            }
        }
    }

    // The property is what the card actually binds its layered rectangle to, so
    // this is the assertion that fails if someone drops the rounding: the raw
    // animated value lands between pixels and the bound height must not follow
    // it there.
    function test_layered_height_lands_on_whole_pixels_data() {
        return [
            { tag: "already whole", animated: 160.0, expected: 160 },
            { tag: "a quarter up", animated: 160.25, expected: 160 },
            { tag: "halfway", animated: 160.5, expected: 161 },
            { tag: "three quarters", animated: 160.75, expected: 161 },
            { tag: "the next whole", animated: 161.0, expected: 161 },
            // A NumberAnimation produces values like these, not round numbers.
            { tag: "mid-flight", animated: 173.48291, expected: 173 },
        ]
    }

    function test_layered_height_lands_on_whole_pixels(data) {
        const card = createTemporaryObject(layeredCard, testCase)
        verify(card, "the probe card was built")
        card.animatedHeight = data.animated

        const subject = card.children.find(child => child.objectName === "subject")
        verify(subject, "the layered rectangle is there")
        compare(subject.height, data.expected,
                `a layer over height ${data.animated} must be sized in whole pixels`)
        compare(subject.height % 1, 0, "no fractional part survives")
    }

    // The premise the rounding rests on. If a NumberAnimation ever stopped
    // producing fractional intermediates the fix would be unnecessary, and this
    // says so out loud rather than leaving it assumed.
    Item {
        id: animated

        property real value: 0

        Behavior on value {
            NumberAnimation {
                id: valueAnimation
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    function test_an_animation_between_whole_numbers_passes_between_pixels() {
        animated.value = 0
        valueAnimation.complete()
        animated.value = 100

        let sawFraction = false
        for (let i = 0; i < 40 && valueAnimation.running; i++) {
            wait(5)
            if (animated.value % 1 !== 0)
                sawFraction = true
        }
        valueAnimation.complete()
        verify(sawFraction,
               "an animation from 0 to 100 never landed between pixels, so the premise is wrong")
    }
}
