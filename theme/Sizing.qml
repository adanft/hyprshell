pragma Singleton
import QtQuick

QtObject {
    readonly property int size14: 14
    readonly property int size16: 16
    readonly property int size24: 24
    readonly property int size26: 26
    readonly property int size28: 28
    readonly property int size30: 30
    readonly property int size32: 32
    readonly property int size34: 34
    // Read by the launcher, both selectors, their filter chips and the wifi
    // password dialog: it is the shell's search field, not the launcher's.
// One square tile, drawn by the launcher's app cards and by the screenshot
    // tool's mode actions. Shared because they are deliberately the same tile,
    // which is what the screenshot tokens used to say by aliasing the launcher's.
    readonly property int actionTileWidth: 104
    readonly property int actionTileHeight: 104
    readonly property int actionTileIconSlotSize: 56

    readonly property int searchFieldHeight: 42
    readonly property int searchFieldIconSlotWidth: size24
    readonly property int themeSelectorPaletteDotSize: size28
    readonly property int themeSelectorGridColumns: 3
    readonly property int themeSelectorMaxWidth: 504
    readonly property int themeSelectorMaxHeight: 226
    readonly property int themeSelectorCellWidth: 160
    readonly property int themeVariantFilterWidth: 42

    readonly property int powerMenuActionSize: 136

    readonly property int wallpaperSelectorMaxWidth: 688
    readonly property int wallpaperSelectorMaxHeight: 444
    readonly property int wallpaperCardWidth: 160
    readonly property int wallpaperCardHeight: 90
    readonly property real wallpaperCardPreviewScale: 1.5
    readonly property int wallpaperCardLabelHeight: 20
    readonly property int wallpaperGridColumns: 4
    readonly property int wallpaperExtensionFilterWidth: 42

    readonly property int screenshotToolTimerOptionWidth: 40
    readonly property int screenshotToolTimerOptionHeight: 40
    readonly property int screenshotToolCursorSwitchWidth: 40
    readonly property int screenshotToolCursorSwitchHeight: 22
    readonly property int screenshotToolCursorSwitchKnobSize: 16

    readonly property int notificationBadgeSize: 6
    readonly property int notificationPopupWidth: 380
    readonly property int notificationCenterCardWidth: 380
    readonly property int notificationCenterFallbackScreenHeight: 560
    readonly property real notificationCenterHeightRatio: 0.75
    readonly property int notificationCenterHeaderHeight: size30
    readonly property int notificationCenterSpacerHeight: 1
    readonly property int notificationCenterClearButtonHeight: size26
    readonly property int notificationCenterClearButtonWidth: 72
    readonly property int notificationCardCollapsedBodyLines: 2
    readonly property int notificationCardUrgencyBarWidth: 3
    readonly property int notificationCardIconSlotSize: 36
    readonly property int notificationCardIconSize: 36
    readonly property int notificationCardIconSaveSize: 72
    readonly property int notificationCardCloseButtonSize: size24
    readonly property int notificationCardActionButtonHeight: size24
    readonly property int notificationCardActionButtonMinWidth: 68
    readonly property int notificationPopupEstimatedHeight: 96

    readonly property int statusBarOuterHeight: 42
    // Where a surface that hangs off the bar starts. The control centre and the
    // notification centre both take their top edge from here rather than each
    // deriving its own: they used to arrive at the same 42 by different routes,
    // one reading this height and the other adding a spacing token to the
    // bottom of whichever module was clicked, so they only agreed by accident.
    // The 3 is deliberately off the even spacing scale — it is a hairline
    // between two surfaces, not a unit of layout rhythm.
    readonly property int statusBarSurfaceTopOffset: statusBarOuterHeight + 3
    readonly property int statusBarHeight: size30
    readonly property int statusBarIconSize: size24
    readonly property int statusBarWorkspaceSlotSize: size24
    readonly property int statusBarWindowTitleWidth: 420
    readonly property int statusBarControlCenterWidth: 420
    readonly property int statusBarNetworkUserCardHeight: 88
    readonly property int statusBarNetworkAvatarSize: 64
    readonly property int statusBarNetworkUserTextReserve: 76
    readonly property int statusBarNetworkQuickControlHeight: 54
    readonly property int statusBarNetworkQuickControlIconWidth: 22
    readonly property int statusBarNetworkQuickControlSliderHeight: size32
    readonly property int statusBarNetworkControlIconSize: 38
    readonly property int statusBarControlEmptyStateHeight: 58
    readonly property int statusBarNetworkDeviceRowHeight: 48
    readonly property int statusBarNetworkInfoCardHeight: 64
    readonly property int statusBarControlActionHeight: 28
    readonly property int statusBarWifiPasswordModalMaxWidth: 420
    readonly property int statusBarWifiPasswordCloseButtonSize: size30
    readonly property int statusBarWifiPasswordVisibilityButtonWidth: 38
    readonly property int statusBarWifiPasswordActionHeight: 38
    readonly property int statusBarSliderTrackHeight: 5
    readonly property int statusBarQuickControlTrackHeight: 8
    readonly property int statusBarSliderHandleSize: size14
    readonly property int statusBarTrayMenuWidth: 260
    readonly property int statusBarTrayMenuMinHeight: size32
    readonly property int statusBarTrayMenuItemHeight: size28
    readonly property int statusBarTrayMenuIconSize: size16
    readonly property int statusBarTrayMenuCheckSize: size14
    readonly property int statusBarTrayMenuTextMinWidth: 120
    readonly property int statusBarTrayMenuTextRightReserve: 56
}
