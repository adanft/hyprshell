import "../theme"
import QtQuick

QtObject {
    readonly property var
    appTheme: AppTheme {
    }

    readonly property int outerHeight: appTheme.sizing.statusBarOuterHeight
    readonly property int height: appTheme.sizing.statusBarHeight
    readonly property int edgeMargin: appTheme.spacing.space6
    readonly property int iconSize: appTheme.sizing.statusBarIconSize
    readonly property int workspaceSlotSize: appTheme.sizing.statusBarWorkspaceSlotSize
    readonly property int gap: appTheme.spacing.space6
    readonly property int trayIconGap: appTheme.spacing.space12
    readonly property int radius: appTheme.shape.radiusFull
    readonly property int containerPadding: appTheme.spacing.space12
    readonly property int compactContainerPadding: appTheme.spacing.space12
    readonly property int workspaceContainerPadding: appTheme.spacing.space16
    readonly property int windowTitleWidth: appTheme.sizing.statusBarWindowTitleWidth
    readonly property int trayMenuWidth: appTheme.sizing.statusBarTrayMenuWidth
    readonly property int trayMenuMinHeight: appTheme.sizing.statusBarTrayMenuMinHeight
    readonly property int trayMenuPadding: appTheme.spacing.space8
    readonly property int trayMenuSpacing: appTheme.spacing.space2
    readonly property int trayMenuItemHeight: appTheme.sizing.statusBarTrayMenuItemHeight
    readonly property int trayMenuSeparatorHeight: appTheme.shape.borderThin
    readonly property int trayMenuRadius: appTheme.shape.radius12
    readonly property int trayMenuItemRadius: appTheme.shape.radius8
    readonly property int trayMenuBorderWidth: appTheme.shape.borderThin
    readonly property int trayMenuIconSize: appTheme.sizing.statusBarTrayMenuIconSize
    readonly property int trayMenuCheckSize: appTheme.sizing.statusBarTrayMenuCheckSize
    readonly property int trayMenuCheckRadius: appTheme.shape.radius3
    readonly property int trayMenuCheckFontSize: appTheme.typography.sizeXs
    readonly property int trayMenuTextMinWidth: appTheme.sizing.statusBarTrayMenuTextMinWidth
    readonly property int trayMenuTextRightReserve: appTheme.sizing.statusBarTrayMenuTextRightReserve
    readonly property int trayMenuClampMargin: appTheme.spacing.space8
    readonly property int trayMenuAnchorDefaultY: outerHeight
    readonly property string fontFamily: appTheme.typography.defaultFontFamily
    readonly property string textFontFamily: appTheme.typography.textFontFamily
    readonly property string iconFontFamily: appTheme.typography.iconFontFamily
    readonly property int fontSize: appTheme.typography.sizeLg
    readonly property int iconFontSize: appTheme.typography.sizeXl
}
