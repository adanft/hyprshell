import QtQuick
import "../theme"
import "components"
import "modules"

Item {
    id: root

    readonly property var
    theme: AppTheme {
    }

    required property var palette
    required property var services
    required property var barWindow

    signal openNotificationCenterRequested()

    Row {
        id: leftAnchor

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Background {
            width: implicitWidth
            height: root.theme.sizing.statusBarHeight
            palette: root.palette
            padding: root.theme.spacing.space16

            Workspaces {
                id: workspaces

                palette: root.palette
            }

        }

        Spacer {
        }

        Background {
            width: windowTitle.width
            height: root.theme.sizing.statusBarHeight
            palette: root.palette
            backgroundColor: root.palette.transparent

            WindowTitle {
                id: windowTitle

                palette: root.palette
            }

        }

    }

    Item {
        id: centerAnchor

        anchors.fill: parent

        Background {
            id: timeBackground

            width: implicitWidth
            height: root.theme.sizing.statusBarHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            palette: root.palette
            padding: root.theme.spacing.space12

            Time {
                id: timeWidget

                palette: root.palette
                services: root.services
            }

        }

        Row {
            anchors.left: timeBackground.right
            anchors.verticalCenter: timeBackground.verticalCenter
            spacing: 0

            Spacer {
            }

            Background {
                width: root.theme.sizing.statusBarIconSize
                height: root.theme.sizing.statusBarHeight
                palette: root.palette
                backgroundColor: root.palette.transparent

                PowerProfile {
                    palette: root.palette
                    services: root.services
                }

            }

        }

    }

    Row {
        id: rightAnchor

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Background {
            id: trayBackground

            width: tray.implicitWidth
            height: root.theme.sizing.statusBarHeight
            visible: tray.hasItems
            palette: root.palette
            backgroundColor: root.palette.transparent

            Tray {
                id: tray

                palette: root.palette
                barWindow: root.barWindow
            }

        }

        Spacer {
        }

        Background {
            width: implicitWidth
            height: root.theme.sizing.statusBarHeight
            palette: root.palette
            padding: root.theme.spacing.space12 + root.theme.spacing.space6

            Row {
                id: rightClusterContent

                spacing: root.theme.spacing.space6 * 2

                NetworkLan {
                    palette: root.palette
                    services: root.services
                }

                NetworkWifi {
                    palette: root.palette
                    services: root.services
                }

                Bluetooth {
                    palette: root.palette
                    services: root.services
                }

                Sound {
                    palette: root.palette
                    services: root.services
                }

                Backlight {
                    palette: root.palette
                    services: root.services
                }

                Battery {
                    palette: root.palette
                    services: root.services
                }

                Microphone {
                    palette: root.palette
                    services: root.services
                }

                Notifications {
                    palette: root.palette
                    services: root.services
                    onOpenRequested: root.openNotificationCenterRequested()
                }

            }

        }

        Spacer {
        }

        Background {
            width: implicitWidth
            height: root.theme.sizing.statusBarHeight
            palette: root.palette
            padding: root.theme.spacing.space12

            Date {
                id: dateModule

                palette: root.palette
                services: root.services
            }

        }

    }

}
