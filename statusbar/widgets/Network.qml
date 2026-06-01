import QtQuick
import Quickshell

Row {
    id: root

    required property var palette
    required property var services
    property bool grouped: false

    spacing: 0

    Pill {
        palette: root.palette
        textColor: root.palette.blue
        backgroundColor: root.grouped ? "transparent" : root.palette.base
        horizontalPadding: 10
        text: root.services.lanUp ? `󰌗  ${root.formatRate(root.services.lanTxRate)}    ${root.formatRate(root.services.lanRxRate)}  ` : "󰌙  0    0  "
        radius: 999

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openNetworkManager()
        }
    }

    Pill {
        palette: root.palette
        textColor: root.palette.red
        backgroundColor: root.grouped ? "transparent" : root.palette.base
        horizontalPadding: 10
        text: root.services.wifiUp && root.services.wifiSignal > 0 ? `󰤨  ${root.services.wifiSignal}%` : "󰤭"
        radius: 999

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openNetworkManager()
        }
    }

    function formatRate(bytes) {
        if (bytes < 1024)
            return `${Math.round(bytes)}B`
        if (bytes < 1024 * 1024)
            return `${Math.round(bytes / 1024)}K`
        return `${(bytes / 1024 / 1024).toFixed(1)}M`
    }

    function openNetworkManager() {
        Quickshell.execDetached(["alacritty", "--class", "floating", "-e", "nmtui"])
    }
}
