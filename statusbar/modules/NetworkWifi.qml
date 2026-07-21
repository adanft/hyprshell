import "../components"
import QtQuick
import Quickshell
import "../../theme"

Item {
    id: root

    readonly property var
    icons: Icons {
    }

    readonly property var
    theme: AppTheme {
    }

    required property var colors
    required property var services
    signal openRequested(var anchorItem)
    readonly property bool connected: services.wifiUp && services.wifiSignal > 0
    readonly property color moduleColor: connected ? colors.primary : colors.text

    implicitWidth: content.implicitWidth
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        BarText {
            text: root.connected ? root.icons.wifiConnected : root.icons.wifiDisconnected
            color: root.moduleColor
        }

        BarText {
            visible: root.connected
            text: `${root.services.wifiSignal}%`
            color: root.moduleColor
        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openRequested(root)
    }

}
