import QtQuick
import "widgets"

Item {
    id: root

    required property var palette
    required property var services
    required property var barWindow

    NotificationCenter {
        id: notificationCenter

        palette: root.palette
        services: root.services
        barWindow: root.barWindow
    }

    NotificationPopupManager {
        palette: root.palette
        services: root.services
        barWindow: root.barWindow
    }

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Workspaces { palette: root.palette }
        WindowTitle { palette: root.palette }
    }

    Time {
        id: timeWidget

        anchors.centerIn: parent
        palette: root.palette
        services: root.services
    }

    PowerProfile {
        anchors.left: timeWidget.right
        anchors.leftMargin: 6
        anchors.verticalCenter: timeWidget.verticalCenter
        palette: root.palette
        services: root.services
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Tray {
            palette: root.palette
            barWindow: root.barWindow
        }
        Rectangle {
            implicitWidth: rightClusterContent.implicitWidth
            implicitHeight: 30
            radius: 999
            color: root.palette.base

            Row {
                id: rightClusterContent

                anchors.fill: parent
                spacing: 0

                Network { palette: root.palette; services: root.services; grouped: true }
                Bluetooth { palette: root.palette; services: root.services; grouped: true }
                Audio { palette: root.palette; services: root.services; source: false; grouped: true }
                Audio { palette: root.palette; services: root.services; source: true; grouped: true }
                Notifications {
                    palette: root.palette
                    services: root.services
                    grouped: true
                    onOpenRequested: notificationCenter.visible = !notificationCenter.visible
                }
            }
        }
        Date { palette: root.palette; services: root.services }
    }
}
