import QtQuick
import QtQuick.Window

Window {
    id: root

    required property var services
    readonly property int captureSize: root.services.notification.theme.sizing.notificationCardIconSaveSize
    property alias captureHost: captureHost

    width: captureSize
    height: captureSize
    visible: true
    opacity: 0
    color: "transparent"
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus

    Component.onCompleted: root.services.notification.registerNotificationImageCaptureHost(captureHost)
    Component.onDestruction: root.services.notification.unregisterNotificationImageCaptureHost(captureHost)

    Item {
        id: captureHost

        anchors.fill: parent
    }
}
