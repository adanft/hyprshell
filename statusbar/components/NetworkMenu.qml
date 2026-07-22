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
    property var suppressedPasswordNetwork: null
    property var wifiScannerDevice: null
    property bool wifiActivationPending: false
    property bool wifiActivationRequested: false
    property int wifiActivationGeneration: 0
    property string connectionError: ""
    readonly property var availableWifiNetworks: Networking.wifiHardwareEnabled
            && Networking.wifiEnabled
            && !wifiActivationPending
            && services.wifiDevice
        ? NetworkMenuLogic.sortedWifiNetworks(services.wifiDevice.networks?.values ?? [])
        : []
    property real uptimeSeconds: 0
    property int quickControlRequestSequence: 0

    function beginWifiActivation() {
        wifiActivationGeneration += 1;
        wifiActivationRequested = true;
        wifiActivationPending = true;
        wifiActivationSettleTimer.activationGeneration = wifiActivationGeneration;
        wifiActivationSettleTimer.restart();
    }

    function toggleWifiEnabled() {
        const enable = !Networking.wifiEnabled;
        if (enable) {
            beginWifiActivation();
        } else {
            wifiActivationGeneration += 1;
            wifiActivationRequested = false;
            wifiActivationPending = false;
            wifiActivationSettleTimer.stop();
        }
        Networking.wifiEnabled = enable;
    }

    function updateWifiScanner(forceRestart) {
        wifiScannerStartTimer.stop();

        const device = services.wifiDevice;
        if (wifiScannerDevice && wifiScannerDevice !== device)
            wifiScannerDevice.scannerEnabled = false;
        wifiScannerDevice = device;
        if (!device)
            return;

        const shouldScan = NetworkMenuLogic.shouldScanWifi(
            menuOpen,
            expandedNetworkSection,
            Networking.wifiEnabled,
            Networking.wifiHardwareEnabled
        );

        if (!shouldScan) {
            if (!wifiActivationRequested) {
                wifiActivationPending = false;
                wifiActivationSettleTimer.stop();
            }
            device.scannerEnabled = false;
            return;
        }

        if (forceRestart) {
            device.scannerEnabled = false;
            wifiScannerStartTimer.restart();
            return;
        }

        device.scannerEnabled = true;
    }

    onMenuOpenChanged: {
        if (NetworkMenuLogic.shouldStopBluetoothScan(menuOpen, expandedNetworkSection, services.bluetoothAdapter?.discovering))
            services.bluetoothAdapter.discovering = false;
        updateWifiScanner(menuOpen);
    }
    onExpandedNetworkSectionChanged: {
        if (NetworkMenuLogic.shouldStopBluetoothScan(menuOpen, expandedNetworkSection, services.bluetoothAdapter?.discovering))
            services.bluetoothAdapter.discovering = false;
        updateWifiScanner(expandedNetworkSection === "wifi");
    }
    property string expandedNetworkSection: ""

    function toggleNetworkSection(section) {
        expandedNetworkSection = NetworkMenuLogic.nextExpandedSection(expandedNetworkSection, section);
        connectionError = "";
        pendingNetwork = null;
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
        if (pendingNetwork?.stateChanging)
            suppressedPasswordNetwork = pendingNetwork;
        menuOpen = false;
        expandedNetworkSection = "";
        pendingNetwork = null;
        connectionError = "";
    }

    function connectNetwork(network) {
        connectionError = "";
        suppressedPasswordNetwork = null;
        if (network.connected) {
            network.disconnect();
            return;
        }
        if (network.known || network.security === WifiSecurityType.None) {
            network.connect();
            return;
        }
        pendingNetwork = network;
    }

    function submitPassword(password) {
        if (!pendingNetwork || password.length === 0 || pendingNetwork.stateChanging)
            return;
        connectionError = "";
        pendingNetwork.connectWithPsk(password);
    }

    function cancelPasswordEntry() {
        if (pendingNetwork?.stateChanging)
            suppressedPasswordNetwork = pendingNetwork;
        pendingNetwork = null;
        connectionError = "";
    }

    function forgetNetwork(network) {
        if (!NetworkMenuLogic.canForgetNetwork(network))
            return;
        if (pendingNetwork === network)
            pendingNetwork = null;
        connectionError = "";
        network.forget();
    }

    function performBluetoothAction(device, action) {
        NetworkMenuLogic.runBluetoothDeviceAction(device, action);
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

    Timer {
        id: wifiScannerStartTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (NetworkMenuLogic.shouldScanWifi(
                    root.menuOpen,
                    root.expandedNetworkSection,
                    Networking.wifiEnabled,
                    Networking.wifiHardwareEnabled
                ) && root.wifiScannerDevice === root.services.wifiDevice) {
                root.wifiScannerDevice.scannerEnabled = true;
                if (root.wifiActivationPending) {
                    wifiActivationSettleTimer.activationGeneration = root.wifiActivationGeneration;
                    wifiActivationSettleTimer.restart();
                }
            } else if (!root.wifiActivationRequested) {
                root.wifiActivationPending = false;
            }
        }
    }

    Timer {
        id: wifiActivationSettleTimer
        property int activationGeneration: 0
        interval: 900
        repeat: false
        onTriggered: {
            if (activationGeneration === root.wifiActivationGeneration) {
                root.wifiActivationRequested = false;
                root.wifiActivationPending = false;
            }
        }
    }

    Connections {
        target: Networking
        ignoreUnknownSignals: true

        function onWifiEnabledChanged() {
            if (root.wifiActivationRequested && !Networking.wifiEnabled)
                return;

            if (Networking.wifiEnabled && !root.wifiActivationRequested) {
                root.beginWifiActivation();
            } else if (!Networking.wifiEnabled) {
                root.wifiActivationPending = false;
                root.cancelPasswordEntry();
                root.suppressedPasswordNetwork = null;
            }

            root.updateWifiScanner(Networking.wifiEnabled);
        }

        function onWifiHardwareEnabledChanged() {
            if (!Networking.wifiHardwareEnabled) {
                root.cancelPasswordEntry();
                root.suppressedPasswordNetwork = null;
            }
            root.updateWifiScanner(Networking.wifiHardwareEnabled);
        }
    }

    Connections {
        target: root.services
        ignoreUnknownSignals: true

        function onWifiDeviceChanged() {
            root.cancelPasswordEntry();
            root.suppressedPasswordNetwork = null;
            root.updateWifiScanner(Networking.wifiEnabled);
        }
    }

    Component.onCompleted: root.updateWifiScanner(false)
    Component.onDestruction: {
        wifiScannerStartTimer.stop();
        wifiActivationSettleTimer.stop();
        if (root.wifiScannerDevice)
            root.wifiScannerDevice.scannerEnabled = false;
        root.wifiScannerDevice = null;
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
                        color: root.colors.surface
                        border.width: 0

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
                                    color: "transparent"
                                    border.width: 0

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
                                            trackHeight: 8
                                            value: root.services.quickVolume?.authoritativePercent ?? 0
                                            available: root.services.quickVolume?.authoritativePercent !== null
                                                && root.services.quickVolume?.authoritativePercent !== undefined
                                                && root.services.quickVolume?.availability !== "unavailable"
                                            trackColor: root.colors.surface
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
                                    color: "transparent"
                                    border.width: 0

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
                                            trackHeight: 8
                                            value: root.services.brightnessLevel
                                            available: root.services.brightnessAvailable
                                            trackColor: root.colors.surface
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
                                    icon: root.services.lanUp
                                        ? root.icons.ethernet
                                        : root.icons.ethernetDisconnected
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
                                    icon: root.services.wifiUp
                                        ? root.icons.wifiConnected
                                        : (Networking.wifiEnabled ? root.icons.wifiEnabled : root.icons.wifiDisconnected)
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
                                    onToggled: root.toggleWifiEnabled()
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
                                    subtitle: NetworkMenuLogic.microphoneSummary(
                                        root.services.microphoneAvailable,
                                        root.services.sourceMuted,
                                        root.services.sourceVolume
                                    )
                                    active: root.services.microphoneAvailable && !root.services.sourceMuted
                                    available: root.services.microphoneAvailable
                                    detailAvailable: true
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
                                    detailAvailable: true
                                    expanded: root.expandedNetworkSection === "bluetooth"
                                    actionAccessibleName: root.services.bluetoothPowered ? "Disable Bluetooth" : "Enable Bluetooth"
                                    detailAccessibleName: expanded ? "Hide Bluetooth devices" : "Show Bluetooth devices"
                                    stateDescription: subtitle
                                    onBodyClicked: root.toggleNetworkSection("bluetooth")
                                        onToggled: {
                                            if (root.services.bluetoothAdapter)
                                                root.services.bluetoothAdapter.enabled = !root.services.bluetoothAdapter.enabled;
                                        }
                                }
                            }
                        }

                        Rectangle {
                            id: microphoneCard
                            visible: root.expandedNetworkSection === "microphone"
                            width: parent.width
                            height: microphoneColumn.implicitHeight + root.theme.spacing.space24
                            color: root.colors.transparent
                            border.width: 0

                            Column {
                                id: microphoneColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space8

                                BarText {
                                    x: root.theme.spacing.space12
                                    width: parent.width - root.theme.spacing.space24
                                    text: "Input volume"
                                    color: root.colors.textSubtle
                                    font.pixelSize: root.theme.typography.sizeMd
                                    font.styleName: root.theme.typography.styleRegular
                                }

                                Rectangle {
                                    width: parent.width
                                    height: root.quickControlHeight
                                    radius: root.theme.shape.radius12
                                    color: root.colors.transparent
                                    border.width: 0

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: root.theme.spacing.space12
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
                                            trackHeight: 8
                                            value: Math.max(0, root.services.sourceVolume)
                                            available: root.services.microphoneAvailable
                                            trackColor: root.colors.surface
                                            fillColor: root.colors.primary
                                            handleColor: root.colors.text
                                            handleBorderColor: root.colors.primary
                                            unavailableText: "Microphone unavailable"
                                            onLiveValueRequested: value => root.services.setSourceVolume(value)
                                        }
                                    }
                                }

                                BarText {
                                    x: root.theme.spacing.space12
                                    width: parent.width - root.theme.spacing.space24
                                    text: "Input devices"
                                    color: root.colors.textSubtle
                                    font.pixelSize: root.theme.typography.sizeMd
                                    font.styleName: root.theme.typography.styleRegular
                                }

                                Repeater {
                                    model: root.services.audioSources ?? []

                                    MicrophoneSourceRow {
                                        required property var modelData
                                        x: root.theme.spacing.space12
                                        width: microphoneColumn.width - root.theme.spacing.space24
                                        source: modelData
                                        active: modelData === root.services.source
                                        colors: root.colors
                                        theme: root.theme
                                        onSelectRequested: source => root.services.selectAudioSource(source)
                                    }
                                }

                                ControlEmptyState {
                                    visible: (root.services.audioSources?.length ?? 0) === 0
                                    x: root.theme.spacing.space12
                                    width: parent.width - root.theme.spacing.space24
                                    colors: root.colors
                                    theme: root.theme
                                    title: root.services.microphoneAvailable
                                        ? "No additional microphone inputs"
                                        : "Microphone unavailable"
                                    description: root.services.microphoneAvailable
                                        ? "The active microphone is already selected"
                                        : "Connect an input device to control it here"
                                }
                            }
                        }

                        Rectangle {
                            id: bluetoothCard
                            visible: root.expandedNetworkSection === "bluetooth"
                            width: parent.width
                            height: bluetoothColumn.implicitHeight + root.theme.spacing.space24
                            color: root.colors.transparent
                            border.width: 0

                            Column {
                                id: bluetoothColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: root.theme.spacing.space12
                                spacing: root.theme.spacing.space8

                                    Row {
                                    width: parent.width
                                    height: root.theme.sizing.statusBarTrayMenuItemHeight

                                    BarText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Bluetooth devices"
                                        color: root.colors.textSubtle
                                        font.pixelSize: root.theme.typography.sizeMd
                                        font.styleName: root.theme.typography.styleRegular
                                    }

                                    BluetoothScanButton {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        colors: root.colors
                                        theme: root.theme
                                        discovering: root.services.bluetoothAdapter?.discovering ?? false
                                        available: root.services.bluetoothPowered
                                        onScanToggled: discovering => {
                                            if (root.services.bluetoothAdapter)
                                                root.services.bluetoothAdapter.discovering = discovering;
                                        }
                                    }
                                }

                                Repeater {
                                    model: NetworkMenuLogic.bluetoothVisibleDevices(
                                        root.services.bluetoothAdapter?.devices?.values ?? [],
                                        root.services.bluetoothAdapter?.discovering ?? false
                                    )

                                    BluetoothDeviceRow {
                                        required property var modelData
                                        width: bluetoothColumn.width
                                        device: modelData
                                        colors: root.colors
                                        theme: root.theme
                                        onPrimaryActionRequested: action => root.performBluetoothAction(modelData, action)
                                        onForgetRequested: modelData.forget()
                                    }
                                }

                                ControlEmptyState {
                                    visible: NetworkMenuLogic.bluetoothVisibleDevices(
                                        root.services.bluetoothAdapter?.devices?.values ?? [],
                                        root.services.bluetoothAdapter?.discovering ?? false
                                    ).length === 0
                                    width: parent.width
                                    colors: root.colors
                                    theme: root.theme
                                    title: NetworkMenuLogic.bluetoothEmptyState(
                                        root.services.bluetoothAvailable,
                                        root.services.bluetoothPowered,
                                        root.services.bluetoothAdapter?.discovering ?? false
                                    )
                                    description: NetworkMenuLogic.bluetoothEmptyDescription(
                                        root.services.bluetoothAvailable,
                                        root.services.bluetoothPowered,
                                        root.services.bluetoothAdapter?.discovering ?? false
                                    )
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

                            BarText {
                                text: "Network info"
                                color: root.colors.textSubtle
                                font.pixelSize: root.theme.typography.sizeMd
                                font.weight: Font.Normal
                            }

                            Rectangle {
                                width: parent.width
                                height: networkInfoColumn.implicitHeight + root.theme.spacing.space16
                                radius: root.theme.shape.radius12
                                color: root.colors.surface
                                border.width: 0

                                Column {
                                    id: networkInfoColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: root.theme.spacing.space8
                                    spacing: root.theme.spacing.space4

                                    BarText {
                                        width: parent.width
                                        text: root.services.lanDevice?.name || "No wired adapter"
                                        color: root.colors.text
                                        font.pixelSize: root.theme.typography.sizeMd
                                        font.weight: Font.Normal
                                        elide: Text.ElideRight
                                    }

                                    BarText {
                                        width: parent.width
                                        text: root.services.lanDevice?.hasLink
                                            ? (root.services.lanUp ? "Connected" : "Cable connected")
                                            : "Cable disconnected"
                                        color: root.services.lanUp ? root.colors.primary : root.colors.textMuted
                                        font.pixelSize: root.theme.typography.sizeSm
                                        font.weight: Font.Normal
                                    }

                                    NetworkInfoRow { label: "Profile"; value: root.services.ethernetInfo.connectionName || ""; colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "IPv4"; value: root.services.ethernetInfo.ipv4Address || ""; colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "Gateway"; value: root.services.ethernetInfo.ipv4Gateway || root.services.ethernetInfo.ipv6Gateway || ""; colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "DNS"; value: [...(root.services.ethernetInfo.ipv4Dns || []), ...(root.services.ethernetInfo.ipv6Dns || [])].join(", "); colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "IPv6"; value: root.services.ethernetInfo.ipv6Address || ""; colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "MAC"; value: root.services.ethernetInfo.macAddress || root.services.lanDevice?.address || ""; colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "Link speed"; value: root.services.lanDevice?.linkSpeed > 0 ? `${root.services.lanDevice.linkSpeed} Mb/s` : ""; colors: root.colors; theme: root.theme }
                                }
                            }

                            Connections {
                                target: root.services.lanDevice?.network ?? null
                                ignoreUnknownSignals: true
                                function onConnectionFailed(reason) {
                                    root.connectionError = `Ethernet: ${ConnectionFailReason.toString(reason)}`;
                                }
                            }

                            BarText {
                                visible: root.connectionError.length > 0 || root.services.ethernetProfileError.length > 0
                                width: parent.width
                                text: root.services.ethernetProfileError || root.connectionError
                                color: root.colors.danger
                                font.pixelSize: root.theme.typography.sizeSm
                                font.weight: Font.Normal
                                wrapMode: Text.Wrap
                            }

                            Rectangle {
                                visible: (root.services.lanDevice?.network?.nmSettings?.length ?? 0) > 0
                                width: parent.width
                                height: root.theme.shape.borderThin
                                color: root.colors.border
                            }

                            BarText {
                                visible: (root.services.lanDevice?.network?.nmSettings?.length ?? 0) > 0
                                text: "Connection profiles"
                                color: root.colors.textSubtle
                                font.pixelSize: root.theme.typography.sizeMd
                                font.weight: Font.Normal
                            }

                            Repeater {
                                model: root.services.lanDevice?.network?.nmSettings ?? []

                                EthernetProfileRow {
                                    required property var modelData
                                    width: lanColumn.width
                                    profile: modelData
                                    active: modelData.uuid === root.services.ethernetInfo.activeUuid
                                    busy: root.services.ethernetProfileBusy
                                    pending: modelData.uuid === root.services.ethernetProfilePendingUuid
                                    colors: root.colors
                                    theme: root.theme
                                    onToggleRequested: profile => root.services.setEthernetProfileEnabled(profile)
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

                                    BarText {
                                        text: "Network info"
                                        color: root.colors.textSubtle
                                        font.pixelSize: root.theme.typography.sizeMd
                                        font.weight: Font.Normal
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: wifiNetworkInfoColumn.implicitHeight + root.theme.spacing.space16
                                        radius: root.theme.shape.radius12
                                        color: root.colors.surface
                                        border.width: 0

                                        Column {
                                            id: wifiNetworkInfoColumn
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.margins: root.theme.spacing.space8
                                            spacing: root.theme.spacing.space4

                                            BarText {
                                                width: parent.width
                                                text: root.services.wifiInterface || "No Wi-Fi adapter"
                                                color: root.colors.text
                                                font.pixelSize: root.theme.typography.sizeMd
                                                font.weight: Font.Normal
                                                elide: Text.ElideRight
                                            }

                                            BarText {
                                                width: parent.width
                                                    text: !Networking.wifiHardwareEnabled
                                                        ? "Unavailable"
                                                        : (root.wifiActivationPending
                                                            ? "Enabling…"
                                                            : (!Networking.wifiEnabled
                                                                ? "Disabled"
                                                                : (root.services.wifiUp ? "Connected" : "Not connected")))
                                                color: root.services.wifiUp ? root.colors.primary : root.colors.textMuted
                                                font.pixelSize: root.theme.typography.sizeSm
                                                font.weight: Font.Normal
                                            }

                                                BarText {
                                                    visible: !root.wifiActivationPending
                                                        && root.services.wifiUp
                                                        && root.services.wifiInfoAvailability !== "available"
                                                    width: parent.width
                                                    text: root.services.wifiInfoAvailability === "unavailable"
                                                        ? "Network details unavailable"
                                                        : "Loading network details…"
                                                    color: root.colors.textSubtle
                                                    font.pixelSize: root.theme.typography.sizeSm
                                                    font.weight: Font.Normal
                                                    wrapMode: Text.WordWrap
                                                }

                                            NetworkInfoRow { label: "Network"; value: root.wifiActivationPending ? "" : (root.services.wifiInfo.connectionName || root.services.connectedWifiNetwork?.name || ""); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "Security"; value: root.wifiActivationPending ? "" : NetworkMenuLogic.wifiSecurityLabel(root.services.connectedWifiNetwork, WifiSecurityType.None); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "Signal quality"; value: root.wifiActivationPending ? "" : NetworkMenuLogic.wifiSignalQualityText(root.services.connectedWifiNetwork); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "IPv4"; value: root.wifiActivationPending ? "" : (root.services.wifiInfo.ipv4Address || ""); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "Gateway"; value: root.wifiActivationPending ? "" : (root.services.wifiInfo.ipv4Gateway || root.services.wifiInfo.ipv6Gateway || ""); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "IPv6"; value: root.wifiActivationPending ? "" : (root.services.wifiInfo.ipv6Address || ""); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "MAC"; value: root.services.wifiInfo.macAddress || root.services.wifiDevice?.address || ""; colors: root.colors; theme: root.theme }
                                        }
                                    }

                                BarText {
                                    visible: root.connectionError.length > 0
                                    width: parent.width
                                    text: root.connectionError
                                    color: root.colors.danger
                                    wrapMode: Text.Wrap
                                }


                            BarText {
                                text: "Available networks"
                                color: root.colors.textSubtle
                                font.pixelSize: root.theme.typography.sizeMd
                                font.weight: Font.Normal
                            }

                                Repeater {
                                    model: root.availableWifiNetworks

                                    WifiNetworkRow {
                                        id: networkRow
                                        required property var modelData
                                        width: wifiColumn.width
                                        network: modelData
                                        colors: root.colors
                                        theme: root.theme
                                        openSecurityValue: WifiSecurityType.None

                                            Connections {
                                                target: networkRow.modelData

                                                function onConnectedChanged() {
                                                    if (networkRow.modelData.connected
                                                            && root.suppressedPasswordNetwork === networkRow.modelData)
                                                        root.suppressedPasswordNetwork = null;
                                                }

                                                function onConnectionFailed(reason) {
                                                if (root.pendingNetwork === networkRow.modelData)
                                                    return;
                                                if (root.suppressedPasswordNetwork === networkRow.modelData) {
                                                    root.suppressedPasswordNetwork = null;
                                                    return;
                                                }
                                                root.connectionError = `${networkRow.modelData.name}: ${ConnectionFailReason.toString(reason)}`;
                                                if (reason === ConnectionFailReason.NoSecrets)
                                                    root.pendingNetwork = networkRow.modelData;
                                            }
                                        }

                                        onPrimaryActionRequested: root.connectNetwork(modelData)
                                        onForgetRequested: root.forgetNetwork(modelData)
                                    }
                                }

                                Rectangle {
                                    visible: root.availableWifiNetworks.length === 0
                                    width: parent.width
                                    height: 58
                                    radius: root.theme.shape.radius12
                                    color: root.colors.surface
                                    border.width: 0

                                    Column {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: root.theme.spacing.space12
                                        spacing: root.theme.spacing.space2

                                        BarText {
                                            width: parent.width
                                            text: !Networking.wifiHardwareEnabled || !root.services.wifiDevice
                                                ? "Wi-Fi unavailable"
                                                : (root.wifiActivationPending
                                                    ? "Enabling Wi-Fi…"
                                                    : (!Networking.wifiEnabled ? "Wi-Fi is disabled" : "No networks found"))
                                            color: root.colors.text
                                            font.pixelSize: root.theme.typography.sizeMd
                                            font.weight: Font.Normal
                                            elide: Text.ElideRight
                                        }

                                        BarText {
                                            width: parent.width
                                            text: !Networking.wifiHardwareEnabled || !root.services.wifiDevice
                                                ? "No wireless adapter is available"
                                                : (root.wifiActivationPending
                                                    ? "Preparing wireless scan"
                                                    : (!Networking.wifiEnabled
                                                        ? "Enable Wi-Fi to scan for networks"
                                                        : "Scanning continues automatically"))
                                            color: root.colors.textSubtle
                                            font.pixelSize: root.theme.typography.sizeSm
                                            font.weight: Font.Normal
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

        Connections {
            target: root.pendingNetwork
            ignoreUnknownSignals: true

            function onConnectedChanged() {
                if (root.pendingNetwork?.connected)
                    root.cancelPasswordEntry();
            }

            function onConnectionFailed(reason) {
                if (!root.pendingNetwork)
                    return;
                root.connectionError = `${root.pendingNetwork.name}: ${ConnectionFailReason.toString(reason)}`;
            }
        }

        WifiPasswordModal {
            screen: root.barWindow.screen
            colors: root.colors
            theme: root.theme
            network: root.pendingNetwork
            errorText: root.connectionError
            onSubmitted: password => root.submitPassword(password)
            onCancelled: root.cancelPasswordEntry()
        }

}
