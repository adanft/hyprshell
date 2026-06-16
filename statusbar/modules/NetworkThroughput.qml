import "../components"
import QtQuick
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
    readonly property bool networkAvailable: services.activeNetworkInterface.length > 0
    readonly property color throughputColor: networkAvailable ? colors.network : colors.wifiDisconnected

    function formatRate(bytes) {
        if (bytes === undefined || bytes === null || isNaN(bytes))
            return "0 B/s";

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
        services.networkThroughputEnabled = true;
        services.refreshNetwork();
    }
    Component.onDestruction: {
        services.networkThroughputEnabled = false;
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        BarText {
            text: root.icons.networkThroughput
            color: root.throughputColor
        }

        BarText {
            text: root.formatRate(root.services.activeNetworkTxRate)
            color: root.throughputColor
        }

        BarText {
            text: root.formatRate(root.services.activeNetworkRxRate)
            color: root.throughputColor
        }


    }

}
