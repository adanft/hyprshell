import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var palette
    required property var services

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 42
    exclusiveZone: 42
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "qs-statusbar"

    BarContent {
        anchors.fill: parent
        anchors.margins: 6
        palette: window.palette
        services: window.services
        barWindow: window
    }
}
