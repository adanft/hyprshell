import QtQuick

QtObject {
    id: colors

    readonly property var availableThemes: StockThemes.availableThemes
    readonly property var themeData: StockThemes.themeData
    readonly property string currentTheme: StockThemes.currentTheme

    readonly property color transparent: themeData.transparent
    readonly property color mask: themeData.mask
    readonly property color scrim: themeData.scrim

    readonly property color background: themeData.background
    readonly property color panel: themeData.panel
    readonly property color surface: themeData.surface
    readonly property color surfaceTransparent: themeData.surfaceTransparent
    readonly property color surfaceHover: themeData.surfaceHover
    readonly property color surfaceActive: themeData.surfaceActive
    readonly property color surfaceInverse: themeData.surfaceInverse
    readonly property color border: themeData.border
    readonly property color borderStrong: themeData.borderStrong

    readonly property color text: themeData.text
    readonly property color textMuted: themeData.textMuted
    readonly property color textSubtle: themeData.textSubtle
    readonly property color textInverse: themeData.textInverse

    readonly property color primary: themeData.primary
    readonly property color primaryText: themeData.primaryText
    readonly property color secondary: themeData.secondary
    readonly property color focus: themeData.focus
    readonly property color selection: themeData.selection
    readonly property color selectionText: themeData.selectionText

    readonly property color info: themeData.info
    readonly property color link: themeData.link
    readonly property color success: themeData.success
    readonly property color warning: themeData.warning
    readonly property color danger: themeData.danger
    readonly property color critical: themeData.critical

    readonly property color notification: themeData.notification
    readonly property color notificationBadge: themeData.notificationBadge
    readonly property color bluetooth: themeData.bluetooth
    readonly property color network: themeData.network
    readonly property color wifiConnected: themeData.wifiConnected
    readonly property color wifiDisconnected: themeData.wifiDisconnected
    readonly property color backlight: themeData.backlight
    readonly property color workspaceActive: themeData.workspaceActive
    readonly property color workspaceUrgent: themeData.workspaceUrgent
    readonly property color workspaceRemote: themeData.workspaceRemote
    readonly property color workspaceHover: themeData.workspaceHover
    readonly property color workspaceOccupied: themeData.workspaceOccupied
    readonly property color workspaceEmpty: themeData.workspaceEmpty
    readonly property color powerPerformance: themeData.powerPerformance
    readonly property color powerSaver: themeData.powerSaver
    readonly property color powerBalanced: themeData.powerBalanced
    readonly property color powerLock: themeData.powerLock
    readonly property color audioOutput: themeData.audioOutput
    readonly property color audioInput: themeData.audioInput
    readonly property color wallpaperSelected: themeData.wallpaperSelected

    function setTheme(name) {
        return StockThemes.setTheme(name)
    }
}
