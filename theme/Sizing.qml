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

    readonly property int appLauncherMaxWidth: 476
    readonly property int appLauncherMaxHeight: 536
    readonly property int appLauncherSearchHeight: 42
    readonly property int appLauncherSearchIconSlotWidth: size24
    readonly property int appLauncherGridCellWidth: 110
    readonly property int appLauncherGridCellHeight: 110
    readonly property int appLauncherCardWidth: 104
    readonly property int appLauncherCardHeight: 104
    readonly property int appLauncherIconSlotSize: 56
    readonly property int appLauncherIconSize: 52
    readonly property int themeSelectorPaletteDotSize: size28
    readonly property int themeSelectorGridColumns: 3
    readonly property int themeSelectorMaxWidth: 504
    readonly property int themeSelectorMaxHeight: 226
    readonly property int themeSelectorCellWidth: 160
    readonly property int themeVariantFilterWidth: 42
    readonly property int themePreviewReferenceWidth: 400
    readonly property int themePreviewReferenceHeight: 208
    readonly property int themePreviewHeaderMinHeight: size24
    readonly property int themePreviewDotMinSize: 9
    readonly property int themePreviewDotSize: 12
    readonly property int themePreviewRailMinWidth: 30
    readonly property int themePreviewNavigationItemMinSize: 22
    readonly property int themePreviewContentMinWidth: 68
    readonly property int themePreviewBarMinHeight: 5
    readonly property int themePreviewBarHeight: 7

    readonly property int powerMenuActionSize: 136

    readonly property int wallpaperSelectorMaxWidth: 688
    readonly property int wallpaperSelectorMaxHeight: 444
    readonly property int wallpaperCardWidth: 160
    readonly property int wallpaperCardHeight: 90
    readonly property real wallpaperCardPreviewScale: 1.5
    readonly property int wallpaperCardLabelHeight: 20
    readonly property int wallpaperGridColumns: 4
    readonly property int wallpaperExtensionFilterWidth: 42

    readonly property int screenshotToolActionWidth: appLauncherCardWidth
    readonly property int screenshotToolActionHeight: appLauncherCardHeight
    readonly property int screenshotToolActionIconSlotSize: appLauncherIconSlotSize
    readonly property int screenshotToolActionIconSize: 36
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
    readonly property int notificationCenterHeaderIconSize: size16
    readonly property int notificationCardCollapsedBodyLines: 2
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
    readonly property int statusBarNetworkMenuWidth: 420
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
