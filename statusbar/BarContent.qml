import QtQuick
import "../theme"

Item {
    id: root

    required property var services
    required property var barWindow

    signal openNotificationCenterRequested
    signal openNetworkMenuRequested(var anchorItem, string section)

    BarLayout {
        anchors.fill: parent
        services: root.services
        barWindow: root.barWindow
        onOpenNotificationCenterRequested: root.openNotificationCenterRequested()
        onOpenNetworkMenuRequested: (anchorItem, section) => root.openNetworkMenuRequested(anchorItem, section)
    }
}
