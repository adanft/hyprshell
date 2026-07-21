import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import Quickshell.Widgets
import "../../theme"
import "NetworkMenu.js" as NetworkMenuLogic

Item {
    id: root

    readonly property var theme: AppTheme {}
    readonly property var icons: Icons {}
    readonly property string username: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "User"
    readonly property string hostname: NetworkMenuLogic.hostnameOrFallback(hostnameFile.loaded ? hostnameFile.text() : "")
    readonly property string userInitial: NetworkMenuLogic.userInitial(username)
    readonly property int menuWidth: 420
    readonly property int userCardHeight: 88
    readonly property int avatarSize: 64
    readonly property int detailRowHeight: 46
    readonly property int toggleWidth: 42
    readonly property int toggleHeight: 22
    readonly property int toggleKnobSize: 16
    readonly property int userTextReserve: 76
    readonly property int lanStatusReserve: 90
    readonly property int networkTextReserve: 78
    readonly property int quickControlHeight: 54
    readonly property int quickControlIconWidth: 22

    required property var colors
    required property var services
    required property var barWindow

    property bool menuOpen: false
    property real menuAnchorX: 0
    property real menuAnchorY: theme.sizing.statusBarOuterHeight
    property var pendingNetwork: null
    property string connectionError: ""
    property real uptimeSeconds: 0
    property int quickControlRequestSequence: 0
    function volumeIcon() {
        if (root.services.quickVolume?.muted)
            return root.icons.volumeMuted;
        const percent = root.services.quickVolume?.authoritativePercent;
        if (percent === null || percent === undefined || percent < 34)
            return root.icons.volumeLow;
        if (percent < 67)
            return root.icons.volumeMedium;
        return root.icons.volumeHigh;
    }

    function refreshUptime() {
        uptimeFile.reload();
        const value = Number.parseFloat(String(uptimeFile.text() || "0").split(/\s+/)[0]);
        if (!Number.isNaN(value))
            uptimeSeconds = value;
    }

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
        refreshUptime();
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

    FileView {
        id: hostnameFile
        path: "/etc/hostname"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        blockLoading: true
        printErrors: false
        Component.onCompleted: root.refreshUptime()
    }

    Timer {
        interval: 60000
        running: root.menuOpen
        repeat: true
        onTriggered: root.refreshUptime()
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

            width: root.menuWidth
            height: Math.min(menuWindow.height - root.theme.spacing.space16, Math.max(360, menuColumn.implicitHeight + root.theme.spacing.space24))
            x: Math.max(root.theme.spacing.space8, Math.min(menuWindow.width - width - root.theme.spacing.space8, root.menuAnchorX - width / 2))
            y: Math.max(root.theme.spacing.space8, Math.min(menuWindow.height - height - root.theme.spacing.space8, root.menuAnchorY))
            radius: root.theme.shape.radius16
            color: root.colors.background
            border.color: root.colors.border
            border.width: root.theme.shape.borderThin

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: root.theme.spacing.space12
                contentWidth: width
                contentHeight: menuColumn.implicitHeight
                clip: true

                Column {
                    id: menuColumn
                    width: parent.width
                    spacing: root.theme.spacing.space8

                    Rectangle {
                        id: userCard
                        width: parent.width
                        height: root.userCardHeight
                        radius: root.theme.shape.radius12
                        color: root.colors.background
                        border.color: root.colors.border
                        border.width: root.theme.shape.borderThin

                        Row {
                            anchors.fill: parent
                            anchors.margins: root.theme.spacing.space12
                            spacing: root.theme.spacing.space12

                            Rectangle {
                                width: root.avatarSize
                                height: root.avatarSize
                                anchors.verticalCenter: parent.verticalCenter
                                radius: width / 2
                                color: root.colors.primary

                                BarText {
                                    anchors.centerIn: parent
                                    text: root.userInitial
                                    visible: avatarImage.status !== Image.Ready
                                    color: root.colors.background
                                    font.family: root.theme.typography.textFontFamily
                                    font.pixelSize: root.theme.typography.actionIconFontSize
                                    font.bold: true
                                }

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"

                                    Image {
                                        id: avatarImage
                                        anchors.fill: parent
                                        source: root.services.activeUserAvatarSource
                                        visible: status === Image.Ready
                                        asynchronous: true
                                        cache: false
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: root.avatarSize * 2
                                        sourceSize.height: root.avatarSize * 2
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: root.colors.primary
                                    border.width: 2
                                }
                            }

                            Column {
                                width: parent.width - root.userTextReserve
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space2

                                BarText {
                                    width: parent.width
                                    text: root.username
                                    color: root.colors.text
                                    font.family: root.theme.typography.textFontFamily
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                BarText {
                                    text: {
                                        const totalMinutes = Math.floor(Math.max(0, root.uptimeSeconds) / 60);
                                        const days = Math.floor(totalMinutes / 1440);
                                        const hours = Math.floor((totalMinutes % 1440) / 60);
                                        const minutes = totalMinutes % 60;
                                        return `up ${days} days, ${hours} hours, ${minutes} minutes`;
                                    }
                                    color: root.colors.textMuted
                                    font.pixelSize: root.theme.typography.sizeSm
                                    font.weight: Font.Normal
                                }
                            }
                        }
                    }

                        Item {
                            id: quickControlsRow
                            width: parent.width
                            height: root.quickControlHeight

                            Row {
                                anchors.fill: parent
                                spacing: root.theme.spacing.space8

                                Rectangle {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    radius: root.theme.shape.radius12
                                    color: root.colors.surface
                                    border.color: root.colors.border
                                    border.width: root.theme.shape.borderThin

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: root.theme.spacing.space12
                                        spacing: root.theme.spacing.space8

                                        BarText {
                                            width: root.quickControlIconWidth
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: Text.AlignHCenter
                                            text: root.volumeIcon()
                                            color: volumeSlider.enabled ? root.colors.text : root.colors.textMuted
                                            font.pixelSize: 20
                                        }

                                        QuickControlSlider {
                                            id: volumeSlider
                                            width: parent.width - root.quickControlIconWidth - parent.spacing
                                            height: 32
                                            anchors.verticalCenter: parent.verticalCenter
                                            value: root.services.quickVolume?.authoritativePercent ?? 0
                                            available: root.services.quickVolume?.authoritativePercent !== null
                                                && root.services.quickVolume?.authoritativePercent !== undefined
                                                && root.services.quickVolume?.availability !== "unavailable"
                                            trackColor: root.colors.background
                                            fillColor: root.colors.primary
                                            handleColor: root.colors.text
                                            handleBorderColor: root.colors.primary
                                            unavailableText: root.services.quickVolume?.errorText || "Volume unavailable"
                                            onLiveValueRequested: value => {
                                                root.quickControlRequestSequence += 1;
                                                root.services.requestSinkVolume(value, root.quickControlRequestSequence);
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    radius: root.theme.shape.radius12
                                    color: root.colors.surface
                                    border.color: root.colors.border
                                    border.width: root.theme.shape.borderThin

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: root.theme.spacing.space12
                                        spacing: root.theme.spacing.space8

                                        BarText {
                                            width: root.quickControlIconWidth
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "󰌵"
                                            color: brightnessSlider.enabled ? root.colors.text : root.colors.textMuted
                                            font.pixelSize: 20
                                        }

                                        QuickControlSlider {
                                            id: brightnessSlider
                                            width: parent.width - root.quickControlIconWidth - parent.spacing
                                            height: 32
                                            anchors.verticalCenter: parent.verticalCenter
                                            value: root.services.quickBrightness?.authoritativePercent ?? 0
                                            available: root.services.quickBrightness?.authoritativePercent !== null
                                                && root.services.quickBrightness?.authoritativePercent !== undefined
                                                && root.services.quickBrightness?.availability !== "unavailable"
                                            trackColor: root.colors.background
                                            fillColor: root.colors.primary
                                            handleColor: root.colors.text
                                            handleBorderColor: root.colors.primary
                                            unavailableText: root.services.quickBrightness?.errorText || "Brightness unavailable"
                                            onLiveValueRequested: value => {
                                                root.quickControlRequestSequence += 1;
                                                root.services.requestBrightness(value, root.quickControlRequestSequence);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: lanCard
                        width: parent.width
                        height: lanColumn.implicitHeight + root.theme.spacing.space24
                        radius: root.theme.shape.radius12
                        color: root.colors.surface
                        border.color: root.services.lanUp ? root.colors.primary : root.colors.border
                        border.width: root.services.lanUp ? root.theme.shape.borderMedium : root.theme.shape.borderThin

                        Column {
                            id: lanColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: root.theme.spacing.space12
                            spacing: root.theme.spacing.space8

                            Row {
                                width: parent.width
                                spacing: root.theme.spacing.space8

                                BarText {
                                    text: root.icons.networkThroughput
                                    color: root.services.lanUp ? root.colors.primary : root.colors.textMuted
                                    font.pixelSize: root.theme.typography.sizeLg
                                }

                                BarText {
                                    text: "LAN"
                                    color: root.colors.text
                                    font.pixelSize: root.theme.typography.sizeLg
                                    font.bold: true
                                }

                                BarText {
                                    width: parent.width - root.lanStatusReserve
                                    horizontalAlignment: Text.AlignRight
                                    text: root.services.lanUp ? "Connected" : "Disconnected"
                                    color: root.services.lanUp ? root.colors.primary : root.colors.textSubtle
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: root.detailRowHeight
                                radius: root.theme.shape.radius8
                                color: root.colors.background
                                border.color: root.colors.border
                                border.width: root.theme.shape.borderThin

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: root.theme.spacing.space8
                                    spacing: root.theme.spacing.space8

                                    Column {
                                        width: parent.width - speedLabel.width - parent.spacing
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: root.theme.spacing.space2

                                        BarText {
                                            width: parent.width
                                            text: root.services.lanDevice?.name || "No wired adapter"
                                            color: root.colors.text
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        BarText {
                                            width: parent.width
                                            text: root.services.lanDevice?.hasLink ? "Cable connected" : "Cable disconnected"
                                            color: root.colors.textMuted
                                            font.pixelSize: root.theme.typography.sizeSm
                                        }
                                    }

                                    BarText {
                                        id: speedLabel
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.services.lanDevice?.linkSpeed > 0 ? `${root.services.lanDevice.linkSpeed} Mb/s` : "—"
                                        color: root.colors.textSubtle
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: wifiCard
                        width: parent.width
                        height: wifiColumn.implicitHeight + root.theme.spacing.space24
                        radius: root.theme.shape.radius12
                        color: root.colors.surface
                        border.color: root.services.wifiUp ? root.colors.primary : root.colors.border
                        border.width: root.services.wifiUp ? root.theme.shape.borderMedium : root.theme.shape.borderThin

                        Column {
                            id: wifiColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: root.theme.spacing.space12
                            spacing: root.theme.spacing.space8

                            Row {
                                width: parent.width
                                spacing: root.theme.spacing.space8

                                BarText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.services.wifiUp ? root.icons.wifiConnected : root.icons.wifiDisconnected
                                    color: root.services.wifiUp ? root.colors.primary : root.colors.textMuted
                                    font.pixelSize: root.theme.typography.sizeLg
                                }

                                Column {
                                    width: parent.width - wifiToggle.width - root.theme.spacing.space16 - 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: root.theme.spacing.space2

                                    BarText {
                                        text: "Wi-Fi"
                                        color: root.colors.text
                                        font.pixelSize: root.theme.typography.sizeLg
                                        font.bold: true
                                    }

                                    BarText {
                                        width: parent.width
                                        text: NetworkMenuLogic.wifiSummary(root.services.connectedWifiNetwork, Networking.wifiHardwareEnabled)
                                        color: root.services.wifiUp ? root.colors.primary : root.colors.textSubtle
                                        font.pixelSize: root.theme.typography.sizeSm
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    id: wifiToggle
                                    width: root.toggleWidth
                                    height: root.toggleHeight
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: height / 2
                                    color: Networking.wifiEnabled ? root.colors.primary : root.colors.surfaceHover
                                    border.color: root.colors.border

                                    Rectangle {
                                        width: root.toggleKnobSize
                                        height: root.toggleKnobSize
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
                                color: root.colors.background
                                border.color: root.colors.border

                                Column {
                                    id: passwordColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: root.theme.spacing.space6
                                    spacing: root.theme.spacing.space6

                                    BarText {
                                        width: parent.width
                                        text: root.pendingNetwork ? `Password for ${root.pendingNetwork.name}` : "Password"
                                        color: root.colors.text
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: root.theme.sizing.statusBarTrayMenuItemHeight
                                        radius: root.theme.shape.radius8
                                        color: root.colors.surface
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
                                    width: wifiColumn.width
                                    height: root.detailRowHeight
                                    radius: root.theme.shape.radius8
                                    color: networkMouse.containsMouse ? root.colors.surfaceHover : root.colors.background
                                    border.color: networkRow.modelData.connected ? root.colors.primary : root.colors.border
                                    border.width: networkRow.modelData.connected ? root.theme.shape.borderMedium : root.theme.shape.borderThin

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
                                        anchors.margins: root.theme.spacing.space8
                                        spacing: root.theme.spacing.space8

                                        BarText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: networkRow.modelData.connected ? root.icons.wifiConnected : root.icons.wifiDisconnected
                                            color: networkRow.modelData.connected ? root.colors.primary : root.colors.text
                                        }

                                        Column {
                                            width: parent.width - root.networkTextReserve
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: root.theme.spacing.space2

                                            BarText {
                                                width: parent.width
                                                text: networkRow.modelData.name
                                                color: root.colors.text
                                                font.bold: networkRow.modelData.connected
                                                elide: Text.ElideRight
                                            }

                                            BarText {
                                                text: NetworkMenuLogic.networkStatus(networkRow.modelData)
                                                color: root.colors.textMuted
                                                font.pixelSize: root.theme.typography.sizeSm
                                            }
                                        }

                                        BarText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: NetworkMenuLogic.networkSignalText(networkRow.modelData)
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
