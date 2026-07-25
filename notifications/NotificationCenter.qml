import "../shared/components"
import "../theme"
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

PopupWindow {
    id: popup

    readonly property var
    icons: Icons {
    }

    readonly property var
    theme: AppTheme {
    }

    required property var colors
    required property var services
    required property var barWindow
    readonly property int contentPadding: theme.spacing.notificationCenterPadding
    readonly property int cardWidth: theme.sizing.notificationCenterCardWidth
    readonly property real heightRatio: theme.sizing.notificationCenterHeightRatio
    property var expandedNotificationIds: ({})

    function notificationExpansionKey(notification) {
        return notification && notification.id !== undefined ? `notification:${notification.id}` : "";
    }

    function isNotificationExpanded(notification) {
        const key = notificationExpansionKey(notification);
        return key.length > 0 && expandedNotificationIds[key] === true;
    }

    function setNotificationExpanded(notification, expanded) {
        const key = notificationExpansionKey(notification);
        if (key.length === 0)
            return ;

        const nextExpandedIds = Object.assign({}, expandedNotificationIds);
        if (expanded)
            nextExpandedIds[key] = true;
        else
            delete nextExpandedIds[key];
        expandedNotificationIds = nextExpandedIds;
    }

    function pruneExpandedNotifications() {
        const activeIds = {};
        const notifications = services.notification.notifications || [];
        for (const notification of notifications) {
            const key = notificationExpansionKey(notification);
            if (key.length > 0 && expandedNotificationIds[key] === true)
                activeIds[key] = true;
        }
        expandedNotificationIds = activeIds;
    }

    implicitWidth: cardWidth + contentPadding * 2
    implicitHeight: Math.round((barWindow.screen ? barWindow.screen.height : theme.sizing.notificationCenterFallbackScreenHeight) * heightRatio)
    visible: false
    grabFocus: true
    color: popup.colors.transparent
    anchor.window: barWindow
    anchor.rect.x: Math.max(theme.spacing.notificationCenterScreenMargin, barWindow.width - width - theme.spacing.notificationCenterScreenMargin)
    anchor.rect.y: theme.sizing.notificationCenterTopOffset
    onVisibleChanged: popup.services.notification.setNotificationCenterOpen(visible)

    Rectangle {
        anchors.fill: parent
        radius: popup.theme.shape.notificationCenterRadius
        color: popup.colors.background
        border.color: popup.colors.border
        border.width: popup.theme.shape.notificationCenterBorderWidth

        Column {
            anchors.fill: parent
            anchors.margins: popup.contentPadding
            spacing: popup.theme.spacing.notificationCenterSectionSpacing

            Row {
                id: headerRow

                width: parent.width
                height: popup.theme.sizing.notificationCenterHeaderHeight
                spacing: popup.theme.spacing.notificationCenterHeaderSpacing

                AppText {
                    id: headerTitle

                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: popup.colors.text
                    font.family: popup.theme.typography.textFontFamily
                }

                AppText {
                    id: headerIcon

                    anchors.verticalCenter: parent.verticalCenter
                    text: popup.icons.notificationsEmpty
                    color: popup.colors.text
                    font.family: popup.theme.typography.iconFontFamily
                    font.pixelSize: popup.theme.typography.sizeLg
                }

                AppText {
                    id: headerCount

                    anchors.verticalCenter: parent.verticalCenter
                    text: popup.services.notification.notificationCount
                    color: popup.colors.text
                    font.family: popup.theme.typography.textFontFamily
                    font.pixelSize: popup.theme.typography.sizeMd
                }

                Item {
                    width: Math.max(0, parent.width - headerTitle.implicitWidth - headerIcon.implicitWidth - headerCount.implicitWidth - clearButton.width - parent.spacing * 4)
                    height: popup.theme.sizing.notificationCenterSpacerHeight
                }

                Item {
                    id: clearButton

                    anchors.verticalCenter: parent.verticalCenter
                    width: clearContent.implicitWidth
                    height: popup.theme.sizing.notificationCenterClearButtonHeight
                    visible: popup.services.notification.hasNotifications

                    Row {
                        id: clearContent

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: popup.theme.spacing.notificationCenterClearButtonSpacing

                        AppText {
                            text: "Clear"
                            color: clearMouse.containsMouse ? popup.colors.link : popup.colors.textMuted
                            font.family: popup.theme.typography.textFontFamily
                            font.pixelSize: popup.theme.typography.sizeMd
                            font.styleName: popup.theme.typography.styleMedium
                        }

                        AppText {
                            text: popup.icons.notificationsClear
                            color: clearMouse.containsMouse ? popup.colors.link : popup.colors.textMuted
                            font.family: popup.theme.typography.iconFontFamily
                            font.pixelSize: popup.theme.typography.sizeMd
                        }

                    }

                    MouseArea {
                        id: clearMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.services.notification.dismissNotifications()
                    }

                }

            }

            Row {
                id: dndRow

                width: parent.width
                height: popup.theme.sizing.notificationCenterDndRowHeight

                AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - dndSwitch.width
                    text: "Do Not Disturb"
                    color: popup.colors.text
                    font.family: popup.theme.typography.textFontFamily
                    font.pixelSize: popup.theme.typography.sizeMd
                }

                Rectangle {
                    id: dndSwitch

                    anchors.verticalCenter: parent.verticalCenter
                    width: popup.theme.sizing.notificationCenterDndSwitchWidth
                    height: popup.theme.sizing.notificationCenterDndSwitchHeight
                    radius: height / 2
                    color: popup.services.notification.notificationDnd ? popup.colors.primary : popup.colors.surfaceHover
                    border.width: 0

                    Rectangle {
                        width: popup.theme.sizing.notificationCenterDndKnobSize
                        height: popup.theme.sizing.notificationCenterDndKnobSize
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: popup.services.notification.notificationDnd ? parent.width - width - popup.theme.spacing.notificationCenterDndKnobMargin : popup.theme.spacing.notificationCenterDndKnobMargin
                        color: popup.services.notification.notificationDnd ? popup.colors.background : popup.colors.textSubtle

                        Behavior on x {
                            NumberAnimation {
                                duration: popup.theme.motion.durationShort
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.services.notification.toggleNotificationDnd()
                    }

                }

            }

            Item {
                width: parent.width
                height: parent.height - headerRow.height - dndRow.height - parent.spacing * 2

                Column {
                    anchors.centerIn: parent
                    spacing: popup.theme.spacing.notificationCenterSectionSpacing
                    visible: !popup.services.notification.hasNotifications

                    AppText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: popup.icons.notificationsEmpty
                        color: popup.colors.textSubtle
                        font.family: popup.theme.typography.iconFontFamily
                        font.pixelSize: popup.theme.typography.displayIconFontSize
                    }

                    AppText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No Notifications"
                        color: popup.colors.textSubtle
                        font.family: popup.theme.typography.textFontFamily
                        font.pixelSize: popup.theme.typography.sizeLg
                    }

                }

                ListView {
                    id: notificationList

                    anchors.fill: parent
                    visible: popup.services.notification.hasNotifications
                    clip: true
                    orientation: ListView.Vertical
                    spacing: popup.theme.spacing.notificationCenterListSpacing
                    cacheBuffer: Math.max(0, height * 2)
                    reuseItems: false
                    model: popup.visible && popup.services.notification.hasNotifications ? popup.services.notification.notifications : []
                    onModelChanged: popup.pruneExpandedNotifications()

                    delegate: NotificationCard {
                        required property var modelData

                        width: notificationList.width
                        colors: popup.colors
                        notificationService: popup.services.notification
                        initialExpanded: popup.isNotificationExpanded(modelData)
                        notificationData: modelData
                        cornerRadius: popup.theme.shape.notificationCenterCardRadius
                        useRenderedHeightForLayout: true
                        timeText: popup.services.notification.notificationTimeText(modelData)
                        onExpandedChanged: popup.setNotificationExpanded(modelData, expanded)
                        onCloseRequested: popup.services.notification.dismissNotificationHistoryEntry(modelData)
                        onActionInvoked: (action) => {
                            if (action && action.invoke)
                                action.invoke();

                        }
                    }

                }

            }

        }

    }

}
