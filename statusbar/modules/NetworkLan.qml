import QtQuick
import Quickshell
import ".."
import "../components"

Item {
    id: root

    readonly property var icons: BarIcons {}
    readonly property var theme: BarTheme {}
    required property var palette
    required property var services

    implicitWidth: content.implicitWidth
    implicitHeight: theme.height
    width: implicitWidth
    height: implicitHeight

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.gap

        BarText {
            text: root.services.lanUp ? root.icons.networkLanConnected : root.icons.networkLanDisconnected
            color: root.palette.blue
        }

        BarText {
            text: root.icons.networkDownload
            color: root.palette.blue
        }

        BarText {
            text: root.services.lanUp ? root.formatRate(root.services.lanRxRate) : "0 B/s"
            color: root.palette.blue
        }

        BarText {
            text: root.icons.networkUpload
            color: root.palette.blue
        }

        BarText {
            text: root.services.lanUp ? root.formatRate(root.services.lanTxRate) : "0 B/s"
            color: root.palette.blue
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["alacritty", "--class", "floating", "-e", "nmtui"])
    }

    Component.onCompleted: {
        services.lanThroughputEnabled = true
        services.refreshNetwork()
    }

    Component.onDestruction: {
        services.lanThroughputEnabled = false
    }

    function formatRate(bytes) {
        if (bytes < 1024)
            return `${Math.round(bytes)} B/s`
        if (bytes < 1024 * 1024)
            return `${Math.round(bytes / 1024)} KiB/s`
        return `${(bytes / 1024 / 1024).toFixed(1)} MiB/s`
    }
}
