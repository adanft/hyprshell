import QtQuick
import "../../theme"

Rectangle {
    id: root

    readonly property var
    theme: AppTheme {
    }

    required property var palette
    default property alias content: contentRow.data
    property color backgroundColor: palette.base
    property int padding: 0
    property int contentSpacing: 0

    implicitWidth: contentRow.implicitWidth + padding * 2
    implicitHeight: theme.sizing.statusBarHeight
    radius: theme.shape.radiusFull
    color: backgroundColor

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: root.contentSpacing
    }

}
