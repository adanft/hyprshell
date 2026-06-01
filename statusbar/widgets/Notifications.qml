import QtQuick
import Quickshell

Pill {
    id: root

    required property var services
    property bool grouped: false
    signal openRequested()

    textColor: services.notificationDnd ? palette.orange : services.hasNotifications ? palette.red : palette.yellow
    backgroundColor: grouped ? "transparent" : palette.base
    text: root.iconText()
    horizontalPadding: 10

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                services.toggleNotificationDnd()
            else
                root.openRequested()
        }
    }

    function iconText() {
        if (services.notificationDnd)
            return "󰪑"
        return services.hasNotifications ? "󰅸" : "󰂜"
    }
}
