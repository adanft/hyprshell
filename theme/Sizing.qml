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
    readonly property int notificationCardIconSaveSize: 72
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
}
