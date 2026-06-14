import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

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
    }

}
