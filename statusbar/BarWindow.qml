import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "components"
import "../controlcenter"

PanelWindow {
    id: window

    readonly property var theme: AppTheme
    readonly property alias notificationImageCaptureHost: notificationImageCaptureHost

    required property var services

    signal openNotificationCenterRequested

    implicitHeight: theme.sizing.statusBarOuterHeight
    exclusiveZone: theme.sizing.statusBarOuterHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "qs-statusbar"
    objectName: `qs-statusbar:${window.screen ? window.screen.name : ""}`

    anchors {
        top: true
        left: true
        right: true
    }

    Item {
        id: notificationImageCaptureHost

        readonly property string captureHostKey: window.screen ? window.screen.name : ""
        readonly property var captureWindow: window

        width: window.theme.sizing.notificationCardIconSaveSize
        height: width
        x: -width - 1
        enabled: false
        visible: true

        Component.onCompleted: window.services.notification.registerNotificationImageCaptureHost(notificationImageCaptureHost)
        Component.onDestruction: window.services.notification.unregisterNotificationImageCaptureHost(notificationImageCaptureHost)
    }

    BarContent {
        anchors.fill: parent
        anchors.topMargin: window.theme.spacing.space6
        anchors.leftMargin: window.theme.spacing.space6
        anchors.rightMargin: window.theme.spacing.space6
        anchors.bottomMargin: 0
        services: window.services
        barWindow: window
        onOpenNotificationCenterRequested: window.openNotificationCenterRequested()
        onOpenControlCenterRequested: (anchorItem, section) => {
            controlCenterLoader.requestedOpen = !controlCenterLoader.requestedOpen
            if (!controlCenterLoader.requestedOpen) {
                if (controlCenterLoader.item && controlCenterLoader.item.menuOpen)
                    controlCenterLoader.item.close()
                else
                    controlCenterLoader.active = false
                return
            }

            controlCenterLoader.active = true
            Qt.callLater(() => {
                if (controlCenterLoader.requestedOpen && controlCenterLoader.item)
                    controlCenterLoader.item.open(anchorItem, section)
            })
        }
    }

    LazyLoader {
        id: controlCenterLoader
        property bool requestedOpen: false
        active: false

        ControlCenter {
            services: window.services
            barWindow: window
        }
    }

    Connections {
        target: controlCenterLoader.item
        enabled: target !== null
        function onMenuOpenChanged() {
            const menu = controlCenterLoader.item
            if (menu && !menu.menuOpen) {
                controlCenterLoader.requestedOpen = false
                controlCenterLoader.active = false
            }
        }
    }
}
