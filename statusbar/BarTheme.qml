import "../theme"
import QtQuick

QtObject {
    readonly property var
    appTheme: AppTheme {
    }

    readonly property int outerHeight: 42
    readonly property int height: appTheme.size30
    readonly property int edgeMargin: appTheme.space6
    readonly property int iconSize: appTheme.size24
    readonly property int workspaceSlotSize: appTheme.size24
    readonly property int gap: appTheme.space6
    readonly property int trayIconGap: appTheme.space12
    readonly property int radius: appTheme.radiusFull
    readonly property int containerPadding: appTheme.space12
    readonly property int compactContainerPadding: appTheme.space12
    readonly property int workspaceContainerPadding: appTheme.space16
    readonly property int windowTitleWidth: 420
    readonly property int trayMenuWidth: 260
    readonly property int trayMenuMinHeight: appTheme.size32
    readonly property int trayMenuPadding: appTheme.space8
    readonly property int trayMenuSpacing: appTheme.space2
    readonly property int trayMenuItemHeight: appTheme.size28
    readonly property int trayMenuSeparatorHeight: appTheme.borderThin
    readonly property int trayMenuRadius: appTheme.radius12
    readonly property int trayMenuItemRadius: appTheme.radius8
    readonly property int trayMenuBorderWidth: appTheme.borderThin
    readonly property int trayMenuIconSize: appTheme.size16
    readonly property int trayMenuCheckSize: appTheme.size14
    readonly property int trayMenuCheckRadius: appTheme.radius3
    readonly property int trayMenuCheckFontSize: appTheme.fontSizeXs
    readonly property int trayMenuTextMinWidth: 120
    readonly property int trayMenuTextRightReserve: 56
    readonly property int trayMenuClampMargin: appTheme.space8
    readonly property int trayMenuAnchorDefaultY: outerHeight
    readonly property string fontFamily: appTheme.fontFamily
    readonly property string textFontFamily: appTheme.textFontFamily
    readonly property string iconFontFamily: appTheme.iconFontFamily
    readonly property int fontSize: appTheme.fontSize
    readonly property int iconFontSize: appTheme.iconFontSize
}
