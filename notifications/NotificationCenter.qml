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
    readonly property real heightRatio: 0.75

    implicitWidth: cardWidth + contentPadding * 2
    implicitHeight: Math.round((barWindow.screen ? barWindow.screen.height : theme.sizing.notificationCenterFallbackScreenHeight) * heightRatio)
    visible: false
    grabFocus: true
    color: popup.colors.transparent
    anchor.window: barWindow
    anchor.rect.x: Math.max(theme.spacing.notificationCenterScreenMargin, barWindow.width - width - theme.spacing.notificationCenterScreenMargin)
    anchor.rect.y: theme.sizing.notificationCenterTopOffset
    onVisibleChanged: popup.services.setNotificationCenterOpen(visible)

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
                    text: popup.services.notificationCount
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
                    visible: popup.services.hasNotifications

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
                        onClicked: popup.services.dismissNotifications()
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
                    color: popup.services.notificationDnd ? popup.colors.primary : popup.colors.surfaceHover
                    border.width: 0

                    Rectangle {
                        width: popup.theme.sizing.notificationCenterDndKnobSize
                        height: popup.theme.sizing.notificationCenterDndKnobSize
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: popup.services.notificationDnd ? parent.width - width - popup.theme.spacing.notificationCenterDndKnobMargin : popup.theme.spacing.notificationCenterDndKnobMargin
                        color: popup.services.notificationDnd ? popup.colors.background : popup.colors.textSubtle

                        Behavior on x {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.services.toggleNotificationDnd()
                    }

                }

            }

            Item {
                width: parent.width
                height: parent.height - headerRow.height - dndRow.height - parent.spacing * 2

                Column {
                    anchors.centerIn: parent
                    spacing: popup.theme.spacing.notificationCenterSectionSpacing
                    visible: !popup.services.hasNotifications

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

                Flickable {
                    anchors.fill: parent
                    visible: popup.services.hasNotifications
                    contentWidth: width
                    contentHeight: notificationList.implicitHeight
                    clip: true

                    Column {
                        id: notificationList

                        width: parent.width
                        spacing: popup.theme.spacing.notificationCenterListSpacing

                        Repeater {
                            model: popup.visible && popup.services.hasNotifications ? popup.services.notifications : []

                            NotificationCard {
                                required property var modelData

                                width: notificationList.width
                                colors: popup.colors
                                notificationData: modelData
                                cornerRadius: popup.theme.shape.notificationCenterCardRadius
                                useRenderedHeightForLayout: true
                                timeText: popup.services.notificationTimeText(modelData)
                                onCloseRequested: popup.services.dismissNotificationHistoryEntry(modelData)
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

    }

}
