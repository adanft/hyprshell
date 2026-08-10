pragma Singleton
import QtQuick
import "../../theme"

// The wallpaper selector's own dimensions.
QtObject {
    readonly property int maxWidth: 688
    readonly property int maxHeight: 444
    readonly property int cardWidth: 160
    readonly property int cardHeight: 90
    readonly property real cardPreviewScale: 1.5
    readonly property int cardLabelHeight: 20
    readonly property int gridColumns: 4
    readonly property int extensionFilterWidth: 42
}
