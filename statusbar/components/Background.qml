import QtQuick
import ".."

Rectangle {
    id: root

    readonly property var theme: BarTheme {}
    required property var palette
    default property alias content: contentRow.data
    property color backgroundColor: palette.base
    property int padding: 0
    property int contentSpacing: 0

    implicitWidth: contentRow.implicitWidth + padding * 2
    implicitHeight: theme.height
    radius: theme.radius
    color: backgroundColor

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: root.contentSpacing
    }
}
