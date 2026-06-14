import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    readonly property var
    theme: BarTheme {
    }

    required property var palette
    required property var services

    signal openNotificationCenterRequested()

    implicitHeight: theme.outerHeight
    exclusiveZone: theme.outerHeight
    color: window.palette.transparent
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "qs-statusbar"

    anchors {
        top: true
        left: true
        right: true
    }

    BarContent {
        anchors.fill: parent
        anchors.topMargin: window.theme.edgeMargin
        anchors.leftMargin: window.theme.edgeMargin
        anchors.rightMargin: window.theme.edgeMargin
        anchors.bottomMargin: 0
        palette: window.palette
        services: window.services
        barWindow: window
        onOpenNotificationCenterRequested: window.openNotificationCenterRequested()
    }

}
