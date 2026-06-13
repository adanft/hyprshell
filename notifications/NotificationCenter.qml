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

    required property var palette
    required property var services
    required property var barWindow
    readonly property int contentPadding: theme.notificationCenterPadding
    readonly property int cardWidth: theme.notificationCenterCardWidth

    implicitWidth: cardWidth + contentPadding * 2
    implicitHeight: Math.round((barWindow.screen ? barWindow.screen.height : theme.notificationCenterFallbackScreenHeight) * theme.notificationCenterHeightRatio)
    visible: false
    grabFocus: true
    color: "transparent"
    anchor.window: barWindow
    anchor.rect.x: Math.max(theme.notificationCenterScreenMargin, barWindow.width - width - theme.notificationCenterScreenMargin)
    anchor.rect.y: theme.notificationCenterTopOffset
    onVisibleChanged: popup.services.setNotificationCenterOpen(visible)

    Rectangle {
        anchors.fill: parent
        radius: popup.theme.notificationCenterRadius
        color: popup.palette.base
        border.color: popup.palette.surface1
        border.width: popup.theme.notificationCenterBorderWidth

        Column {
            anchors.fill: parent
            anchors.margins: popup.contentPadding
            spacing: popup.theme.notificationCenterSectionSpacing

            Row {
                id: headerRow

                width: parent.width
                height: popup.theme.notificationCenterHeaderHeight
                spacing: popup.theme.notificationCenterHeaderSpacing

                AppText {
                    id: headerTitle

                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: popup.palette.text
                    font.family: popup.theme.textFontFamily
                }

                AppText {
                    id: headerIcon

                    anchors.verticalCenter: parent.verticalCenter
                    text: popup.icons.notificationsEmpty
                    color: popup.palette.mauve
                    font.family: popup.theme.iconFontFamily
                    font.pixelSize: popup.theme.notificationCenterHeaderIconFontSize
                }

                AppText {
                    id: headerCount

                    anchors.verticalCenter: parent.verticalCenter
                    text: popup.services.notificationCount
                    color: popup.palette.text
                    font.family: popup.theme.textFontFamily
                    font.pixelSize: popup.theme.notificationCenterTextFontSize
                }

                Item {
                    width: Math.max(0, parent.width - headerTitle.implicitWidth - headerIcon.implicitWidth - headerCount.implicitWidth - clearButton.width - parent.spacing * 4)
                    height: popup.theme.notificationCenterSpacerHeight
                }

                Item {
                    id: clearButton

                    anchors.verticalCenter: parent.verticalCenter
                    width: clearContent.implicitWidth
                    height: popup.theme.notificationCenterClearButtonHeight
                    visible: popup.services.hasNotifications

                    Row {
                        id: clearContent

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: popup.theme.notificationCenterClearButtonSpacing

                        AppText {
                            text: "Clear"
                            color: clearMouse.containsMouse ? popup.palette.blue : popup.palette.subtext1
                            font.family: popup.theme.textFontFamily
                            font.pixelSize: popup.theme.notificationCenterTextFontSize
                            font.weight: Font.Medium
                        }

                        AppText {
                            text: popup.icons.notificationsClear
                            color: clearMouse.containsMouse ? popup.palette.blue : popup.palette.subtext1
                            font.family: popup.theme.iconFontFamily
                            font.pixelSize: popup.theme.notificationCenterTextFontSize
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
                height: popup.theme.notificationCenterDndRowHeight

                AppText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - dndSwitch.width
                    text: "Do Not Disturb"
                    color: popup.palette.text
                    font.family: popup.theme.textFontFamily
                    font.pixelSize: popup.theme.notificationCenterTextFontSize
                }

                Rectangle {
                    id: dndSwitch

                    anchors.verticalCenter: parent.verticalCenter
                    width: popup.theme.notificationCenterDndSwitchWidth
                    height: popup.theme.notificationCenterDndSwitchHeight
                    radius: height / 2
                    color: popup.services.notificationDnd ? popup.palette.mauve : popup.palette.surface1
                    border.width: 0

                    Rectangle {
                        width: popup.theme.notificationCenterDndKnobSize
                        height: popup.theme.notificationCenterDndKnobSize
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: popup.services.notificationDnd ? parent.width - width - popup.theme.notificationCenterDndKnobMargin : popup.theme.notificationCenterDndKnobMargin
                        color: popup.services.notificationDnd ? popup.palette.base : popup.palette.overlay1

                        Behavior on x {
                            NumberAnimation {
                                duration: popup.theme.notificationCenterDndAnimationMs
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
                    spacing: popup.theme.notificationCenterSectionSpacing
                    visible: !popup.services.hasNotifications

                    AppText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: popup.icons.notificationsEmpty
                        color: popup.palette.overlay1
                        font.family: popup.theme.iconFontFamily
                        font.pixelSize: popup.theme.notificationCenterEmptyIconFontSize
                    }

                    AppText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No Notifications"
                        color: popup.palette.overlay1
                        font.family: popup.theme.textFontFamily
                        font.pixelSize: popup.theme.notificationCenterEmptyTextFontSize
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
                        spacing: popup.theme.notificationCenterListSpacing

                        Repeater {
                            model: popup.visible && popup.services.hasNotifications ? popup.services.notifications : []

                            NotificationCard {
                                required property var modelData

                                width: notificationList.width
                                palette: popup.palette
                                notificationData: modelData
                                cornerRadius: popup.theme.notificationCenterCardRadius
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
