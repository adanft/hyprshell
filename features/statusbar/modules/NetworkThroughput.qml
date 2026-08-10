import "../components"
import QtQuick
import "../../../theme"
import "../../../shared/components"

Item {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var services

    signal openRequested
    readonly property bool networkAvailable: services.network.activeNetworkInterface.length > 0
    readonly property bool moduleDisabled: !networkAvailable
    readonly property color neutralColor: moduleDisabled ? Colors.outline : Colors.on_surface
    readonly property color txColor: moduleDisabled ? Colors.outline : Colors.error
    readonly property color rxColor: moduleDisabled ? Colors.outline : Colors.tertiary

    function formatRate(bytes) {
        if (bytes === undefined || bytes === null || isNaN(bytes))
            return "0 B/s"

        if (bytes < 1024)
            return `${Math.round(bytes)} B/s`

        if (bytes < 1024 * 1024)
            return `${Math.round(bytes / 1024)} KiB/s`

        return `${(bytes / 1024 / 1024).toFixed(1)} MiB/s`
    }

    implicitWidth: content.implicitWidth
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight
    Component.onCompleted: services.network.enableNetworkThroughput()
    Component.onDestruction: services.network.disableNetworkThroughput()

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        AppText {
            text: root.icons.networkThroughput
            color: root.neutralColor
        }

        AppText {
            text: root.formatRate(root.services.network.activeNetworkTxRate)
            color: root.txColor
        }

        AppText {
            text: root.formatRate(root.services.network.activeNetworkRxRate)
            color: root.rxColor
        }
    }

    // A readout, not a switch: there is no throughput to turn off, so this only
    // opens the panel.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: "Open network controls"
        onClicked: root.openRequested()
        Keys.onSpacePressed: root.openRequested()
        Keys.onReturnPressed: root.openRequested()
        Keys.onEnterPressed: root.openRequested()
    }
}
