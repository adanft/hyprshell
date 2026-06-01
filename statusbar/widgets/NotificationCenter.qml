import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

PopupWindow {
    id: popup

    required property var palette
    required property var services
    required property var barWindow

    readonly property int contentPadding: 16
    readonly property int cardWidth: 380

    implicitWidth: cardWidth + contentPadding * 2
    implicitHeight: Math.round((barWindow.screen ? barWindow.screen.height : 560) * 0.75)
    visible: false
    grabFocus: true
    color: "transparent"

    anchor.window: barWindow
    anchor.rect.x: Math.max(6, barWindow.width - width - 6)
    anchor.rect.y: 42

    onVisibleChanged: popup.services.setNotificationCenterOpen(visible)

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: popup.palette.base
        border.color: popup.palette.surface1
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: popup.contentPadding
            spacing: 12

            Row {
                id: headerRow

                width: parent.width
                height: 30

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - clearButton.width - 10
                    text: `Notifications (${popup.services.notificationCount})`
                    color: popup.palette.text
                    font.family: "SF Pro Display, Symbols Nerd Font"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: clearButton

                    anchors.verticalCenter: parent.verticalCenter
                    width: clearText.implicitWidth + 18
                    height: 28
                    radius: 999
                    color: clearMouse.containsMouse ? popup.palette.surface1 : "transparent"
                    border.color: popup.palette.surface1
                    border.width: 1
                    visible: popup.services.hasNotifications

                    Text {
                        id: clearText

                        anchors.centerIn: parent
                        text: "Clear"
                        color: popup.palette.subtext1
                        font.family: "SF Pro Display, Symbols Nerd Font"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
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

            Rectangle {
                id: divider

                width: parent.width
                height: 1
                color: popup.palette.surface1
            }

            Item {
                width: parent.width
                height: parent.height - headerRow.height - divider.height - parent.spacing * 2

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !popup.services.hasNotifications

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰂜"
                        color: popup.palette.overlay1
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 34
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Nothing to see here"
                        color: popup.palette.overlay1
                        font.family: "SF Pro Display"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
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
                        spacing: 10

                        Repeater {
                            model: popup.services.notifications

                            NotificationCard {
                                required property var modelData

                                width: notificationList.width
                                palette: popup.palette
                                notificationData: modelData
                                cornerRadius: 12
                                timeText: "now"
                                onCloseRequested: modelData.dismiss()
                                onActionInvoked: action => {
                                    if (action && action.invoke)
                                        action.invoke()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
