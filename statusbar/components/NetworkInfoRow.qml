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
        width: root.theme.sizing.statusBarNetworkInfoLabelWidth
        text: root.label
        color: root.colors.textMuted
        font.family: root.theme.typography.textFontFamily
        font.pixelSize: root.theme.typography.sizeSm
        font.styleName: root.theme.typography.styleRegular
    }

    Text {
        width: parent.width - root.theme.sizing.statusBarNetworkInfoLabelWidth - parent.spacing
        text: root.value
        color: root.colors.text
        font.family: root.theme.typography.textFontFamily
        font.pixelSize: root.theme.typography.sizeSm
        font.styleName: root.theme.typography.styleRegular
        wrapMode: Text.WrapAnywhere
    }
}
