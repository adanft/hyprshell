import QtQuick
import "NetworkMenu.js" as NetworkMenuLogic

Rectangle {
    id: root

    required property var network
    required property var colors
    required property var theme
    property var openSecurityValue: 0

    signal primaryActionRequested
    signal forgetRequested

    readonly property bool forgetAvailable: NetworkMenuLogic.canForgetNetwork(network)
    readonly property bool actionBusy: Boolean(network?.stateChanging)

    function requestPrimaryAction() {
        if (!network || actionBusy)
            return;
        primaryActionRequested();
    }

    function requestForget() {
        if (!forgetAvailable)
            return;
        forgetRequested();
    }

    height: 48
    radius: theme.shape.radius12
    color: colors.surface
    border.width: 0

    Accessible.role: Accessible.ListItem
    Accessible.name: network ? `${network.name}, ${NetworkMenuLogic.networkStatus(network)}` : "Wi-Fi network"

    Column {
        id: networkDetails
        objectName: "networkDetails"
        anchors.left: parent.left
        anchors.right: actions.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.theme.spacing.space12
        anchors.rightMargin: root.theme.spacing.space8
        spacing: root.theme.spacing.space2

        Text {
            width: parent.width
            text: root.network?.name || ""
            color: root.network?.connected ? root.colors.primary : root.colors.text
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeMd
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }

        Text {
            objectName: "wifiNetworkMeta"
            width: parent.width
            text: NetworkMenuLogic.wifiNetworkMeta(root.network, root.openSecurityValue)
            color: root.network?.connected ? root.colors.primary : root.colors.textSubtle
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: root.theme.spacing.space8
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.theme.spacing.space4

        Rectangle {
            id: primaryButton
            objectName: "primaryActionButton"
            width: primaryLabel.implicitWidth + root.theme.spacing.space16
            height: root.theme.sizing.statusBarTrayMenuItemHeight - root.theme.spacing.space8
            radius: root.theme.shape.radius8
            color: primaryInput.containsMouse || primaryInput.activeFocus
                ? root.colors.surfaceHover
                : root.colors.transparent
            opacity: root.actionBusy ? 0.45 : 1

            Text {
                id: primaryLabel
                objectName: "primaryActionLabel"
                anchors.centerIn: parent
                text: root.actionBusy
                    ? "Please wait…"
                    : (root.network?.connected ? "Disconnect" : "Connect")
                color: root.network?.connected ? root.colors.danger : root.colors.primary
                font.family: root.theme.typography.textFontFamily
                font.pixelSize: root.theme.typography.sizeSm
                font.styleName: root.theme.typography.styleRegular
            }

            MouseArea {
                id: primaryInput
                objectName: "primaryAction"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: Boolean(root.network) && !root.actionBusy
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

        Rectangle {
            id: forgetButton
            objectName: "forgetAction"
            visible: root.forgetAvailable
            width: visible ? forgetLabel.implicitWidth + root.theme.spacing.space16 : 0
            height: root.theme.sizing.statusBarTrayMenuItemHeight - root.theme.spacing.space8
            radius: root.theme.shape.radius8
            color: forgetInput.containsMouse || forgetInput.activeFocus
                ? root.colors.surfaceHover
                : root.colors.transparent

            Text {
                id: forgetLabel
                anchors.centerIn: parent
                text: "Forget"
                color: root.colors.danger
                font.family: root.theme.typography.textFontFamily
                font.pixelSize: root.theme.typography.sizeSm
                font.styleName: root.theme.typography.styleRegular
            }

            MouseArea {
                id: forgetInput
                objectName: "forgetInput"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: root.forgetAvailable
                activeFocusOnTab: enabled
                Accessible.role: Accessible.Button
                Accessible.name: root.network ? `Forget ${root.network.name}` : "Forget network"
                onClicked: root.requestForget()
                Keys.onSpacePressed: root.requestForget()
                Keys.onReturnPressed: root.requestForget()
                Keys.onEnterPressed: root.requestForget()
            }
        }
    }
}
