import ".."
import "../../theme"
import "../components"
import QtQuick

Item {
    id: root

    readonly property var
    icons: BarIcons {
    }

    readonly property var
    theme: BarTheme {
    }

    readonly property var
    appTheme: AppTheme {
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
    implicitHeight: theme.height
    width: implicitWidth
    height: implicitHeight

    BarText {
        id: content

        anchors.centerIn: parent
        text: root.iconText()
        color: root.palette.yellow
    }

    Rectangle {
        width: root.appTheme.notificationBadgeSize
        height: root.appTheme.notificationBadgeSize
        radius: root.appTheme.notificationBadgeRadius
        color: root.palette.red
        visible: root.services.hasNotifications
        anchors.top: parent.top
        anchors.topMargin: root.appTheme.notificationBadgeTopMargin
        anchors.right: parent.right
        anchors.rightMargin: root.appTheme.notificationBadgeRightMargin
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
