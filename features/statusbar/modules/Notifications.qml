import "../../../theme"
import "../components"
import QtQuick
import "../../../shared/components"

Item {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var services
    // Do Not Disturb silences notifications the way muting silences audio, so
    // it dims for the same reason. Nothing pending is the empty state, the same
    // way a workspace with no windows is empty.
    readonly property bool moduleDisabled: services.notification.notificationDnd
                                           || !services.notification.hasNotifications
    readonly property color moduleColor: moduleDisabled ? Colors.outline : Colors.on_surface

    signal openRequested

    function iconText() {
        if (services.notification.notificationDnd)
            return icons.notification.doNotDisturb

        return icons.notification.bell
    }

    implicitWidth: content.implicitWidth
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight

    AppText {
        id: content

        anchors.centerIn: parent
        text: root.iconText()
        color: root.moduleColor
    }

    Rectangle {
        width: root.theme.sizing.notificationBadgeSize
        height: root.theme.sizing.notificationBadgeSize
        radius: root.theme.shape.notificationBadgeRadius
        color: Colors.error
        visible: root.services.notification.hasNotifications
        anchors.top: parent.top
        anchors.topMargin: root.theme.spacing.space6
        anchors.right: parent.right
        anchors.rightMargin: 0
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                services.notification.toggleNotificationDnd()
            else
                root.openRequested()
        }
    }
}
