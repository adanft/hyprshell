import "../components"
import QtQuick
import Quickshell
import "../../theme"

Item {
    id: root

    readonly property var
    icons: Icons {
    }

    readonly property var
    theme: AppTheme {
    }

    required property var colors
    required property var services

    function formatRate(bytes) {
        if (bytes < 1024)
            return `${Math.round(bytes)} B/s`;

        if (bytes < 1024 * 1024)
            return `${Math.round(bytes / 1024)} KiB/s`;

        return `${(bytes / 1024 / 1024).toFixed(1)} MiB/s`;
    }

    implicitWidth: content.implicitWidth
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight
    Component.onCompleted: {
        services.lanThroughputEnabled = true;
        services.refreshNetwork();
    }
    Component.onDestruction: {
        services.lanThroughputEnabled = false;
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        BarText {
            text: root.services.lanUp ? root.icons.networkLanConnected : root.icons.networkLanDisconnected
            color: root.colors.network
        }

        BarText {
            text: root.icons.networkDownload
            color: root.colors.network
        }

        BarText {
            text: root.services.lanUp ? root.formatRate(root.services.lanRxRate) : "0 B/s"
            color: root.colors.network
        }

        BarText {
            text: root.icons.networkUpload
            color: root.colors.network
        }

        BarText {
            text: root.services.lanUp ? root.formatRate(root.services.lanTxRate) : "0 B/s"
            color: root.colors.network
        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["alacritty", "--class", "floating", "-e", "nmtui"])
    }

}
