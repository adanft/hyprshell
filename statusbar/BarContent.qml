import QtQuick

Item {
    id: root

    required property var colors
    required property var services
    required property var barWindow

    signal openNotificationCenterRequested
    signal openNetworkMenuRequested(var anchorItem)

    BarLayout {
        anchors.fill: parent
        colors: root.colors
        services: root.services
        barWindow: root.barWindow
        onOpenNotificationCenterRequested: root.openNotificationCenterRequested()
        onOpenNetworkMenuRequested: anchorItem => root.openNetworkMenuRequested(anchorItem)
    }
}
