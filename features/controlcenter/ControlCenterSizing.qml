pragma Singleton
import QtQuick
import "../../theme"

// The control centre's own dimensions.
//
// They carried a statusBar prefix from when this was a menu inside the bar,
// which stopped being true a while ago and stopped being its name recently.
QtObject {
    readonly property int panelMaxHeight: 624
    readonly property int panelWidth: 420
    readonly property int userCardHeight: 88
    readonly property int avatarSize: 64
    readonly property int userTextReserve: 76
    readonly property int quickControlHeight: 54
    readonly property int quickControlIconWidth: 22
    readonly property int quickControlSliderHeight: Sizing.size32
    readonly property int controlIconSize: 38
    readonly property int emptyStateHeight: 58
    readonly property int deviceRowHeight: 48
    readonly property int infoCardHeight: 64
    readonly property int actionHeight: 28
    readonly property int wifiPasswordModalMaxWidth: 420
    readonly property int wifiPasswordCloseButtonSize: Sizing.size30
    readonly property int wifiPasswordVisibilityButtonWidth: 38
    readonly property int wifiPasswordActionHeight: 38
    readonly property int sliderTrackHeight: 5
    readonly property int quickControlTrackHeight: 8
    readonly property int sliderHandleSize: Sizing.size14
}
