import QtQuick
import QtQuick.Controls as Controls
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
    property string expandedNetworkSection: ""

    function toggleNetworkSection(section) {
        expandedNetworkSection = NetworkMenuLogic.nextExpandedSection(expandedNetworkSection, section);
        connectionError = "";
        pendingNetwork = null;
        passwordInput.text = "";
    }

    function toggleEthernet() {
        const network = services.lanDevice?.network;
        const action = NetworkMenuLogic.ethernetToggleAction(network);
        if (action === "disconnect")
            network.disconnect();
        else if (action === "connect")
            network.connect();
    }

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
        expandedNetworkSection = "";
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

            width: Math.max(0, Math.min(root.menuWidth, menuWindow.width - root.theme.spacing.space16))
            height: Math.max(0, Math.min(
                menuWindow.height - root.theme.spacing.space16,
                Math.max(360, menuColumn.implicitHeight + root.theme.spacing.space24)
            ))
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
                id: menuFlickable
                anchors.fill: parent
                anchors.margins: root.theme.spacing.space12
                contentWidth: width
                contentHeight: menuColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    policy: menuFlickable.contentHeight > menuFlickable.height
                        ? Controls.ScrollBar.AlwaysOn
                        : Controls.ScrollBar.AlwaysOff
                }

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
                                            text: root.icons.brightnessControl
                                            color: brightnessSlider.enabled ? root.colors.text : root.colors.textMuted
                                            font.pixelSize: 20
                                        }

                                        QuickControlSlider {
                                            id: brightnessSlider
                                            width: parent.width - root.quickControlIconWidth - parent.spacing
                                            height: 32
                                            anchors.verticalCenter: parent.verticalCenter
                                            value: root.services.brightnessLevel
                                            available: root.services.brightnessAvailable
                                            trackColor: root.colors.background
                                            fillColor: root.colors.primary
                                            handleColor: root.colors.text
                                            handleBorderColor: root.colors.primary
                                            unavailableText: "Brightness unavailable"
                                            onLiveValueRequested: value => root.services.setBrightness(value)
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            id: networkControlsRow
                            width: parent.width
                            height: root.quickControlHeight

                            Row {
                                anchors.fill: parent
                                spacing: root.theme.spacing.space8

                                NetworkControlCard {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    colors: root.colors
                                    theme: root.theme
                                    icon: root.icons.ethernet
                                    title: "Ethernet"
                                    subtitle: root.services.lanUp
                                        ? "Connected"
                                        : (root.services.lanDevice?.hasLink ? "Disconnected" : "Cable unplugged")
                                    active: root.services.lanUp
                                    available: root.services.lanDevice?.network !== null
                                        && root.services.lanDevice?.network !== undefined
                                    busy: root.services.lanDevice?.network?.stateChanging ?? false
                                    expanded: root.expandedNetworkSection === "ethernet"
                                    onBodyClicked: root.toggleNetworkSection("ethernet")
                                    onToggled: root.toggleEthernet()
                                }

                                NetworkControlCard {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    colors: root.colors
                                    theme: root.theme
                                    icon: root.services.wifiUp ? root.icons.wifiConnected : root.icons.wifiDisconnected
                                    title: "Wi-Fi"
                                    subtitle: !Networking.wifiHardwareEnabled
                                        ? "Unavailable"
                                        : (!Networking.wifiEnabled
                                            ? "Disabled"
                                            : NetworkMenuLogic.wifiSummary(root.services.connectedWifiNetwork, true))
                                    active: Networking.wifiEnabled
                                    available: Networking.wifiHardwareEnabled
                                    expanded: root.expandedNetworkSection === "wifi"
                                    onBodyClicked: root.toggleNetworkSection("wifi")
                                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: root.quickControlHeight

                            Row {
                                anchors.fill: parent
                                spacing: root.theme.spacing.space8

                                NetworkControlCard {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    colors: root.colors
                                    theme: root.theme
                                    icon: root.services.sourceMuted ? root.icons.microphoneMuted : root.icons.microphone
                                    title: "Microphone"
                                    subtitle: !root.services.source?.audio
                                        ? "Unavailable"
                                        : (root.services.sourceMuted ? "Muted" : `${root.services.sourceVolume}%`)
                                    active: root.services.source?.audio !== null
                                        && root.services.source?.audio !== undefined
                                        && !root.services.sourceMuted
                                    available: root.services.source?.audio !== null
                                        && root.services.source?.audio !== undefined
                                    detailAvailable: available
                                    expanded: root.expandedNetworkSection === "microphone"
                                    actionAccessibleName: root.services.sourceMuted ? "Unmute microphone" : "Mute microphone"
                                    detailAccessibleName: expanded ? "Hide microphone volume" : "Show microphone volume"
                                    stateDescription: subtitle
                                    onBodyClicked: root.toggleNetworkSection("microphone")
                                    onToggled: root.services.toggleMute(true)
                                }

                                NetworkControlCard {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    colors: root.colors
                                    theme: root.theme
                                    icon: !root.services.bluetoothAvailable
                                        ? root.icons.bluetoothOff
                                        : (root.services.bluetoothConnectedCount > 0
                                            ? root.icons.bluetoothConnected
                                            : (root.services.bluetoothPowered ? root.icons.bluetoothOn : root.icons.bluetoothOff))
                                    title: "Bluetooth"
                                    subtitle: NetworkMenuLogic.bluetoothSummary(
                                        root.services.bluetoothAvailable,
                                        root.services.bluetoothPowered,
                                        root.services.bluetoothConnectedCount
                                    )
                                    active: root.services.bluetoothPowered
                                    available: root.services.bluetoothAvailable
                                    detailAvailable: root.services.bluetoothAvailable
                                    expanded: root.expandedNetworkSection === "bluetooth"
                                    actionAccessibleName: root.services.bluetoothPowered ? "Disable Bluetooth" : "Enable Bluetooth"
                                    detailAccessibleName: expanded ? "Hide Bluetooth devices" : "Show Bluetooth devices"
                                    stateDescription: subtitle
                                    onBodyClicked: root.toggleNetworkSection("bluetooth")
                                    onToggled: root.services.bluetoothAdapter.enabled = !root.services.bluetoothAdapter.enabled
                                }
                            }
                        }

                        Item {
                            visible: root.expandedNetworkSection === "microphone"
                            width: parent.width
                            height: root.quickControlHeight

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: root.theme.spacing.space12
                                anchors.rightMargin: root.theme.spacing.space12
                                spacing: root.theme.spacing.space8

                                BarText {
                                    width: root.quickControlIconWidth
                                    anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.services.sourceMuted ? root.icons.microphoneMuted : root.icons.microphone
                                    color: microphoneSlider.enabled ? root.colors.text : root.colors.textMuted
                                    font.pixelSize: 20
                                }

                                QuickControlSlider {
                                    id: microphoneSlider
                                    width: parent.width - root.quickControlIconWidth - parent.spacing
                                    height: 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    value: root.services.sourceVolume
                                    available: root.services.source?.audio !== null
                                        && root.services.source?.audio !== undefined
                                    trackColor: root.colors.background
                                    fillColor: root.colors.primary
                                    handleColor: root.colors.text
                                    handleBorderColor: root.colors.primary
                                    unavailableText: "Microphone unavailable"
                                    onLiveValueRequested: value => root.services.setSourceVolume(value)
                                }
                            }
                        }

                            Item {
                                visible: root.expandedNetworkSection === "bluetooth"
                                width: parent.width
                                height: bluetoothColumn.implicitHeight + root.theme.spacing.space16

                                Column {
                                    id: bluetoothColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: root.theme.spacing.space12
                                    anchors.rightMargin: root.theme.spacing.space12
                                    spacing: root.theme.spacing.space6

                                    BarText {
                                        text: "Bluetooth devices"
                                        color: root.colors.text
                                        font.weight: Font.Medium
                                    }

                                    Repeater {
                                        model: root.services.bluetoothAdapter?.devices?.values?.filter(device => device && (device.paired || device.connected)) ?? []

                                        Item {
                                            required property var modelData
                                            width: bluetoothColumn.width
                                            height: root.detailRowHeight

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: root.theme.spacing.space8
                                                anchors.rightMargin: root.theme.spacing.space8
                                                spacing: root.theme.spacing.space8

                                                BarText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.connected ? root.icons.bluetoothConnected : root.icons.bluetoothOn
                                                    color: modelData.connected ? root.colors.primary : root.colors.textMuted
                                                }

                                                BarText {
                                                    width: parent.width - 80
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.name || modelData.alias || "Bluetooth device"
                                                    color: root.colors.text
                                                    font.weight: modelData.connected ? Font.Medium : Font.Normal
                                                    elide: Text.ElideRight
                                                }

                                                BarText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.connected ? "Connected" : "Paired"
                                                    color: modelData.connected ? root.colors.primary : root.colors.textSubtle
                                                    font.weight: Font.Normal
                                                }
                                            }
                                        }
                                    }

                                    BarText {
                                        visible: (root.services.bluetoothAdapter?.devices?.values?.filter(device => device && (device.paired || device.connected)).length ?? 0) === 0
                                        text: root.services.bluetoothPowered ? "No paired devices" : "Bluetooth is off"
                                        color: root.colors.textSubtle
                                        font.weight: Font.Normal
                                    }
                                }
                            }

                            Rectangle {
                                id: lanCard
                                visible: root.expandedNetworkSection === "ethernet"
                            width: parent.width
                        height: lanColumn.implicitHeight + root.theme.spacing.space24
                        color: root.colors.transparent
                        border.width: 0

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
                                    font.weight: Font.Medium
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
                                color: root.colors.transparent
                                border.width: 0

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
                                            font.weight: Font.Normal
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
                        visible: root.expandedNetworkSection === "wifi"
                        width: parent.width
                        height: wifiColumn.implicitHeight + root.theme.spacing.space24
                        color: root.colors.transparent
                        border.width: 0

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
                                    width: parent.width - root.theme.spacing.space16 - 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: root.theme.spacing.space2

                                    BarText {
                                        text: "Wi-Fi"
                                        color: root.colors.text
                                        font.pixelSize: root.theme.typography.sizeLg
                                        font.weight: Font.Medium
                                    }

                                    BarText {
                                        width: parent.width
                                        text: NetworkMenuLogic.wifiSummary(root.services.connectedWifiNetwork, Networking.wifiHardwareEnabled)
                                        color: root.services.wifiUp ? root.colors.primary : root.colors.textSubtle
                                        font.pixelSize: root.theme.typography.sizeSm
                                        elide: Text.ElideRight
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
                                    color: networkMouse.containsMouse ? root.colors.surfaceHover : root.colors.transparent
                                    border.width: 0

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
                                                font.weight: networkRow.modelData.connected ? Font.Medium : Font.Normal
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
        value: NetworkMenuLogic.shouldScanWifi(
            root.menuOpen,
            root.expandedNetworkSection,
            Networking.wifiEnabled,
            Networking.wifiHardwareEnabled
        )
        when: root.services.wifiDevice !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
