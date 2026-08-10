import QtQuick
import "../../../theme"

Rectangle {
    id: root

    readonly property var theme: AppTheme

    default property alias content: contentRow.data
    property color backgroundColor: Colors.shadow
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
