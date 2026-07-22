import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "components"

PanelWindow {
    id: window

    readonly property var
    theme: AppTheme {
    }

    required property var colors
    required property var services

    signal openNotificationCenterRequested()

    implicitHeight: theme.sizing.statusBarOuterHeight
    exclusiveZone: theme.sizing.statusBarOuterHeight
    color: window.colors.transparent
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "qs-statusbar"

    anchors {
        top: true
        left: true
        right: true
    }

    BarContent {
        anchors.fill: parent
        anchors.topMargin: window.theme.spacing.space6
        anchors.leftMargin: window.theme.spacing.space6
        anchors.rightMargin: window.theme.spacing.space6
        anchors.bottomMargin: 0
        colors: window.colors
        services: window.services
        barWindow: window
        onOpenNotificationCenterRequested: window.openNotificationCenterRequested()
        onOpenNetworkMenuRequested: anchorItem => {
            networkMenuLoader.requestedOpen = !networkMenuLoader.requestedOpen;
            if (!networkMenuLoader.requestedOpen) {
                if (networkMenuLoader.item && networkMenuLoader.item.menuOpen)
                    networkMenuLoader.item.close();
                else
                    networkMenuLoader.active = false;
                return;
            }

            networkMenuLoader.active = true;
            Qt.callLater(() => {
                if (networkMenuLoader.requestedOpen && networkMenuLoader.item)
                    networkMenuLoader.item.open(anchorItem);
            });
        }
    }

    LazyLoader {
        id: networkMenuLoader
        property bool requestedOpen: false
        active: false

        NetworkMenu {
            colors: window.colors
            services: window.services
            barWindow: window
        }
    }

    Connections {
        target: networkMenuLoader.item
        enabled: target !== null
        function onMenuOpenChanged() {
            const menu = networkMenuLoader.item;
            if (menu && !menu.menuOpen) {
                networkMenuLoader.requestedOpen = false;
                networkMenuLoader.active = false;
            }
        }
    }
}
