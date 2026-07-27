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
    required property var colors
    required property var services
    required property var barWindow

    property bool menuOpen: false
    property real menuAnchorX: 0
    property real menuAnchorY: theme.sizing.statusBarOuterHeight
    readonly property var pendingNetwork: networkController.pendingNetwork
    readonly property bool wifiActivationPending: networkController.wifiActivationPending
    readonly property string connectionError: networkController.connectionError
    readonly property string expandedNetworkSection: networkController.expandedNetworkSection
    readonly property bool activeDetail: expandedNetworkSection === "output"
        || expandedNetworkSection === "microphone"
        || expandedNetworkSection === "ethernet"
        || expandedNetworkSection === "wifi"
    readonly property real uptimeSeconds: networkController.uptimeSeconds
    readonly property var availableWifiNetworks: Networking.wifiHardwareEnabled
            && Networking.wifiEnabled && !wifiActivationPending && services.network.wifiDevice
        ? NetworkMenuLogic.sortedWifiNetworks(services.network.wifiDevice.networks?.values ?? []) : []
        property int quickControlRequestSequence: 0
        readonly property var outputQuickVolume: root.services.audio.quickVolume
        readonly property bool outputAvailable: NetworkMenuLogic.outputAvailable(root.services.audio.sink, root.outputQuickVolume)
        readonly property string outputSummary: NetworkMenuLogic.outputSummary(root.outputAvailable, root.services.audio.sinkMuted, root.outputQuickVolume?.authoritativePercent)
        readonly property string outputSinkLabel: NetworkMenuLogic.audioOutputLabel(root.services.audio.sink, "Audio output")
        readonly property string outputIconKind: NetworkMenuLogic.volumeIconKind(root.outputAvailable, root.services.audio.sinkMuted, root.outputQuickVolume?.authoritativePercent)
        readonly property string outputIcon: root.outputIconKind === "unavailable"
            ? root.icons.volumeUnavailable
            : (root.outputIconKind === "muted"
                ? root.icons.volumeMuted
                : (root.outputIconKind === "low"
                    ? root.icons.volumeLow
                    : (root.outputIconKind === "medium" ? root.icons.volumeMedium : root.icons.volumeHigh)))





    NetworkMenuController {
        id: networkController
        networkService: root.services.network; networking: Networking; menuOpen: root.menuOpen
        openSecurityValue: WifiSecurityType.None; noSecretsValue: ConnectionFailReason.NoSecrets
        failureReasonText: reason => ConnectionFailReason.toString(reason)
        uptimeSource: FileView { path: "/proc/uptime"; blockLoading: true; printErrors: false }
        onCloseRequested: root.menuOpen = false
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
        networkController.prepareOpen();
        menuOpen = true;
    }

    function close() { networkController.requestClose(); }

    function clampDetailContentY() {
        detailFlickable.contentY = NetworkMenuLogic.clampDetailContentY(
            root.activeDetail,
            detailFlickable.contentY,
            detailFlickable.contentHeight,
            detailFlickable.height
        );
    }

    onExpandedNetworkSectionChanged: detailFlickable.contentY = 0
    onMenuOpenChanged: {
        if (!menuOpen)
            detailFlickable.contentY = 0;
    }

    FileView {
        id: hostnameFile
        path: "/etc/hostname"
        blockLoading: true
        printErrors: false
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

            width: Math.max(0, Math.min(root.theme.sizing.statusBarNetworkMenuWidth, menuWindow.width - root.theme.spacing.space16))
            height: NetworkMenuLogic.menuCenterHeight(
                menuWindow.height,
                root.theme.spacing.space16,
                360,
                root.theme.spacing.space24,
                fixedShell.implicitHeight,
                root.theme.spacing.space8,
                root.activeDetail,
                detailContent.implicitHeight,
                root.theme.sizing.statusBarNetworkQuickControlHeight
            )
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

            Column {
                id: menuLayout
                anchors.fill: parent
                anchors.margins: root.theme.spacing.space12
                spacing: root.theme.spacing.space8

                Column {
                    id: fixedShell
                    width: parent.width
                    spacing: root.theme.spacing.space8

                    Rectangle {
                        id: userCard
                        width: parent.width
                        height: root.theme.sizing.statusBarNetworkUserCardHeight
                        radius: root.theme.shape.radius12
                        color: root.colors.surface
                        border.width: 0

                        Row {
                            anchors.fill: parent
                            anchors.margins: root.theme.spacing.space12
                            spacing: root.theme.spacing.space12

                            Rectangle {
                                width: root.theme.sizing.statusBarNetworkAvatarSize
                                height: root.theme.sizing.statusBarNetworkAvatarSize
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
                                    font.styleName: root.theme.typography.styleSemibold
                                }

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: root.colors.transparent

                                    Image {
                                        id: avatarImage
                                        anchors.fill: parent
                                        source: root.services.activeUserAvatarSource
                                        visible: status === Image.Ready
                                        asynchronous: true
                                        cache: false
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: root.theme.sizing.statusBarNetworkAvatarSize * 2
                                        sourceSize.height: root.theme.sizing.statusBarNetworkAvatarSize * 2
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: root.colors.transparent
                                    border.color: root.colors.primary
                                    border.width: root.theme.shape.borderMedium
                                }
                            }

                            Column {
                                width: parent.width - root.theme.sizing.statusBarNetworkUserTextReserve
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space2

                                BarText {
                                    width: parent.width
                                    text: root.username
                                    color: root.colors.text
                                    font.family: root.theme.typography.textFontFamily
                                    font.pixelSize: root.theme.typography.sizeLg
                                    font.styleName: root.theme.typography.styleSemibold
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
                                    font.styleName: root.theme.typography.styleRegular
                                }
                            }
                        }
                    }

                        Item {
                            id: quickControlsRow
                            width: parent.width
                            height: root.theme.sizing.statusBarNetworkQuickControlHeight

                            Row {
                                anchors.fill: parent
                                spacing: root.theme.spacing.space8

                                Rectangle {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    radius: root.theme.shape.radius12
                                    color: root.colors.surface
                                    border.width: 0

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: root.theme.spacing.space12
                                        spacing: root.theme.spacing.space8

                                        BarText {
                                            width: root.theme.sizing.statusBarNetworkQuickControlIconWidth
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: Text.AlignHCenter
                                            text: root.outputIcon
                                            color: volumeSlider.enabled ? root.colors.text : root.colors.textMuted
                                            font.family: root.theme.typography.iconFontFamily
                                            font.pixelSize: root.theme.typography.sizeXl
                                            font.styleName: root.theme.typography.styleRegular
                                        }

                                        QuickControlSlider {
                                            id: volumeSlider
                                            width: parent.width - root.theme.sizing.statusBarNetworkQuickControlIconWidth - parent.spacing
                                            height: root.theme.sizing.statusBarNetworkQuickControlSliderHeight
                                            anchors.verticalCenter: parent.verticalCenter
                                            trackHeight: root.theme.sizing.statusBarQuickControlTrackHeight
                                            value: root.outputQuickVolume?.authoritativePercent ?? 0
                                            available: root.outputAvailable
                                            trackColor: root.colors.surface
                                            fillColor: root.colors.primary
                                            handleColor: root.colors.text
                                            handleBorderColor: root.colors.primary
                                            unavailableText: root.services.audio.quickVolume?.errorText || "Volume unavailable"
                                            onLiveValueRequested: value => {
                                                root.quickControlRequestSequence += 1;
                                                root.services.audio.requestSinkVolume(value, root.quickControlRequestSequence);
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    radius: root.theme.shape.radius12
                                    color: root.colors.surface
                                    border.width: 0

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: root.theme.spacing.space12
                                        spacing: root.theme.spacing.space8

                                        BarText {
                                            width: root.theme.sizing.statusBarNetworkQuickControlIconWidth
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: Text.AlignHCenter
                                            text: root.icons.brightnessControl
                                            color: brightnessSlider.enabled ? root.colors.text : root.colors.textMuted
                                            font.family: root.theme.typography.iconFontFamily
                                            font.pixelSize: root.theme.typography.sizeXl
                                            font.styleName: root.theme.typography.styleRegular
                                        }

                                        QuickControlSlider {
                                            id: brightnessSlider
                                            width: parent.width - root.theme.sizing.statusBarNetworkQuickControlIconWidth - parent.spacing
                                            height: root.theme.sizing.statusBarNetworkQuickControlSliderHeight
                                            anchors.verticalCenter: parent.verticalCenter
                                            trackHeight: root.theme.sizing.statusBarQuickControlTrackHeight
                                            value: root.services.brightness.brightnessLevel
                                            available: root.services.brightness.brightnessAvailable
                                            trackColor: root.colors.surface
                                            fillColor: root.colors.primary
                                            handleColor: root.colors.text
                                            handleBorderColor: root.colors.primary
                                            unavailableText: "Brightness unavailable"
                                            onLiveValueRequested: value => root.services.brightness.setBrightness(value)
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            id: networkControlsRow
                            width: parent.width
                            height: root.theme.sizing.statusBarNetworkQuickControlHeight

                            Row {
                                anchors.fill: parent
                                spacing: root.theme.spacing.space8

                                NetworkControlCard {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    colors: root.colors
                                    theme: root.theme
                                    icon: root.services.network.lanUp
                                        ? root.icons.ethernet
                                        : root.icons.ethernetDisconnected
                                    title: "Ethernet"
                                    subtitle: root.services.network.lanUp
                                        ? "Connected"
                                        : (root.services.network.lanDevice?.hasLink ? "Disconnected" : "Cable unplugged")
                                    active: root.services.network.lanUp
                                    available: root.services.network.lanDevice?.network !== null
                                        && root.services.network.lanDevice?.network !== undefined
                                    busy: root.services.network.lanDevice?.network?.stateChanging ?? false
                                    expanded: root.expandedNetworkSection === "ethernet"
                                    onBodyClicked: networkController.toggleNetworkSection("ethernet")
                                    onToggled: networkController.toggleEthernet()
                                }

                                NetworkControlCard {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    colors: root.colors
                                    theme: root.theme
                                    icon: root.services.network.wifiUp
                                        ? root.icons.wifiConnected
                                        : (Networking.wifiEnabled ? root.icons.wifiEnabled : root.icons.wifiDisconnected)
                                    title: "Wi-Fi"
                                    subtitle: !Networking.wifiHardwareEnabled
                                        ? "Unavailable"
                                        : (!Networking.wifiEnabled
                                            ? "Disabled"
                                            : NetworkMenuLogic.wifiSummary(root.services.network.connectedWifiNetwork, true))
                                    active: Networking.wifiEnabled
                                    available: Networking.wifiHardwareEnabled
                                    expanded: root.expandedNetworkSection === "wifi"
                                    onBodyClicked: networkController.toggleNetworkSection("wifi")
                                    onToggled: networkController.toggleWifiEnabled()
                                }
                            }
                        }

                        Item {
                            id: audioControlsRow
                            width: parent.width
                            height: root.theme.sizing.statusBarNetworkQuickControlHeight

                            Row {
                                anchors.fill: parent
                                spacing: root.theme.spacing.space8

                                NetworkControlCard {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    colors: root.colors
                                    theme: root.theme
                                    icon: root.outputIcon
                                    title: root.outputSinkLabel
                                    subtitle: root.outputSummary
                                    active: root.outputAvailable && !root.services.audio.sinkMuted
                                        && (root.outputQuickVolume?.authoritativePercent ?? 0) > 0
                                    available: root.outputAvailable
                                    detailAvailable: true
                                    expanded: root.expandedNetworkSection === "output"
                                    actionAccessibleName: root.services.audio.sinkMuted ? "Unmute output" : "Mute output"
                                    detailAccessibleName: expanded ? "Hide output volume" : "Show output volume"
                                    stateDescription: subtitle
                                    onBodyClicked: networkController.toggleNetworkSection("output")
                                    onToggled: root.services.audio.toggleMute(false)
                                }

                                NetworkControlCard {
                                    width: (parent.width - parent.spacing) / 2
                                    height: parent.height
                                    colors: root.colors
                                    theme: root.theme
                                    icon: root.services.audio.sourceMuted ? root.icons.microphoneMuted : root.icons.microphone
                                    title: NetworkMenuLogic.audioSourceLabel(root.services.audio.source, "Microphone")
                                    subtitle: NetworkMenuLogic.microphoneSummary(
                                        root.services.audio.microphoneAvailable,
                                        root.services.audio.sourceMuted,
                                        root.services.audio.sourceVolume
                                    )
                                    active: root.services.audio.microphoneAvailable && !root.services.audio.sourceMuted
                                    available: root.services.audio.microphoneAvailable
                                    detailAvailable: true
                                    expanded: root.expandedNetworkSection === "microphone"
                                    actionAccessibleName: root.services.audio.sourceMuted ? "Unmute microphone" : "Mute microphone"
                                    detailAccessibleName: expanded ? "Hide microphone volume" : "Show microphone volume"
                                    stateDescription: subtitle
                                    onBodyClicked: networkController.toggleNetworkSection("microphone")
                                    onToggled: root.services.audio.toggleMute(true)
                                }
                            }
                        }

                        NetworkControlCard {
                            id: bluetoothCard
                            width: (parent.width - root.theme.spacing.space8) / 2
                            height: root.theme.sizing.statusBarNetworkQuickControlHeight
                            colors: root.colors
                            theme: root.theme
                            icon: !root.services.bluetooth.bluetoothAvailable
                                ? root.icons.bluetoothOff
                                : (root.services.bluetooth.bluetoothConnectedCount > 0
                                    ? root.icons.bluetoothConnected
                                    : (root.services.bluetooth.bluetoothPowered ? root.icons.bluetoothOn : root.icons.bluetoothOff))
                            title: "Bluetooth"
                            subtitle: NetworkMenuLogic.bluetoothSummary(
                                root.services.bluetooth.bluetoothAvailable,
                                root.services.bluetooth.bluetoothPowered,
                                root.services.bluetooth.bluetoothConnectedCount
                            )
                            active: root.services.bluetooth.bluetoothPowered
                            available: root.services.bluetooth.bluetoothAvailable
                            actionAccessibleName: root.services.bluetooth.bluetoothPowered ? "Disable Bluetooth" : "Enable Bluetooth"
                            stateDescription: subtitle
                            onToggled: {
                                if (root.services.bluetooth.bluetoothAdapter)
                                    root.services.bluetooth.bluetoothAdapter.enabled = !root.services.bluetooth.bluetoothAdapter.enabled;
                            }
                        }

                }

                Flickable {
                    id: detailFlickable
                    width: parent.width
                    height: NetworkMenuLogic.detailViewportHeight(
                        root.activeDetail,
                        detailContent.implicitHeight,
                        menuContainer.height - root.theme.spacing.space24
                            - fixedShell.implicitHeight
                            - (root.activeDetail ? root.theme.spacing.space8 : 0),
                        root.theme.sizing.statusBarNetworkQuickControlHeight
                    )
                    visible: root.activeDetail && height > 0
                    contentWidth: width
                    contentHeight: detailContent.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    interactive: root.activeDetail && height > 0 && contentHeight > height
                    onContentHeightChanged: root.clampDetailContentY()
                    onHeightChanged: root.clampDetailContentY()
                    Component.onCompleted: root.clampDetailContentY()

                    Controls.ScrollBar.vertical: Controls.ScrollBar {
                        policy: root.activeDetail && detailFlickable.height > 0
                                && detailFlickable.contentHeight > detailFlickable.height
                            ? Controls.ScrollBar.AlwaysOn
                            : Controls.ScrollBar.AlwaysOff
                    }

                    Column {
                        id: detailContent
                        width: detailFlickable.width

                        Rectangle {
                            id: outputCard
                            visible: root.expandedNetworkSection === "output"
                            width: parent.width
                            height: outputColumn.implicitHeight + root.theme.spacing.space24
                            color: root.colors.transparent
                            border.width: 0

                            Column {
                                id: outputColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space8

                                AudioMixerSection {
                                    id: audioMixerSection
                                    width: parent.width
                                    audio: root.services.audio
                                    colors: root.colors
                                    theme: root.theme
                                    icons: root.icons
                                    outputQuickVolume: root.outputQuickVolume
                                    outputAvailable: root.outputAvailable
                                    outputIcon: root.outputIcon
                                    onMasterVolumeRequested: value => {
                                        root.quickControlRequestSequence += 1;
                                        root.services.audio.requestSinkVolume(value, root.quickControlRequestSequence);
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
                                    height: root.theme.sizing.statusBarNetworkQuickControlHeight
                                    radius: root.theme.shape.radius12
                                    color: root.colors.transparent
                                    border.width: 0

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: root.theme.spacing.space12
                                        spacing: root.theme.spacing.space8

                                        BarText {
                                            width: root.theme.sizing.statusBarNetworkQuickControlIconWidth
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: Text.AlignHCenter
                                            text: root.services.audio.sourceMuted ? root.icons.microphoneMuted : root.icons.microphone
                                            color: microphoneSlider.enabled ? root.colors.text : root.colors.textMuted
                                            font.family: root.theme.typography.iconFontFamily
                                            font.pixelSize: root.theme.typography.sizeXl
                                            font.styleName: root.theme.typography.styleRegular
                                        }

                                        QuickControlSlider {
                                            id: microphoneSlider
                                            width: parent.width - root.theme.sizing.statusBarNetworkQuickControlIconWidth - parent.spacing
                                            height: root.theme.sizing.statusBarNetworkQuickControlSliderHeight
                                            anchors.verticalCenter: parent.verticalCenter
                                            trackHeight: root.theme.sizing.statusBarQuickControlTrackHeight
                                            value: Math.max(0, root.services.audio.sourceVolume)
                                            available: root.services.audio.microphoneAvailable
                                            trackColor: root.colors.surface
                                            fillColor: root.colors.primary
                                            handleColor: root.colors.text
                                            handleBorderColor: root.colors.primary
                                            unavailableText: "Microphone unavailable"
                                            onLiveValueRequested: value => root.services.audio.setSourceVolume(value)
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

                                    Column {
                                        id: microphoneDevicesSection
                                        x: root.theme.spacing.space12
                                        width: parent.width - root.theme.spacing.space24
                                        spacing: root.theme.spacing.space8

                                        Repeater {
                                            model: root.services.audio.audioSources ?? []

                                            MicrophoneSourceRow {
                                                required property var modelData
                                                width: microphoneDevicesSection.width
                                                source: modelData
                                                icon: root.services.audio.sourceMuted
                                                    ? root.icons.microphoneMuted
                                                    : root.icons.microphone
                                                active: modelData === root.services.audio.source
                                                colors: root.colors
                                                theme: root.theme
                                                onSelectRequested: source => root.services.audio.selectAudioSource(source)
                                            }
                                        }

                                        ControlEmptyState {
                                    visible: (root.services.audio.audioSources?.length ?? 0) === 0
                                    width: parent.width
                                    colors: root.colors
                                    theme: root.theme
                                    title: root.services.audio.microphoneAvailable
                                        ? "No additional microphone inputs"
                                        : "Microphone unavailable"
                                    description: root.services.audio.microphoneAvailable
                                        ? "The active microphone is already selected"
                                        : "Connect an input device to control it here"
                                    }
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
                                font.styleName: root.theme.typography.styleRegular
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
                                        text: root.services.network.lanDevice?.name || "No wired adapter"
                                        color: root.colors.text
                                        font.pixelSize: root.theme.typography.sizeMd
                                        font.styleName: root.theme.typography.styleRegular
                                        elide: Text.ElideRight
                                    }

                                    BarText {
                                        width: parent.width
                                        text: root.services.network.lanDevice?.hasLink
                                            ? (root.services.network.lanUp ? "Connected" : "Cable connected")
                                            : "Cable disconnected"
                                        color: root.services.network.lanUp ? root.colors.primary : root.colors.textMuted
                                        font.pixelSize: root.theme.typography.sizeSm
                                        font.styleName: root.theme.typography.styleRegular
                                    }

                                    NetworkInfoRow { label: "Profile"; value: root.services.network.ethernetInfo.connectionName || ""; colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "IPv4"; value: root.services.network.ethernetInfo.ipv4Address || ""; colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "Gateway"; value: root.services.network.ethernetInfo.ipv4Gateway || root.services.network.ethernetInfo.ipv6Gateway || ""; colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "DNS"; value: [...(root.services.network.ethernetInfo.ipv4Dns || []), ...(root.services.network.ethernetInfo.ipv6Dns || [])].join(", "); colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "IPv6"; value: root.services.network.ethernetInfo.ipv6Address || ""; colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "MAC"; value: root.services.network.ethernetInfo.macAddress || root.services.network.lanDevice?.address || ""; colors: root.colors; theme: root.theme }
                                    NetworkInfoRow { label: "Link speed"; value: root.services.network.lanDevice?.linkSpeed > 0 ? `${root.services.network.lanDevice.linkSpeed} Mb/s` : ""; colors: root.colors; theme: root.theme }
                                }
                            }

                            BarText {
                                visible: root.connectionError.length > 0 || root.services.network.ethernetProfileError.length > 0
                                width: parent.width
                                text: root.services.network.ethernetProfileError || root.connectionError
                                color: root.colors.danger
                                font.pixelSize: root.theme.typography.sizeSm
                                font.styleName: root.theme.typography.styleRegular
                                wrapMode: Text.Wrap
                            }

                            Rectangle {
                                visible: (root.services.network.lanDevice?.network?.nmSettings?.length ?? 0) > 0
                                width: parent.width
                                height: root.theme.shape.borderThin
                                color: root.colors.border
                            }

                            BarText {
                                visible: (root.services.network.lanDevice?.network?.nmSettings?.length ?? 0) > 0
                                text: "Connection profiles"
                                color: root.colors.textSubtle
                                font.pixelSize: root.theme.typography.sizeMd
                                font.styleName: root.theme.typography.styleRegular
                            }

                            Repeater {
                                model: root.services.network.lanDevice?.network?.nmSettings ?? []

                                EthernetProfileRow {
                                    required property var modelData
                                    width: lanColumn.width
                                    profile: modelData
                                    active: modelData.uuid === root.services.network.ethernetInfo.activeUuid
                                    busy: root.services.network.ethernetProfileBusy
                                    pending: modelData.uuid === root.services.network.ethernetProfilePendingUuid
                                    colors: root.colors
                                    theme: root.theme
                                    onToggleRequested: profile => root.services.network.setEthernetProfileEnabled(profile)
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
                                        font.styleName: root.theme.typography.styleRegular
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
                                                text: root.services.network.wifiInterface || "No Wi-Fi adapter"
                                                color: root.colors.text
                                                font.pixelSize: root.theme.typography.sizeMd
                                                font.styleName: root.theme.typography.styleRegular
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
                                                                : (root.services.network.wifiUp ? "Connected" : "Not connected")))
                                                color: root.services.network.wifiUp ? root.colors.primary : root.colors.textMuted
                                                font.pixelSize: root.theme.typography.sizeSm
                                                font.styleName: root.theme.typography.styleRegular
                                            }

                                                BarText {
                                                    visible: !root.wifiActivationPending
                                                        && root.services.network.wifiUp
                                                        && root.services.network.wifiInfoAvailability !== "available"
                                                    width: parent.width
                                                    text: root.services.network.wifiInfoAvailability === "unavailable"
                                                        ? "Network details unavailable"
                                                        : "Loading network details…"
                                                    color: root.colors.textSubtle
                                                    font.pixelSize: root.theme.typography.sizeSm
                                                    font.styleName: root.theme.typography.styleRegular
                                                    wrapMode: Text.WordWrap
                                                }

                                            NetworkInfoRow { label: "Network"; value: root.wifiActivationPending ? "" : (root.services.network.wifiInfo.connectionName || root.services.network.connectedWifiNetwork?.name || ""); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "Security"; value: root.wifiActivationPending ? "" : NetworkMenuLogic.wifiSecurityLabel(root.services.network.connectedWifiNetwork, WifiSecurityType.None); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "Signal quality"; value: root.wifiActivationPending ? "" : NetworkMenuLogic.wifiSignalQualityText(root.services.network.connectedWifiNetwork); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "IPv4"; value: root.wifiActivationPending ? "" : (root.services.network.wifiInfo.ipv4Address || ""); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "Gateway"; value: root.wifiActivationPending ? "" : (root.services.network.wifiInfo.ipv4Gateway || root.services.network.wifiInfo.ipv6Gateway || ""); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "IPv6"; value: root.wifiActivationPending ? "" : (root.services.network.wifiInfo.ipv6Address || ""); colors: root.colors; theme: root.theme }
                                            NetworkInfoRow { label: "MAC"; value: root.services.network.wifiInfo.macAddress || root.services.network.wifiDevice?.address || ""; colors: root.colors; theme: root.theme }
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
                                font.styleName: root.theme.typography.styleRegular
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

                                            Connections { target: networkRow.modelData
                                                function onConnectedChanged() { networkController.handleWifiNetworkConnectedChanged(networkRow.modelData); }
                                                function onConnectionFailed(reason) { networkController.handleWifiNetworkConnectionFailed(networkRow.modelData, reason); }
                                            }

                                        onPrimaryActionRequested: networkController.connectNetwork(modelData)
                                        onForgetRequested: networkController.forgetNetwork(modelData)
                                    }
                                }

                                Rectangle {
                                    visible: root.availableWifiNetworks.length === 0
                                    width: parent.width
                                    height: root.theme.sizing.statusBarControlEmptyStateHeight
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
                                            text: !Networking.wifiHardwareEnabled || !root.services.network.wifiDevice
                                                ? "Wi-Fi unavailable"
                                                : (root.wifiActivationPending
                                                    ? "Enabling Wi-Fi…"
                                                    : (!Networking.wifiEnabled ? "Wi-Fi is disabled" : "No networks found"))
                                            color: root.colors.text
                                            font.pixelSize: root.theme.typography.sizeMd
                                            font.styleName: root.theme.typography.styleRegular
                                            elide: Text.ElideRight
                                        }

                                        BarText {
                                            width: parent.width
                                            text: !Networking.wifiHardwareEnabled || !root.services.network.wifiDevice
                                                ? "No wireless adapter is available"
                                                : (root.wifiActivationPending
                                                    ? "Preparing wireless scan"
                                                    : (!Networking.wifiEnabled
                                                        ? "Enable Wi-Fi to scan for networks"
                                                        : "Scanning continues automatically"))
                                            color: root.colors.textSubtle
                                            font.pixelSize: root.theme.typography.sizeSm
                                            font.styleName: root.theme.typography.styleRegular
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

    }

        WifiPasswordModal {
            screen: root.barWindow.screen
            colors: root.colors
            theme: root.theme
            network: root.pendingNetwork
            errorText: root.connectionError
            onSubmitted: password => networkController.submitPassword(password)
            onCancelled: networkController.cancelPasswordEntry()
        }

}
