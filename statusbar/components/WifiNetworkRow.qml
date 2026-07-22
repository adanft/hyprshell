import QtQuick
import "NetworkMenu.js" as NetworkMenuLogic

Rectangle {
    id: root

    required property var network
    required property var colors
    required property var theme
    required property var icons

    signal primaryActionRequested
    signal forgetRequested

    readonly property bool forgetAvailable: NetworkMenuLogic.canForgetNetwork(network)

    function requestPrimaryAction() {
        if (!network || network.stateChanging)
            return;
        primaryActionRequested();
    }

    function requestForget() {
        if (!forgetAvailable)
            return;
        forgetRequested();
    }

    height: 48
    color: primaryMouse.containsMouse ? colors.surfaceHover : colors.transparent
    border.width: 0

    Accessible.role: Accessible.ListItem
    Accessible.name: network ? `${network.name}, ${NetworkMenuLogic.networkStatus(network)}` : "Wi-Fi network"

    Row {
        anchors.fill: parent
        anchors.margins: root.theme.spacing.space8
        spacing: root.theme.spacing.space8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.network.connected ? root.icons.wifiConnected : root.icons.wifiDisconnected
            color: root.network.connected ? root.colors.primary : root.colors.text
            font.family: root.theme.typography.iconFontFamily
        }

        Column {
            width: parent.width - signalLabel.width - forgetButton.width
                - (root.forgetAvailable ? parent.spacing * 2 : parent.spacing)
                - 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.theme.spacing.space2

            Text {
                width: parent.width
                text: root.network.name
                color: root.colors.text
                font.family: root.theme.typography.textFontFamily
                font.weight: root.network.connected ? Font.Medium : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                text: NetworkMenuLogic.networkStatus(root.network)
                color: root.colors.textMuted
                font.family: root.theme.typography.textFontFamily
                font.pixelSize: root.theme.typography.sizeSm
            }
        }

        Text {
            id: signalLabel
            anchors.verticalCenter: parent.verticalCenter
            text: NetworkMenuLogic.networkSignalText(root.network)
            color: root.colors.textMuted
            font.family: root.theme.typography.textFontFamily
        }

        Rectangle {
            id: forgetButton
            objectName: "forgetAction"
            width: 58
            opacity: root.forgetAvailable ? 1 : 0
            height: root.theme.sizing.statusBarTrayMenuItemHeight - root.theme.spacing.space8
            anchors.verticalCenter: parent.verticalCenter
            radius: root.theme.shape.radius6
            color: forgetMouse.containsMouse || forgetMouse.activeFocus
                ? root.colors.surfaceHover
                : root.colors.transparent
            border.width: 0

            Accessible.role: Accessible.Button
            Accessible.name: root.network ? `Forget ${root.network.name}` : "Forget network"
            Accessible.focusable: root.forgetAvailable
            Accessible.ignored: !root.forgetAvailable

            Text {
                id: forgetLabel
                anchors.centerIn: parent
                text: "Forget"
                color: root.colors.danger
                font.family: root.theme.typography.textFontFamily
                font.pixelSize: root.theme.typography.sizeSm
            }

            MouseArea {
                id: forgetMouse
                objectName: "forgetInput"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.forgetAvailable
                activeFocusOnTab: enabled
                onClicked: root.requestForget()
                Keys.onSpacePressed: root.requestForget()
                Keys.onReturnPressed: root.requestForget()
                Keys.onEnterPressed: root.requestForget()
            }
        }
    }

    MouseArea {
        id: primaryMouse
        objectName: "primaryAction"
        anchors.fill: parent
        anchors.rightMargin: root.forgetAvailable ? forgetButton.width + root.theme.spacing.space8 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: Boolean(root.network) && !root.network.stateChanging
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        Accessible.name: root.network
            ? `${root.network.connected ? "Disconnect from" : "Connect to"} ${root.network.name}`
            : "Wi-Fi network"
        onClicked: root.requestPrimaryAction()
        Keys.onSpacePressed: root.requestPrimaryAction()
        Keys.onReturnPressed: root.requestPrimaryAction()
        Keys.onEnterPressed: root.requestPrimaryAction()
    }
}
