import QtQuick
import "../theme"
import "components"
import "modules"
import "../tray"
import "../shared/components"

Item {
    id: root

    readonly property var theme: AppTheme
    readonly property var icons: Icons

    required property var services
    required property var barWindow

    signal openNotificationCenterRequested
    signal openControlCenterRequested(var anchorItem, string section)

    Row {
        id: leftAnchor

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Background {
            width: implicitWidth
            height: root.theme.sizing.statusBarHeight
            padding: root.theme.spacing.space16

            Workspaces {
                id: workspaces

                services: root.services
                screen: root.barWindow.screen
            }
        }

        Spacer {}

        Background {
            width: implicitWidth
            height: root.theme.sizing.statusBarHeight
            padding: root.theme.spacing.space12 + root.theme.spacing.space6
            contentSpacing: root.theme.spacing.space6 * 2

            Processor {
                services: root.services
            }

            Ram {
                services: root.services
            }
        }

        Spacer {}

        Background {
            id: trayBackground

            width: tray.implicitWidth
            height: root.theme.sizing.statusBarHeight
            visible: tray.hasItems
            backgroundColor: "transparent"

            Tray {
                id: tray

                barWindow: root.barWindow
            }
        }
    }

    Item {
        id: centerAnchor

        anchors.fill: parent

        Row {
            anchors.right: timeBackground.left
            anchors.verticalCenter: timeBackground.verticalCenter
            spacing: 0

            Background {
                id: controlCenterButton
                width: root.theme.sizing.statusBarIconSize
                height: root.theme.sizing.statusBarHeight
                backgroundColor: "transparent"

                Item {
                    width: root.theme.sizing.statusBarIconSize
                    height: root.theme.sizing.statusBarIconSize

                    AppText {
                        anchors.centerIn: parent
                        text: root.icons.controlCenter
                        color: Colors.tertiary
                        font.family: root.theme.typography.iconFontFamily
                        font.pixelSize: root.theme.typography.statusBarIconFontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openControlCenterRequested(controlCenterButton, "")
                    }
                }
            }

            Spacer {}
        }

        Background {
            id: timeBackground

            width: implicitWidth
            height: root.theme.sizing.statusBarHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            padding: root.theme.spacing.space12

            Time {
                id: timeWidget

                services: root.services
            }
        }

        Row {
            anchors.left: timeBackground.right
            anchors.verticalCenter: timeBackground.verticalCenter
            spacing: 0

            Spacer {}

            Background {
                width: root.theme.sizing.statusBarIconSize
                height: root.theme.sizing.statusBarHeight
                backgroundColor: "transparent"

                PowerProfile {
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
            padding: root.theme.spacing.space12 + root.theme.spacing.space6

            Row {
                id: rightClusterContent

                spacing: root.theme.spacing.space6 * 2

                NetworkThroughput {
                    id: throughputModule
                    services: root.services
                    // No section of its own: it reports whichever interface is
                    // live, which may be either of them.
                    onOpenRequested: root.openControlCenterRequested(throughputModule, "")
                }

                NetworkWifi {
                    id: wifiModule
                    services: root.services
                    onOpenRequested: root.openControlCenterRequested(wifiModule, "wifi")
                }

                Bluetooth {
                    id: bluetoothModule
                    services: root.services
                    onOpenRequested: root.openControlCenterRequested(bluetoothModule, "bluetooth")
                }

                Sound {
                    id: soundModule
                    services: root.services
                    onOpenRequested: root.openControlCenterRequested(soundModule, "output")
                }

                Backlight {
                    services: root.services
                }

                Battery {
                    services: root.services
                }

                Microphone {
                    id: microphoneModule
                    services: root.services
                    onOpenRequested: root.openControlCenterRequested(microphoneModule, "microphone")
                }

                Notifications {
                    services: root.services
                    onOpenRequested: root.openNotificationCenterRequested()
                }
            }
        }

        Spacer {}

        Background {
            width: implicitWidth
            height: root.theme.sizing.statusBarHeight
            padding: root.theme.spacing.space12

            Date {
                id: dateModule

                services: root.services
            }
        }
    }
}
