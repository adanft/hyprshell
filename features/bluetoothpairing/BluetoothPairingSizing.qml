pragma Singleton
import QtQuick

// The pairing dialog's own dimensions.
//
// Only one so far, and it exists because the alternative was an arithmetic
// expression over spacing tokens — which is how this dialog spent an afternoon
// invisible: it added a `space32` that does not exist, got NaN for a height,
// and drew nothing at all without QML saying a word.
QtObject {
    // Matches the control center's own action buttons. A dialog that answers a
    // question should not invent a button size the rest of the shell has
    // already settled on.
    readonly property int actionHeight: 38
}
