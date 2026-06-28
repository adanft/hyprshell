import QtQuick
import "../theme"
import "components"
import "modules"

Item {
    id: root

    readonly property var
    theme: AppTheme {
    }

    required property var colors
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
            colors: root.colors
            padding: root.theme.spacing.space16

            Workspaces {
                id: workspaces

                colors: root.colors
            }

        }

        Spacer {
        }

        Background {
            id: trayBackground

            width: tray.implicitWidth
            height: root.theme.sizing.statusBarHeight
            visible: tray.hasItems
            colors: root.colors
            backgroundColor: root.colors.transparent

            Tray {
                id: tray

                colors: root.colors
                barWindow: root.barWindow
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
            colors: root.colors
            padding: root.theme.spacing.space12

            Time {
                id: timeWidget

                colors: root.colors
                services: root.services
            }

        }

        Row {
            anchors.right: timeBackground.left
            anchors.verticalCenter: timeBackground.verticalCenter
            spacing: 0

            Background {
                width: implicitWidth
                height: root.theme.sizing.statusBarHeight
                colors: root.colors
                padding: root.theme.spacing.space12 + root.theme.spacing.space6
                contentSpacing: root.theme.spacing.space6 * 2

                Processor {
                    colors: root.colors
                    services: root.services
                }

                Ram {
                    colors: root.colors
                    services: root.services
                }

            }

            Spacer {
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
                colors: root.colors
                backgroundColor: root.colors.transparent

                PowerProfile {
                    colors: root.colors
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
            width: implicitWidth
            height: root.theme.sizing.statusBarHeight
            colors: root.colors
            padding: root.theme.spacing.space12 + root.theme.spacing.space6

            Row {
                id: rightClusterContent

                spacing: root.theme.spacing.space6 * 2

                NetworkThroughput {
                    colors: root.colors
                    services: root.services
                }

                NetworkWifi {
                    colors: root.colors
                    services: root.services
                }

                Bluetooth {
                    colors: root.colors
                    services: root.services
                }

                Sound {
                    colors: root.colors
                    services: root.services
                }

                Backlight {
                    colors: root.colors
                    services: root.services
                }

                Battery {
                    colors: root.colors
                    services: root.services
                }

                Microphone {
                    colors: root.colors
                    services: root.services
                }

                Notifications {
                    colors: root.colors
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
            colors: root.colors
            padding: root.theme.spacing.space12

            Date {
                id: dateModule

                colors: root.colors
                services: root.services
            }

        }

    }

}
