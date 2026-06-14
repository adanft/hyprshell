import "../../theme"
import QtQuick

Text {
    readonly property var
    theme: AppTheme {
    }

    font.family: theme.textFontFamily
    font.pixelSize: theme.fontSize
    font.styleName: theme.fontStyleSemibold
    verticalAlignment: Text.AlignVCenter
}
