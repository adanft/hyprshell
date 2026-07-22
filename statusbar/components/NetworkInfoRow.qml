import QtQuick

Row {
    id: root

    required property string label
    required property string value
    required property var colors
    required property var theme

    width: parent ? parent.width : 0
    spacing: theme.spacing.space8
    visible: value.length > 0

    Text {
        width: 72
        text: root.label
        color: root.colors.textMuted
        font.family: root.theme.typography.textFontFamily
        font.pixelSize: root.theme.typography.sizeSm
        font.weight: Font.Normal
    }

    Text {
        width: parent.width - 72 - parent.spacing
        text: root.value
        color: root.colors.text
        font.family: root.theme.typography.textFontFamily
        font.pixelSize: root.theme.typography.sizeSm
        font.weight: Font.Normal
        wrapMode: Text.WrapAnywhere
    }
}
