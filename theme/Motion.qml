pragma Singleton
import QtQuick

QtObject {
    readonly property int durationShort: 120
    readonly property int durationNormal: 220
    readonly property int durationEntrance: 260
    readonly property int layoutFinalizeDelay: 32

    // Here for the same reason the durations are: the curve is half of how a
    // movement reads, and leaving it at each call site is how four of them drifted
    // to Easing.Linear while the rest of the shell decelerated. Linear has no
    // acceleration at either end — it leaves at full speed and stops dead — so it
    // reads as mechanical at a perfect frame rate, which sends anyone looking for
    // the fault in the renderer.
    //
    // Standard covers anything moving or resizing on screen: immediate on the way
    // out, soft on the landing, so a movement the person asked for answers at once
    // and still settles. Exit is the other half of the pair, for something leaving
    // the screen, where gathering speed reads as dismissed rather than as retreat.
    //
    // Watch what these evaluate to before trusting a change here. Easing.Linear is
    // 0, so a token that fails to resolve coerces to exactly the behavior this
    // replaced, silently and everywhere at once. tests/tst_MotionEasing.qml is
    // what stops that from being invisible.
    readonly property int easingStandard: Easing.OutCubic
    readonly property int easingExit: Easing.InCubic
    // One turn of the rescan wheel. Slow enough to read as deliberate work
    // rather than a stutter, quick enough that it is plainly moving.
    readonly property int spinnerRotationMs: 1100

    readonly property real opacityDisabled: 0.45
    readonly property real opacityInactive: 0.6
    readonly property real opacityPreviewMuted: 0.72
    readonly property real opacityPreviewInactive: 0.48
    readonly property real opacityPreviewBarMuted: 0.34
    readonly property real opacityPreviewBarActive: 0.82
    readonly property real opacityPreviewSubtle: 0.16
}
