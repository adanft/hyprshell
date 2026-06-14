import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: window

    readonly property var
    theme: AppTheme {
    }

    required property var palette
    required property var services

    signal openNotificationCenterRequested()

    implicitHeight: theme.sizing.statusBarOuterHeight
    exclusiveZone: theme.sizing.statusBarOuterHeight
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
        anchors.topMargin: window.theme.spacing.space6
        anchors.leftMargin: window.theme.spacing.space6
        anchors.rightMargin: window.theme.spacing.space6
        anchors.bottomMargin: 0
        palette: window.palette
        services: window.services
        barWindow: window
        onOpenNotificationCenterRequested: window.openNotificationCenterRequested()
    }

}
