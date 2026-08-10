pragma Singleton
import QtQuick
import "../../theme"

// The system tray menu's own dimensions.
QtObject {
    readonly property int menuWidth: 260
    readonly property int menuMinHeight: Sizing.size32
    readonly property int menuItemHeight: Sizing.size28
    readonly property int menuIconSize: Sizing.size16
    readonly property int menuCheckSize: Sizing.size14
    readonly property int menuTextMinWidth: 120
    readonly property int menuTextRightReserve: 56
}
