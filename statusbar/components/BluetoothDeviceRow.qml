import QtQuick
import "NetworkMenu.js" as NetworkMenuLogic
Rectangle {
    id: root
    required property var device
    required property var colors
    required property var theme
    signal primaryActionRequested(string action)
    signal forgetRequested
    readonly property string action: NetworkMenuLogic.bluetoothDeviceAction(device)
    readonly property bool actionAvailable: action !== "none"
    readonly property bool forgetAvailable: Boolean(device && device.paired && !device.connected && !device.pairing)
    function requestPrimaryAction() {
        if (actionAvailable)
            primaryActionRequested(action);
    }
    function requestForget() {
        if (forgetAvailable)
            forgetRequested();
    }
    height: 52
    radius: theme.shape.radius8
    color: colors.transparent
    border.width: 0
    Accessible.role: Accessible.ListItem
    Accessible.name: device ? `${device.name || device.deviceName}, ${NetworkMenuLogic.bluetoothDeviceStatus(device)}` : "Bluetooth device"
    Column {
        anchors.left: parent.left
        anchors.right: actionButton.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.theme.spacing.space8
        anchors.rightMargin: root.theme.spacing.space8
        spacing: root.theme.spacing.space2

        Text {
            width: parent.width
            text: root.device?.name || root.device?.deviceName || "Bluetooth device"
            color: root.colors.text
            font.family: root.theme.typography.textFontFamily
            font.weight: root.device?.connected ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }

        Text {
            text: NetworkMenuLogic.bluetoothDeviceStatus(root.device)
            color: root.device?.connected ? root.colors.primary : root.colors.textSubtle
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
        }
    }

    Rectangle {
        id: actionButton
        objectName: "bluetoothPrimaryAction"
        width: 78
        height: root.theme.sizing.statusBarTrayMenuItemHeight - root.theme.spacing.space8
        anchors.right: forgetButton.left
        anchors.rightMargin: forgetButton.opacity > 0 ? root.theme.spacing.space6 : 0
        anchors.verticalCenter: parent.verticalCenter
        radius: root.theme.shape.radius6
        color: actionMouse.containsMouse || actionMouse.activeFocus ? root.colors.surfaceHover : root.colors.surface

        Text {
            anchors.centerIn: parent
            text: NetworkMenuLogic.bluetoothActionLabel(root.device)
            color: root.colors.text
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
        }

        MouseArea {
            id: actionMouse
            objectName: "bluetoothPrimaryInput"
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.actionAvailable
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Button
            Accessible.name: root.device
                ? `${NetworkMenuLogic.bluetoothActionLabel(root.device)} ${root.device.name || root.device.deviceName}`
                : "Bluetooth action"
            onClicked: root.requestPrimaryAction()
            Keys.onSpacePressed: root.requestPrimaryAction()
            Keys.onReturnPressed: root.requestPrimaryAction()
            Keys.onEnterPressed: root.requestPrimaryAction()
        }
    }

    Rectangle {
        id: forgetButton
        objectName: "bluetoothForgetAction"
        width: 58
        height: root.theme.sizing.statusBarTrayMenuItemHeight - root.theme.spacing.space8
        anchors.right: parent.right
        anchors.rightMargin: root.theme.spacing.space8
        anchors.verticalCenter: parent.verticalCenter
        radius: root.theme.shape.radius6
        opacity: root.forgetAvailable ? 1 : 0
        color: forgetMouse.containsMouse || forgetMouse.activeFocus ? root.colors.surfaceHover : root.colors.transparent

        Text {
            anchors.centerIn: parent
            text: "Forget"
            color: root.colors.danger
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
        }

        MouseArea {
            id: forgetMouse
            objectName: "bluetoothForgetInput"
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.forgetAvailable
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Button
            Accessible.name: root.device ? `Forget ${root.device.name || root.device.deviceName}` : "Forget device"
            Accessible.ignored: !root.forgetAvailable
            onClicked: root.requestForget()
            Keys.onSpacePressed: root.requestForget()
            Keys.onReturnPressed: root.requestForget()
            Keys.onEnterPressed: root.requestForget()
        }
    }
}
