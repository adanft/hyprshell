import QtQuick
import QtTest
import "../theme"

// The motion curves, checked for the one failure that would otherwise be
// invisible.
//
// Easing.Linear is 0. Every easing token is an int, so a token that fails to
// resolve — renamed, moved out of the singleton, typed as something QML cannot
// coerce — does not error: it becomes 0, which is Linear, which is exactly the
// motion these tokens were added to replace. The shell would go back to sliding
// notifications like an elevator, everywhere at once, and nothing would say so.
//
// So this asserts the values and not merely that the properties exist. Reading
// them is what a missing token survives; comparing them is what it does not.
TestCase {
    id: testCase

    name: "MotionEasing"

    // Both halves live here, because separating them put the check that cannot
    // fail alone under the name that promised the check that can.
    //
    // A token set to Linear is caught by the `verify`. A token that is REMOVED is
    // not: an absent property reads as `undefined`, and `undefined !== 0` is
    // true, so the verify passes on exactly the case its own name describes.
    // Measured, not assumed — renaming `easingStandard` in the singleton leaves
    // the verify green and fails only the compare. So the compare is the
    // load-bearing line, and it sits beside the verify rather than in another
    // function someone could delete while this one still reads like a guard.
    function test_tokens_are_not_the_silent_zero() {
        compare(Easing.Linear, 0, "the premise: an unresolved int token lands on Linear")

        verify(Motion.easingStandard !== Easing.Linear,
               "easingStandard is Linear, which is also what an unresolved token becomes")
        compare(Motion.easingStandard, Easing.OutCubic,
                "easingStandard is missing or is not the curve that decelerates into place")

        verify(Motion.easingExit !== Easing.Linear,
               "easingExit is Linear, which is also what an unresolved token becomes")
        compare(Motion.easingExit, Easing.InCubic,
                "easingExit is missing or is not the curve that gathers speed on the way out")
    }

    // The durations the curves are spent over. Here because a curve is only half
    // of how a movement reads, and a token silently at 0 would end the animation
    // before it began — the same class of nothing, one property over.
    function test_durations_are_positive() {
        verify(Motion.durationShort > 0, "durationShort")
        verify(Motion.durationNormal > 0, "durationNormal")
        verify(Motion.durationEntrance > 0, "durationEntrance")
    }
}
