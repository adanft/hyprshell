pragma Singleton
import QtQuick

// The spacing scale, and nothing else.
//
// Every gap, margin and padding in the shell is one of these steps, named for
// what it measures rather than for where it is used. Fifty semantic aliases used
// to sit on top — eight different names meaning space12, each read exactly once —
// so a call site named a concept and still told you nothing about the size, and
// the file grew a name per use rather than a step per distance.
QtObject {
    readonly property int space2: 2
    readonly property int space3: 3
    readonly property int space4: 4
    readonly property int space6: 6
    readonly property int space8: 8
    readonly property int space12: 12
    readonly property int space16: 16
    readonly property int space18: 18
    readonly property int space24: 24

    // Room around a full-screen surface rather than rhythm between elements,
    // which is why these jump rather than step.
    readonly property int space52: 52
    readonly property int space80: 80
    readonly property int space96: 96
    readonly property int space128: 128
}
