import QtQuick
import "NetworkMenu.js" as NetworkMenuLogic

Rectangle {
    id: root
    required property var device
    required property var colors
    required property var theme
    property bool pending: false
    property bool powered: true
    property bool primaryActionVisible: true
    signal primaryActionRequested
    signal forgetRequested

    readonly property string action: NetworkMenuLogic.bluetoothDeviceAction(device)
    readonly property bool busy: pending || action === "busy"
    readonly property bool forgetAvailable: Boolean(powered && device && (device.connected || device.paired || device.trusted))
    height: theme.sizing.statusBarNetworkDeviceRowHeight
    radius: theme.shape.radius12
    color: colors.surface
    Accessible.role: Accessible.ListItem
    Accessible.name: device ? `${device.name || device.deviceName || "Bluetooth device"}, ${NetworkMenuLogic.bluetoothDeviceState(device)}` : "Bluetooth device"

    function requestPrimaryAction() {
        if (!busy)
            primaryActionRequested()
    }
    function requestForget() {
        if (forgetAvailable && !busy)
            forgetRequested()
    }

    Text {
        id: deviceIcon
        objectName: "deviceIcon"
        anchors.left: parent.left
        anchors.leftMargin: theme.spacing.space12
        anchors.verticalCenter: parent.verticalCenter
        width: theme.sizing.statusBarNetworkQuickControlIconWidth
        text: NetworkMenuLogic.bluetoothDeviceIcon(root.device)
        color: root.device?.connected ? colors.primary : colors.text
        font.family: theme.typography.iconFontFamily
        font.pixelSize: theme.typography.sizeXl
        horizontalAlignment: Text.AlignHCenter
    }
    Column {
        anchors.left: deviceIcon.right
        anchors.right: actions.left
        anchors.leftMargin: theme.spacing.space8
        anchors.rightMargin: theme.spacing.space8
        anchors.verticalCenter: parent.verticalCenter
        spacing: theme.spacing.space2
        Text {
            width: parent.width
            text: root.device?.name || root.device?.deviceName || "Unknown device"
            color: root.colors.text
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeMd
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.busy ? "Working…" : NetworkMenuLogic.bluetoothDeviceState(root.device) + (NetworkMenuLogic.bluetoothBatteryText(root.device) ? " · " + NetworkMenuLogic.bluetoothBatteryText(root.device) : "")
            color: root.colors.textSubtle
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }
    }
    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: theme.spacing.space8
        anchors.verticalCenter: parent.verticalCenter
        spacing: theme.spacing.space4
        BluetoothActionButton {
            id: primaryButton
            objectName: "primaryActionButton"
            visible: root.primaryActionVisible
            label: root.busy ? "Working…" : (root.action === "pair" ? "Pair" : root.action === "connect" ? "Connect" : "Disconnect")
            danger: root.action === "disconnect"
            enabled: root.primaryActionVisible && !root.busy
            accessibleName: root.device ? primaryButton.label + " " + (root.device.name || root.device.deviceName || "device") : "Bluetooth action"
            onTriggered: root.requestPrimaryAction()
        }
        BluetoothActionButton {
            id: forgetButton
            objectName: "forgetAction"
            visible: root.forgetAvailable
            label: "Forget"
            danger: true
            enabled: root.forgetAvailable && !root.busy
            accessibleName: root.device ? "Forget " + (root.device.name || root.device.deviceName || "device") : "Forget device"
            onTriggered: root.requestForget()
        }
    }

    component BluetoothActionButton: Rectangle {
        required property string label
        required property string accessibleName
        property bool danger: false
        signal triggered
        width: labelText.implicitWidth + root.theme.spacing.space16
        height: root.theme.sizing.statusBarTrayMenuItemHeight - root.theme.spacing.space8
        radius: root.theme.shape.radius8
        color: input.containsMouse || input.activeFocus ? root.colors.surfaceHover : root.colors.transparent
        opacity: enabled ? 1 : root.theme.motion.opacityDisabled
        Text {
            id: labelText
            anchors.centerIn: parent
            text: parent.label
            color: parent.danger ? root.colors.danger : root.colors.primary
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleRegular
        }
        MouseArea {
            id: input
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: parent.enabled
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Button
            Accessible.name: parent.accessibleName
            onClicked: parent.triggered()
            Keys.onSpacePressed: parent.triggered()
            Keys.onReturnPressed: parent.triggered()
            Keys.onEnterPressed: parent.triggered()
        }
    }
}
