pragma Singleton
import QtQuick
import "../../theme"

// The notification centre, its cards and its popups.
QtObject {
    readonly property int popupWidth: 380
    readonly property int centerCardWidth: 380
    readonly property int centerFallbackScreenHeight: 560
    readonly property real centerHeightRatio: 0.75
    readonly property int centerHeaderHeight: Sizing.size30
    readonly property int centerSpacerHeight: 1
    readonly property int centerClearButtonHeight: Sizing.size26
    readonly property int centerClearButtonWidth: 72
    readonly property int cardCollapsedBodyLines: 2
    readonly property int cardUrgencyBarWidth: 3
    readonly property int cardIconSlotSize: 36
    readonly property int cardIconSize: 36
    readonly property int cardCloseButtonSize: Sizing.size24
    readonly property int cardActionButtonHeight: Sizing.size24
    readonly property int cardActionButtonMinWidth: 68
}
