import "../../theme"
import QtQuick

Text {
    readonly property var theme: AppTheme {}

    font.family: theme.typography.textFontFamily
    font.pixelSize: theme.typography.sizeLg
    font.styleName: theme.typography.styleSemibold
    verticalAlignment: Text.AlignVCenter
}
