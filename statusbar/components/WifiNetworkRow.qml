import QtQuick
import "NetworkMenu.js" as NetworkMenuLogic
import "../../theme"

Rectangle {
    id: root

    required property var network
    required property var theme
    property var openSecurityValue: 0

    signal primaryActionRequested
    signal forgetRequested

    readonly property bool forgetAvailable: NetworkMenuLogic.canForgetNetwork(network)
    readonly property bool actionBusy: Boolean(network?.stateChanging)

    function requestPrimaryAction() {
        if (!network || actionBusy)
            return
        primaryActionRequested()
    }

    function requestForget() {
        if (!forgetAvailable)
            return
        forgetRequested()
    }

    height: theme.sizing.statusBarNetworkDeviceRowHeight
    radius: theme.shape.radius12
    color: Colors.surface
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
        anchors.rightMargin: root.theme.spacing.space12
        spacing: root.theme.spacing.space2

        Text {
            width: parent.width
            text: root.network?.name || ""
            color: root.network?.connected ? Colors.primary : Colors.on_surface
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeMd
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }

        Text {
            objectName: "wifiNetworkMeta"
            width: parent.width
            text: NetworkMenuLogic.wifiNetworkMeta(root.network, root.openSecurityValue)
            color: root.network?.connected ? Colors.primary : Colors.on_surface_variant
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: root.theme.spacing.space12
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.theme.spacing.space6

        Rectangle {
            id: primaryButton
            objectName: "primaryActionButton"
            width: primaryLabel.implicitWidth + root.theme.spacing.space16
            height: root.theme.sizing.statusBarTrayMenuItemHeight - root.theme.spacing.space8
            radius: root.theme.shape.radius8
            color: primaryInput.containsMouse || primaryInput.activeFocus ? Colors.hover :
                                                                            "transparent"

            opacity: root.actionBusy ? root.theme.motion.opacityDisabled : 1

            Text {
                id: primaryLabel
                objectName: "primaryActionLabel"
                anchors.centerIn: parent
                text: root.actionBusy ? "Please wait…" : (root.network?.connected ? "Disconnect" : "Connect")
                color: primaryInput.containsMouse || primaryInput.activeFocus ? Colors.on_hover :
                                                                                 (root.network?.connected ? Colors.error : Colors.primary)
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
                Accessible.name: root.network ? [root.network.connected ? "Disconnect from" : "Connect to", " ",
                                                 root.network.name].join("") : "Wi-Fi network"
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
            // Driven by the same condition as visible rather than by visible
            // itself: reading visible yields effective visibility, so the width
            // collapsed to zero whenever an ancestor was hidden, even though
            // the button was meant to be shown.
            width: root.forgetAvailable ? forgetLabel.implicitWidth + root.theme.spacing.space16 : 0
            height: root.theme.sizing.statusBarTrayMenuItemHeight - root.theme.spacing.space8
            radius: root.theme.shape.radius8
            color: forgetInput.containsMouse || forgetInput.activeFocus ? Colors.hover :
                                                                          "transparent"

            Text {
                id: forgetLabel
                anchors.centerIn: parent
                text: "Forget"
                color: forgetInput.containsMouse || forgetInput.activeFocus ? Colors.on_hover : Colors.error
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
