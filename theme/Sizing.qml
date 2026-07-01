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

    readonly property int appLauncherMaxWidth: 488
    readonly property int appLauncherMaxHeight: 548
    readonly property int appLauncherSearchHeight: 42
    readonly property int appLauncherSearchIconSlotWidth: size24
    readonly property int appLauncherGridCellWidth: 110
    readonly property int appLauncherGridCellHeight: 110
    readonly property int appLauncherCardWidth: 104
    readonly property int appLauncherCardHeight: 104
    readonly property int appLauncherIconSlotSize: 56
    readonly property int appLauncherIconSize: 52

    readonly property int powerMenuActionSize: 136

    readonly property int wallpaperCardWidth: 220
    readonly property int wallpaperCardHeight: 150

    readonly property int screenshotToolActionWidth: appLauncherCardWidth
    readonly property int screenshotToolActionHeight: appLauncherCardHeight
    readonly property int screenshotToolActionIconSlotSize: appLauncherIconSlotSize
    readonly property int screenshotToolActionIconSize: 36
    readonly property int screenshotToolTimerInputWidth: 96
    readonly property int screenshotToolTimerInputHeight: 42
    readonly property int screenshotToolCursorSwitchWidth: size34
    readonly property int screenshotToolCursorSwitchHeight: size16
    readonly property int screenshotToolCursorSwitchKnobSize: size14

    readonly property int notificationBadgeSize: 6
    readonly property int notificationPopupWidth: 380
    readonly property int notificationCenterCardWidth: 380
    readonly property int notificationCenterFallbackScreenHeight: 560
    readonly property int notificationCenterTopOffset: 42
    readonly property int notificationCenterHeaderHeight: size30
    readonly property int notificationCenterSpacerHeight: 1
    readonly property int notificationCenterClearButtonHeight: size26
    readonly property int notificationCenterDndRowHeight: size26
    readonly property int notificationCenterDndSwitchWidth: size34
    readonly property int notificationCenterDndSwitchHeight: size16
    readonly property int notificationCenterDndKnobSize: size14
    readonly property int notificationCardIconSlotSize: size32
    readonly property int notificationCardIconSize: size24
    readonly property int notificationCardCloseButtonSize: size24
    readonly property int notificationCardActionButtonHeight: size24
    readonly property int notificationCardActionButtonMinWidth: 68
    readonly property int notificationPopupEstimatedHeight: 96

    readonly property int statusBarOuterHeight: 42
    readonly property int statusBarHeight: size30
    readonly property int statusBarIconSize: size24
    readonly property int statusBarWorkspaceSlotSize: size24
    readonly property int statusBarWindowTitleWidth: 420
    readonly property int statusBarTrayMenuWidth: 260
    readonly property int statusBarTrayMenuMinHeight: size32
    readonly property int statusBarTrayMenuItemHeight: size28
    readonly property int statusBarTrayMenuIconSize: size16
    readonly property int statusBarTrayMenuCheckSize: size14
    readonly property int statusBarTrayMenuTextMinWidth: 120
    readonly property int statusBarTrayMenuTextRightReserve: 56
}
