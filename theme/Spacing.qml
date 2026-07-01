import QtQuick

QtObject {
    readonly property int space2: 2
    readonly property int space4: 4
    readonly property int space6: 6
    readonly property int space8: 8
    readonly property int space12: 12
    readonly property int space16: 16
    readonly property int space18: 18
    readonly property int space24: 24
    readonly property int space52: 52
    readonly property int space80: 80
    readonly property int space96: 96
    readonly property int space128: 128

    readonly property int appLauncherScreenMargin: space128
    readonly property int appLauncherPadding: space24
    readonly property int appLauncherSectionSpacing: space18
    readonly property int appLauncherSearchHorizontalPadding: space16
    readonly property int appLauncherEmptyTextHorizontalMargin: space80
    readonly property int appLauncherCardPadding: space8
    readonly property int appLauncherCardSpacing: space6

    readonly property int powerMenuActionSpacing: space16

    readonly property int wallpaperSelectorScreenMargin: space96
    readonly property int wallpaperSelectorGridMargin: space24
    readonly property int wallpaperSelectorEmptyTextHorizontalMargin: space80

    readonly property int screenshotToolScreenMargin: space96
    readonly property int screenshotToolPadding: space24
    readonly property int screenshotToolSectionSpacing: space16
    readonly property int screenshotToolActionRowSpacing: space6
    readonly property int screenshotToolActionPadding: space8
    readonly property int screenshotToolActionSpacing: appLauncherCardSpacing
    readonly property int screenshotToolTimerInputHorizontalPadding: space16
    readonly property int screenshotToolCursorSwitchKnobMargin: space2

    readonly property int notificationBadgeTopMargin: space6
    readonly property int notificationBadgeRightMargin: space8
    readonly property int notificationPopupTopMargin: space52
    readonly property int notificationPopupRightMargin: space12
    readonly property int notificationPopupBottomMargin: space12
    readonly property int notificationPopupSpacing: space6
    readonly property int notificationPopupEnterOffsetMargin: space16
    readonly property int notificationCenterPadding: space16
    readonly property int notificationCenterScreenMargin: space6
    readonly property int notificationCenterSectionSpacing: space12
    readonly property int notificationCenterHeaderSpacing: space8
    readonly property int notificationCenterClearButtonSpacing: space4
    readonly property int notificationCenterDndKnobMargin: space2
    readonly property int notificationCenterListSpacing: space12
    readonly property int notificationCardSpacing: space8
    readonly property int notificationCardPadding: space8
    readonly property int notificationCardActionButtonHorizontalPadding: space16
}
