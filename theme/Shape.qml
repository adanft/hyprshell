pragma Singleton
import QtQuick

QtObject {
    readonly property int radius3: 3
    readonly property int radius8: 8
    readonly property int radius12: 12
    readonly property int radius16: 16
    readonly property int radius24: 24
    readonly property int radius36: 36
    readonly property int radiusFull: 999

    readonly property int borderThin: 1
    readonly property int borderMedium: 2
    readonly property int borderEmphasis: 6
    readonly property int focusBorderWidth: borderMedium

    readonly property int appLauncherRadius: radius16
    readonly property int appLauncherBorderWidth: borderMedium
    readonly property int appLauncherSearchRadius: radiusFull
    readonly property int appLauncherCardRadius: radius12

    readonly property int powerMenuActionRadius: radius36
    readonly property int powerMenuActionBorderWidth: borderEmphasis

    readonly property int wallpaperSelectorRadius: radius16
    readonly property int wallpaperSelectorBorderWidth: borderMedium
    readonly property int wallpaperCardRadius: radius24
    readonly property int wallpaperThumbnailRadius: radius12
    readonly property int wallpaperExtensionFilterRadius: radius12
    readonly property int wallpaperCardBorderWidth: borderMedium

    readonly property int screenshotToolRadius: radius16
    readonly property int screenshotToolActionRadius: radius12
    readonly property int screenshotToolTimerOptionRadius: radiusFull

    readonly property int notificationBadgeRadius: radius3
    readonly property int notificationCenterRadius: radius16
    readonly property int notificationCenterBorderWidth: borderThin
    readonly property int notificationCardRadius: radius16
    readonly property int notificationCardBorderWidth: borderThin
    readonly property int notificationCardCloseButtonRadius: radiusFull
    readonly property int notificationCardActionButtonRadius: radiusFull
}
