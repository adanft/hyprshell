import "../../theme"
import "../components"
import QtQuick

Item {
    id: root

    readonly property var
    icons: Icons {
    }

    readonly property var
    theme: AppTheme {
    }

    required property var palette
    required property var services

    signal openRequested()

    function iconText() {
        if (services.notificationDnd)
            return icons.notificationsDnd;

        return icons.notifications;
    }

    implicitWidth: content.implicitWidth
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight

    BarText {
        id: content

        anchors.centerIn: parent
        text: root.iconText()
        color: root.palette.yellow
    }

    Rectangle {
        width: root.theme.sizing.notificationBadgeSize
        height: root.theme.sizing.notificationBadgeSize
        radius: root.theme.shape.notificationBadgeRadius
        color: root.palette.red
        visible: root.services.hasNotifications
        anchors.top: parent.top
        anchors.topMargin: root.theme.spacing.notificationBadgeTopMargin
        anchors.right: parent.right
        anchors.rightMargin: root.theme.spacing.notificationBadgeRightMargin
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                services.toggleNotificationDnd();
            else
                root.openRequested();
        }
    }

}
