pragma Singleton
import QtQuick
import "../../theme"

// The bar's own dimensions. Its height and icon size are shared, since
// the tray reads them too, so they stay in the theme.
QtObject {
    readonly property int notificationBadgeSize: 6
    // The workspace pill. Twenty rather than a step of the shared scale: it is
    // sized against the number it holds, which stays at textSm, not against
    // anything else in the bar.
    readonly property int workspaceSlotSize: 20
    readonly property int windowTitleWidth: 420
}
