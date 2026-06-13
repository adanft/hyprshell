import QtQuick

Item {
    id: root

    required property var palette
    required property var services
    required property var barWindow

    signal openNotificationCenterRequested()

    BarLayout {
        anchors.fill: parent
        palette: root.palette
        services: root.services
        barWindow: root.barWindow
        onOpenNotificationCenterRequested: root.openNotificationCenterRequested()
    }

}
