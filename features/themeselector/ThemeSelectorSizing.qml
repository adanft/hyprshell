pragma Singleton
import QtQuick
import "../../theme"

// The theme selector's own dimensions.
QtObject {
    readonly property int paletteDotSize: Sizing.size28
    readonly property int gridColumns: 3
    readonly property int maxWidth: 504
    readonly property int maxHeight: 226
    readonly property int cellWidth: 160
    readonly property int variantFilterWidth: 42
}
