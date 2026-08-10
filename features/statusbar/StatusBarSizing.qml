pragma Singleton
import QtQuick
import "../../theme"

// The bar's own dimensions. Its height and icon size are shared, since
// the tray reads them too, so they stay in the theme.
QtObject {
    readonly property int notificationBadgeSize: 6
    readonly property int workspaceSlotSize: Sizing.size24
    readonly property int windowTitleWidth: 420
}
