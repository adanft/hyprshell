import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Wayland
import "../../theme"

Item {
    id: root

    readonly property var theme: AppTheme {}
    readonly property var icons: Icons {}

    required property var colors
    required property var services
    required property var barWindow

    property bool menuOpen: false
    property real menuAnchorX: 0
    property real menuAnchorY: theme.sizing.statusBarOuterHeight
    property var pendingNetwork: null
    property string connectionError: ""

    function toggle(anchorItem) {
        if (menuOpen) {
            close();
            return;
        }
        open(anchorItem);
    }

    function open(anchorItem) {
        if (anchorItem) {
            const globalPosition = anchorItem.mapToGlobal(anchorItem.width / 2, anchorItem.height);
            const screenX = barWindow.screen ? (barWindow.screen.x || 0) : 0;
            const screenY = barWindow.screen ? (barWindow.screen.y || 0) : 0;
            menuAnchorX = globalPosition.x - screenX;
            menuAnchorY = globalPosition.y - screenY + theme.spacing.space6;
        }
        connectionError = "";
        menuOpen = true;
    }

    function close() {
        menuOpen = false;
        pendingNetwork = null;
        passwordInput.text = "";
        connectionError = "";
    }

    function connectNetwork(network) {
        connectionError = "";
        if (network.connected) {
            network.disconnect();
            return;
        }
        if (network.known || network.security === WifiSecurityType.None) {
            network.connect();
            return;
        }
        pendingNetwork = network;
        passwordInput.text = "";
        passwordInput.forceActiveFocus();
    }

    function submitPassword() {
        if (!pendingNetwork || passwordInput.text.length === 0)
            return;
        pendingNetwork.connectWithPsk(passwordInput.text);
        passwordInput.text = "";
        pendingNetwork = null;
    }

    PanelWindow {
        id: menuWindow

        visible: root.menuOpen
        screen: root.barWindow.screen
        color: root.colors.transparent
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-statusbar-network-menu"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        Shortcut {
            sequence: "Escape"
            onActivated: root.close()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.close()
        }

        Rectangle {
            id: menuContainer

            width: Math.max(320, root.theme.sizing.statusBarTrayMenuWidth)
            height: Math.min(menuWindow.height - root.theme.spacing.space16, Math.max(260, menuColumn.implicitHeight + root.theme.spacing.space16))
            x: Math.max(root.theme.spacing.space8, Math.min(menuWindow.width - width - root.theme.spacing.space8, root.menuAnchorX - width / 2))
            y: Math.max(root.theme.spacing.space8, Math.min(menuWindow.height - height - root.theme.spacing.space8, root.menuAnchorY))
            radius: root.theme.shape.radius12
            color: root.colors.background
            border.color: root.colors.border
            border.width: root.theme.shape.borderThin

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: root.theme.spacing.space8
                contentWidth: width
                contentHeight: menuColumn.implicitHeight
                clip: true

                Column {
                    id: menuColumn
                    width: parent.width
                    spacing: root.theme.spacing.space6

                    BarText {
                        text: "Network"
                        color: root.colors.text
                        font.family: root.theme.typography.textFontFamily
                        font.pixelSize: root.theme.typography.sizeXl
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        height: root.theme.shape.borderThin
                        color: root.colors.border
                    }

                    BarText {
                        text: "LAN"
                        color: root.colors.textMuted
                        font.family: root.theme.typography.textFontFamily
                        font.pixelSize: root.theme.typography.sizeSm
                    }

                    BarText {
                        width: parent.width
                        text: {
                            const device = root.services.lanDevice;
                            if (!device)
                                return "No wired adapter";
                            if (!device.hasLink)
                                return `${device.name} · Cable disconnected`;
                            const speed = device.linkSpeed > 0 ? ` · ${device.linkSpeed} Mb/s` : "";
                            return `${device.name} · ${device.connected ? "Connected" : "Connecting"}${speed}`;
                        }
                        color: root.services.lanUp ? root.colors.primary : root.colors.textSubtle
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: parent.width
                        height: root.theme.shape.borderThin
                        color: root.colors.border
                    }

                    Row {
                        width: parent.width
                        spacing: root.theme.spacing.space8

                        BarText {
                            width: parent.width - wifiToggle.width - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Wi-Fi"
                            color: root.colors.text
                            font.family: root.theme.typography.textFontFamily
                            font.pixelSize: root.theme.typography.sizeLg
                            font.bold: true
                        }

                        Rectangle {
                            id: wifiToggle
                            width: 42
                            height: 22
                            radius: height / 2
                            color: Networking.wifiEnabled ? root.colors.primary : root.colors.surfaceHover
                            border.color: root.colors.border

                            Rectangle {
                                width: 16
                                height: 16
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: Networking.wifiEnabled ? parent.width - width - 3 : 3
                                color: root.colors.background
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: Networking.wifiHardwareEnabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                            }
                        }
                    }

                    BarText {
                        width: parent.width
                        text: root.services.connectedWifiNetwork
                            ? `${root.services.connectedWifiNetwork.name} · ${root.services.wifiSignal}%`
                            : (Networking.wifiHardwareEnabled ? "Not connected" : "Wi-Fi disabled by hardware")
                        color: root.services.wifiUp ? root.colors.primary : root.colors.textSubtle
                        elide: Text.ElideRight
                    }

                    BarText {
                        visible: root.connectionError.length > 0
                        width: parent.width
                        text: root.connectionError
                        color: root.colors.danger
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        visible: root.pendingNetwork !== null
                        width: parent.width
                        height: passwordColumn.implicitHeight + root.theme.spacing.space12
                        radius: root.theme.shape.radius8
                        color: root.colors.surface
                        border.color: root.colors.border

                        Column {
                            id: passwordColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: root.theme.spacing.space6
                            spacing: root.theme.spacing.space6

                            BarText {
                                text: root.pendingNetwork ? `Password for ${root.pendingNetwork.name}` : "Password"
                                color: root.colors.text
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Rectangle {
                                width: parent.width
                                height: root.theme.sizing.statusBarTrayMenuItemHeight
                                radius: root.theme.shape.radius8
                                color: root.colors.background
                                border.color: passwordInput.activeFocus ? root.colors.primary : root.colors.border

                                TextInput {
                                    id: passwordInput
                                    anchors.fill: parent
                                    anchors.leftMargin: root.theme.spacing.space8
                                    anchors.rightMargin: root.theme.spacing.space8
                                    color: root.colors.text
                                    selectionColor: root.colors.primary
                                    echoMode: TextInput.Password
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: root.theme.typography.textFontFamily
                                    onAccepted: root.submitPassword()
                                }
                            }
                        }
                    }

                    Repeater {
                        model: root.services.wifiDevice?.networks?.values ?? []

                        Rectangle {
                            id: networkRow
                            required property var modelData
                            width: menuColumn.width
                            height: root.theme.sizing.statusBarTrayMenuItemHeight + root.theme.spacing.space4
                            radius: root.theme.shape.radius8
                            color: networkMouse.containsMouse ? root.colors.surfaceHover : root.colors.transparent

                            Connections {
                                target: networkRow.modelData
                                function onConnectionFailed(reason) {
                                    root.connectionError = `${networkRow.modelData.name}: ${ConnectionFailReason.toString(reason)}`;
                                    if (reason === ConnectionFailReason.NoSecrets) {
                                        root.pendingNetwork = networkRow.modelData;
                                        passwordInput.forceActiveFocus();
                                    }
                                }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: root.theme.spacing.space8
                                anchors.rightMargin: root.theme.spacing.space8
                                spacing: root.theme.spacing.space8

                                BarText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: networkRow.modelData.connected ? root.icons.wifiConnected : root.icons.wifiDisconnected
                                    color: networkRow.modelData.connected ? root.colors.primary : root.colors.text
                                }

                                BarText {
                                    width: parent.width - 72
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: networkRow.modelData.name
                                    color: root.colors.text
                                    elide: Text.ElideRight
                                }

                                BarText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: networkRow.modelData.stateChanging
                                        ? "…"
                                        : `${Math.round((networkRow.modelData.signalStrength || 0) * 100)}%`
                                    color: root.colors.textMuted
                                }
                            }

                            MouseArea {
                                id: networkMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !networkRow.modelData.stateChanging
                                onClicked: root.connectNetwork(networkRow.modelData)
                            }
                        }
                    }

                    BarText {
                        visible: Networking.wifiEnabled && (root.services.wifiDevice?.networks?.values?.length ?? 0) === 0
                        text: "Scanning for networks…"
                        color: root.colors.textMuted
                    }
                }
            }
        }
    }

    Binding {
        target: root.services.wifiDevice
        property: "scannerEnabled"
        value: root.menuOpen && Networking.wifiEnabled
        when: root.services.wifiDevice !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
