pragma Singleton
import QtQuick

// The app launcher's own dimensions.
//
// They live with the launcher because nothing else reads them: a name no longer
// has to carry its owner, since the file it sits in already says who that is.
QtObject {
    readonly property int maxWidth: 476
    readonly property int maxHeight: 536
    readonly property int gridCellWidth: 110
    readonly property int gridCellHeight: 110
    readonly property int iconSize: 52
}
