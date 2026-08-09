import QtQuick
import "../../theme"

Rectangle {
    id: root

    required property var theme
    property string title: ""
    property string description: ""

    height: theme.sizing.statusBarControlEmptyStateHeight
    radius: theme.shape.radius12
    color: Colors.surface
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
            color: Colors.on_surface
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeMd
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.description
            color: Colors.on_surface_variant
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }
    }
}
