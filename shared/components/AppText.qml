import "../../theme"
import QtQuick

Text {
    readonly property var theme: AppTheme

    // Qt defaults an uncolored Text to black, which is unreadable on every
    // surface this shell paints. Body text is on_surface unless overridden.
    color: Colors.on_surface
    font.family: theme.typography.textFontFamily
    font.pixelSize: theme.typography.textBase
    font.styleName: theme.typography.styleSemibold
    verticalAlignment: Text.AlignVCenter
}
