import QtQuick

Rectangle {
    id: root

    required property var colors
    required property var theme
    property string title: ""
    property string description: ""

    height: theme.sizing.statusBarControlEmptyStateHeight
    radius: theme.shape.radius12
    color: colors.surface
    border.width: 0

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: root.theme.spacing.space12
        spacing: root.theme.spacing.space2

        Text {
            width: parent.width
            text: root.title
            color: root.colors.text
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeMd
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.description
            color: root.colors.textSubtle
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }
    }
}
