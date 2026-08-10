import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import Quickshell.Widgets
import "../../theme"
import "components"
import "ControlCenter.js" as ControlCenterLogic
import "../../shared/components"

Item {
    id: root

    readonly property var theme: AppTheme
    readonly property var icons: Icons
    readonly property string username: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "User"
    readonly property string hostname: ControlCenterLogic.hostnameOrFallback(hostnameFile.loaded ? hostnameFile.text() :
                                                                                                 "")
    readonly property string userInitial: ControlCenterLogic.userInitial(username)
    required property var services
    required property var barWindow

    property bool menuOpen: false
    property real menuAnchorX: 0
    property real menuAnchorY: theme.sizing.statusBarSurfaceTopOffset
    readonly property var pendingNetwork: controlCenterController.pendingNetwork
    readonly property bool wifiActivationPending: controlCenterController.wifiActivationPending
    readonly property string connectionError: controlCenterController.connectionError
    readonly property string expandedNetworkSection: controlCenterController.expandedNetworkSection
    readonly property bool activeDetail: expandedNetworkSection === "output" || expandedNetworkSection === "microphone"
                                         || expandedNetworkSection === "ethernet" || expandedNetworkSection === "wifi"
                                         || expandedNetworkSection === "bluetooth"
    readonly property real uptimeSeconds: controlCenterController.uptimeSeconds
    readonly property bool hasEthernetProfiles: (services.network.lanDevice?.network?.nmSettings?.length ?? 0) > 0
    readonly property bool scanningBluetooth: services.bluetooth.bluetoothDiscovering
    readonly property bool wifiUsable: Networking.wifiHardwareEnabled && Boolean(services.network.wifiDevice)
    readonly property string wifiEmptyTitle: !wifiUsable ? "Wi-Fi unavailable"
                                                         : (wifiActivationPending ? "Enabling Wi-Fi…"
                                                                                  : (!Networking.wifiEnabled
                                                                                     ? "Wi-Fi is disabled"
                                                                                     : "No networks found"))
    readonly property string wifiEmptyDescription: !wifiUsable ? "No wireless adapter is available"
                                                              : (wifiActivationPending ? "Preparing wireless scan"
                                                                                       : (!Networking.wifiEnabled
                                                                                          ? "Enable Wi-Fi to scan for networks"
                                                                                          : "Scanning continues automatically"))
    readonly property var availableWifiNetworks: Networking.wifiHardwareEnabled && Networking.wifiEnabled &&
                                                 !wifiActivationPending && services.network.wifiDevice
                                                 ? ControlCenterLogic.sortedWifiNetworks(
                                                       services.network.wifiDevice.networks?.values ?? []) : []
    property int quickControlRequestSequence: 0
    readonly property var outputQuickVolume: root.services.audio.quickVolume
    readonly property bool outputAvailable: ControlCenterLogic.outputAvailable(root.services.audio.sink,
                                                                             root.outputQuickVolume)
    readonly property string outputSummary: ControlCenterLogic.outputSummary(root.outputAvailable,
                                                                           root.services.audio.sinkMuted,
                                                                           root.outputQuickVolume?.authoritativePercent)
    readonly property string outputSinkLabel: ControlCenterLogic.audioOutputLabel(root.services.audio.sink,
                                                                                "Audio output")
    readonly property string outputIconKind: ControlCenterLogic.volumeIconKind(root.outputAvailable,
                                                                             root.services.audio.sinkMuted,
                                                                             root.outputQuickVolume
                                                                             ?.authoritativePercent)
    readonly property string outputIcon: root.outputIconKind === "unavailable" ? root.icons.volumeUnavailable : (root.outputIconKind
                                                                                                                 === "muted"
                                                                                                                 ? root.icons.volumeMuted :
                                                                                                                   (root.outputIconKind
                                                                                                                    === "low"
                                                                                                                    ? root.icons.volumeLow :
                                                                                                                      (root.outputIconKind
                                                                                                                       === "medium"
                                                                                                                       ? root.icons.volumeMedium :
                                                                                                                         root.icons.volumeHigh)))

    ControlCenterController {
        id: controlCenterController
        networkService: root.services.network
        networking: Networking
        menuOpen: root.menuOpen
        openSecurityValue: WifiSecurityType.None
        noSecretsValue: ConnectionFailReason.NoSecrets
        failureReasonText: reason => ConnectionFailReason.toString(reason)
        uptimeSource: FileView {
            path: "/proc/uptime"
            blockLoading: true
            printErrors: false
        }
        onCloseRequested: root.menuOpen = false
    }

    function toggle(anchorItem) {
        if (menuOpen) {
            close()
            return
        }
        open(anchorItem)
    }

    // section is the panel to arrive expanded on, or "" to open as it was left.
    // A status bar module passes its own, so clicking the speaker lands on the
    // volume controls rather than on whatever was open last time.
    function open(anchorItem, section) {
        controlCenterController.expandNetworkSection(section || "")
        if (anchorItem) {
            // Only x follows the module that was clicked. The top edge comes
            // from the bar, not from the module, so the panel no longer shifts
            // vertically depending on which module opened it.
            const globalPosition = anchorItem.mapToGlobal(anchorItem.width / 2, 0)
            const screenX = barWindow.screen ? (barWindow.screen.x || 0) : 0
            menuAnchorX = globalPosition.x - screenX
            menuAnchorY = theme.sizing.statusBarSurfaceTopOffset
        }
        controlCenterController.prepareOpen()
        menuOpen = true
    }

    function close() {
        stopBluetoothScan()
        controlCenterController.requestClose()
    }

    function startBluetoothScan() {
        if (!root.services.bluetooth.bluetoothPowered)
            return
        root.services.bluetooth.setBluetoothScanning(true)
        bluetoothScanTimer.restart()
    }

    function stopBluetoothScan() {
        bluetoothScanTimer.stop()
        root.services.bluetooth.setBluetoothScanning(false)
    }

    function toggleBluetoothScan() {
        if (root.scanningBluetooth)
            stopBluetoothScan()
        else
            startBluetoothScan()
    }

    Timer {
        id: bluetoothScanTimer
        interval: 25000
        repeat: false
        onTriggered: root.stopBluetoothScan()
    }

    function clampDetailContentY() {
        detailFlickable.contentY = ControlCenterLogic.clampDetailContentY(root.activeDetail, detailFlickable.contentY,
                                                                        detailFlickable.contentHeight,
                                                                        detailFlickable.height)
    }

    onExpandedNetworkSectionChanged: {
        detailFlickable.contentY = 0
        if (menuOpen && expandedNetworkSection === "bluetooth")
            startBluetoothScan()
        else
            stopBluetoothScan()
    }
    onMenuOpenChanged: {
        if (!menuOpen) {
            detailFlickable.contentY = 0
            stopBluetoothScan()
        } else if (expandedNetworkSection === "bluetooth") {
            startBluetoothScan()
        }
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
        color: "transparent"
        // Without keyboard focus the Escape shortcut below and the Keys
        // handlers on the rows never receive an event. OnDemand rather than
        // Exclusive: this is a menu, not a modal, so it must not lock the
        // keyboard away from the focused application.
        focusable: true
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "qs-statusbar-control-center"

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

            width: Math.max(0, Math.min(root.theme.sizing.statusBarControlCenterWidth, menuWindow.width
                                        - root.theme.spacing.space16))
            height: ControlCenterLogic.menuCenterHeight(menuWindow.height, root.theme.spacing.space16, 360,
                                                      root.theme.spacing.space24, fixedShell.implicitHeight,
                                                      root.theme.spacing.space8, root.activeDetail,
                                                      detailContent.implicitHeight,
                                                      root.theme.sizing.statusBarNetworkQuickControlHeight)
            x: Math.max(root.theme.spacing.space8, Math.min(menuWindow.width - width - root.theme.spacing.space8, root.menuAnchorX
                                                            - width / 2))
            y: Math.max(root.theme.spacing.space8, Math.min(menuWindow.height - height - root.theme.spacing.space8,
                                                            root.menuAnchorY))
            radius: root.theme.shape.radius16
            color: Colors.shadow
            border.color: Colors.outline
            border.width: root.theme.shape.borderThin

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            }

            Column {
                id: menuLayout
                anchors.fill: parent
                anchors.margins: root.theme.spacing.space12
                spacing: root.theme.spacing.space6

                Column {
                    id: fixedShell
                    width: parent.width
                    spacing: root.theme.spacing.space6

                    Rectangle {
                        id: userCard
                        width: parent.width
                        height: root.theme.sizing.statusBarNetworkUserCardHeight
                        radius: root.theme.shape.radius12
                        color: Colors.surface
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
                                color: Colors.primary

                                AppText {
                                    anchors.centerIn: parent
                                    text: root.userInitial
                                    visible: avatarImage.status !== Image.Ready
                                    color: Colors.shadow
                                    font.family: root.theme.typography.textFontFamily
                                    font.pixelSize: root.theme.typography.actionIconFontSize
                                    font.styleName: root.theme.typography.styleSemibold
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
                                        sourceSize.width: root.theme.sizing.statusBarNetworkAvatarSize * 2
                                        sourceSize.height: root.theme.sizing.statusBarNetworkAvatarSize * 2
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: Colors.primary
                                    border.width: root.theme.shape.borderMedium
                                }
                            }

                            Column {
                                width: parent.width - root.theme.sizing.statusBarNetworkUserTextReserve
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space2

                                AppText {
                                    width: parent.width
                                    text: root.username
                                    color: Colors.on_surface
                                    font.family: root.theme.typography.textFontFamily
                                    font.pixelSize: root.theme.typography.sizeLg
                                    font.styleName: root.theme.typography.styleSemibold
                                    elide: Text.ElideRight
                                }

                                AppText {
                                    text: {
                                        const totalMinutes = Math.floor(Math.max(0, root.uptimeSeconds) / 60)
                                        const days = Math.floor(totalMinutes / 1440)
                                        const hours = Math.floor((totalMinutes % 1440) / 60)
                                        const minutes = totalMinutes % 60
                                        return `up ${days} days, ${hours} hours, ${minutes} minutes`
                                    }
                                    color: Colors.on_surface_variant
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
                            spacing: root.theme.spacing.space6

                            // No card behind the quick controls: the slider track is
                            // the only thing here that carries a surface.
                            Item {
                                width: (parent.width - parent.spacing) / 2
                                height: parent.height

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: root.theme.spacing.space12
                                    spacing: root.theme.spacing.space6

                                    AppText {
                                        width: root.theme.sizing.statusBarNetworkQuickControlIconWidth
                                        anchors.verticalCenter: parent.verticalCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.outputIcon
                                        color: volumeSlider.enabled ? Colors.on_surface : Colors.on_surface_variant
                                        font.family: root.theme.typography.iconFontFamily
                                        font.pixelSize: root.theme.typography.sizeXl
                                        font.styleName: root.theme.typography.styleRegular
                                    }

                                    QuickControlSlider {
                                        id: volumeSlider
                                        theme: root.theme
                                        width: parent.width - root.theme.sizing.statusBarNetworkQuickControlIconWidth
                                               - parent.spacing
                                        height: root.theme.sizing.statusBarNetworkQuickControlSliderHeight
                                        anchors.verticalCenter: parent.verticalCenter
                                        trackHeight: root.theme.sizing.statusBarQuickControlTrackHeight
                                        value: root.outputQuickVolume?.authoritativePercent ?? 0
                                        available: root.outputAvailable
                                        trackColor: Colors.surface_variant
                                        fillColor: Colors.primary
                                        handleColor: Colors.on_surface
                                        handleBorderColor: Colors.primary
                                        unavailableText: root.services.audio.quickVolume?.errorText
                                                         || "Volume unavailable"
                                        onLiveValueRequested: value => {
                                            root.quickControlRequestSequence += 1
                                            root.services.audio.requestSinkVolume(value,
                                                                                  root.quickControlRequestSequence)
                                        }
                                    }
                                }
                            }

                            // No card behind the quick controls: the slider track is
                            // the only thing here that carries a surface.
                            Item {
                                width: (parent.width - parent.spacing) / 2
                                height: parent.height

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: root.theme.spacing.space12
                                    spacing: root.theme.spacing.space6

                                    AppText {
                                        width: root.theme.sizing.statusBarNetworkQuickControlIconWidth
                                        anchors.verticalCenter: parent.verticalCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.icons.brightnessControl
                                        color: brightnessSlider.enabled ? Colors.on_surface : Colors.on_surface_variant
                                        font.family: root.theme.typography.iconFontFamily
                                        font.pixelSize: root.theme.typography.sizeXl
                                        font.styleName: root.theme.typography.styleRegular
                                    }

                                    QuickControlSlider {
                                        id: brightnessSlider
                                        theme: root.theme
                                        width: parent.width - root.theme.sizing.statusBarNetworkQuickControlIconWidth
                                               - parent.spacing
                                        height: root.theme.sizing.statusBarNetworkQuickControlSliderHeight
                                        anchors.verticalCenter: parent.verticalCenter
                                        trackHeight: root.theme.sizing.statusBarQuickControlTrackHeight
                                        value: root.services.brightness.brightnessLevel
                                        available: root.services.brightness.brightnessAvailable
                                        trackColor: Colors.surface_variant
                                        fillColor: Colors.primary
                                        handleColor: Colors.on_surface
                                        handleBorderColor: Colors.primary
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
                            spacing: root.theme.spacing.space6

                            NetworkControlCard {
                                width: (parent.width - parent.spacing) / 2
                                height: parent.height
                                theme: root.theme
                                icon: root.services.network.lanUp ? root.icons.ethernet :
                                                                    root.icons.ethernetDisconnected

                                title: "Ethernet"
                                subtitle: root.services.network.lanUp ? "Connected" : (root.services.network.lanDevice
                                                                                       ?.hasLink ? "Disconnected" :
                                                                                                   "Cable unplugged")
                                active: root.services.network.lanUp
                                available: root.services.network.lanDevice?.network !== null && root.services.network.lanDevice
                                           ?.network !== undefined
                                busy: root.services.network.lanDevice?.network?.stateChanging ?? false
                                expanded: root.expandedNetworkSection === "ethernet"
                                onBodyClicked: controlCenterController.toggleNetworkSection("ethernet")
                                onToggled: controlCenterController.toggleEthernet()
                            }

                            NetworkControlCard {
                                width: (parent.width - parent.spacing) / 2
                                height: parent.height
                                theme: root.theme
                                icon: root.services.network.wifiUp ? root.icons.wifiConnected : (Networking.wifiEnabled
                                                                                                 ? root.icons.wifiEnabled :
                                                                                                   root.icons.wifiDisconnected)
                                title: "Wi-Fi"
                                subtitle: !Networking.wifiHardwareEnabled ? "Unavailable" : (!Networking.wifiEnabled
                                                                                             ? "Disabled" :
                                                                                               ControlCenterLogic.wifiSummary(
                                                                                                   root.services.network.connectedWifiNetwork,
                                                                                                   true))
                                active: Networking.wifiEnabled
                                available: Networking.wifiHardwareEnabled
                                expanded: root.expandedNetworkSection === "wifi"
                                onBodyClicked: controlCenterController.toggleNetworkSection("wifi")
                                onToggled: controlCenterController.toggleWifiEnabled()
                            }
                        }
                    }

                    Item {
                        id: audioControlsRow
                        width: parent.width
                        height: root.theme.sizing.statusBarNetworkQuickControlHeight

                        Row {
                            anchors.fill: parent
                            spacing: root.theme.spacing.space6

                            NetworkControlCard {
                                width: (parent.width - parent.spacing) / 2
                                height: parent.height
                                theme: root.theme
                                icon: root.outputIcon
                                title: root.outputSinkLabel
                                subtitle: root.outputSummary
                                active: root.outputAvailable && !root.services.audio.sinkMuted && (
                                            root.outputQuickVolume?.authoritativePercent ?? 0) > 0
                                available: root.outputAvailable
                                detailAvailable: true
                                expanded: root.expandedNetworkSection === "output"
                                actionAccessibleName: root.services.audio.sinkMuted ? "Unmute output" : "Mute output"
                                detailAccessibleName: expanded ? "Hide output volume" : "Show output volume"
                                stateDescription: subtitle
                                onBodyClicked: controlCenterController.toggleNetworkSection("output")
                                onToggled: root.services.audio.toggleMute(false)
                            }

                            NetworkControlCard {
                                width: (parent.width - parent.spacing) / 2
                                height: parent.height
                                theme: root.theme
                                icon: root.services.audio.sourceMuted ? root.icons.microphoneMuted :
                                                                        root.icons.microphone

                                title: ControlCenterLogic.audioSourceLabel(root.services.audio.source, "Microphone")
                                subtitle: ControlCenterLogic.microphoneSummary(root.services.audio.microphoneAvailable,
                                                                             root.services.audio.sourceMuted,
                                                                             root.services.audio.sourceVolume)
                                active: root.services.audio.microphoneAvailable && !root.services.audio.sourceMuted
                                available: root.services.audio.microphoneAvailable
                                detailAvailable: true
                                expanded: root.expandedNetworkSection === "microphone"
                                actionAccessibleName: root.services.audio.sourceMuted ? "Unmute microphone" :
                                                                                        "Mute microphone"
                                detailAccessibleName: expanded ? "Hide microphone volume" : "Show microphone volume"
                                stateDescription: subtitle
                                onBodyClicked: controlCenterController.toggleNetworkSection("microphone")
                                onToggled: root.services.audio.toggleMute(true)
                            }
                        }
                    }

                    NetworkControlCard {
                        id: bluetoothCard
                        width: (parent.width - root.theme.spacing.space8) / 2
                        height: root.theme.sizing.statusBarNetworkQuickControlHeight
                        theme: root.theme
                        icon: !root.services.bluetooth.bluetoothAvailable ? root.icons.bluetoothOff : (
                                                                                root.services.bluetooth.bluetoothConnectedCount
                                                                                > 0 ? root.icons.bluetoothConnected : (
                                                                                          root.services.bluetooth.bluetoothPowered
                                                                                          ? root.icons.bluetoothOn :
                                                                                            root.icons.bluetoothOff))
                        title: "Bluetooth"
                        subtitle: ControlCenterLogic.bluetoothSummary(root.services.bluetooth.bluetoothAvailable,
                                                                    root.services.bluetooth.bluetoothPowered,
                                                                    root.services.bluetooth.bluetoothConnectedCount)
                        active: root.services.bluetooth.bluetoothPowered
                        available: root.services.bluetooth.bluetoothAvailable
                        actionAccessibleName: root.services.bluetooth.bluetoothPowered ? "Disable Bluetooth" :
                                                                                         "Enable Bluetooth"
                        stateDescription: subtitle
                        detailAvailable: root.services.bluetooth.bluetoothAvailable
                        expanded: root.expandedNetworkSection === "bluetooth"
                        detailAccessibleName: expanded ? "Hide Bluetooth devices" : "Show Bluetooth devices"
                        onBodyClicked: controlCenterController.toggleNetworkSection("bluetooth")
                        onToggled: {
                            if (root.services.bluetooth.bluetoothAdapter)
                                root.services.bluetooth.bluetoothAdapter.enabled =
                                        !root.services.bluetooth.bluetoothAdapter.enabled
                        }
                    }
                }

                Flickable {
                    id: detailFlickable
                    width: parent.width
                    height: ControlCenterLogic.detailViewportHeight(root.activeDetail, detailContent.implicitHeight,
                                                                  menuContainer.height - root.theme.spacing.space24
                                                                  - fixedShell.implicitHeight - (root.activeDetail
                                                                                                 ? root.theme.spacing.space8 :
                                                                                                   0), root.theme.sizing.statusBarNetworkQuickControlHeight)
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
                        policy: root.activeDetail && detailFlickable.height > 0 && detailFlickable.contentHeight
                                > detailFlickable.height ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
                    }

                    Column {
                        id: detailContent
                        width: detailFlickable.width

                        Item {
                            id: outputCard
                            visible: root.expandedNetworkSection === "output"
                            width: parent.width
                            height: outputColumn.implicitHeight + root.theme.spacing.space24

                            Column {
                                id: outputColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space6

                                AudioMixerSection {
                                    id: audioMixerSection
                                    width: parent.width
                                    audio: root.services.audio
                                    theme: root.theme
                                    icons: root.icons
                                    outputQuickVolume: root.outputQuickVolume
                                    outputAvailable: root.outputAvailable
                                    outputIcon: root.outputIcon
                                    onMasterVolumeRequested: value => {
                                        root.quickControlRequestSequence += 1
                                        root.services.audio.requestSinkVolume(value, root.quickControlRequestSequence)
                                    }
                                }
                            }
                        }

                        Item {
                            id: microphoneCard
                            visible: root.expandedNetworkSection === "microphone"
                            width: parent.width
                            height: microphoneColumn.implicitHeight + root.theme.spacing.space24

                            Column {
                                id: microphoneColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space6

                                AudioInputSection {
                                    width: parent.width
                                    theme: root.theme
                                    services: root.services
                                    onInputVolumeRequested: value => root.services.audio.setSourceVolume(value)
                                }
                            }
                        }

                        Item {
                            id: lanCard
                            visible: root.expandedNetworkSection === "ethernet"
                            width: parent.width
                            height: lanColumn.implicitHeight + root.theme.spacing.space24

                            Column {
                                id: lanColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space6

                                AppText {
                                    text: "Ethernet info"
                                    color: Colors.on_surface_variant
                                    font.pixelSize: root.theme.typography.sizeMd
                                    font.styleName: root.theme.typography.styleRegular
                                }

                                EthernetInfoCard {
                                    width: parent.width
                                    theme: root.theme
                                    interfaceName: root.services.network.lanDevice?.name || ""
                                    wired: Boolean(root.services.network.lanDevice?.hasLink)
                                    online: Boolean(root.services.network.lanUp)
                                    address: root.services.network.ethernetInfo.ipv4Address || ""
                                }

                                AppText {
                                    visible: root.connectionError.length > 0
                                             || root.services.network.ethernetProfileError.length > 0
                                    width: parent.width
                                    text: root.services.network.ethernetProfileError || root.connectionError
                                    color: Colors.error
                                    font.pixelSize: root.theme.typography.sizeSm
                                    font.styleName: root.theme.typography.styleRegular
                                    wrapMode: Text.Wrap
                                }

                                AppText {
                                    visible: root.hasEthernetProfiles
                                    text: "Connection profiles"
                                    color: Colors.on_surface_variant
                                    font.pixelSize: root.theme.typography.sizeMd
                                    font.styleName: root.theme.typography.styleRegular
                                }

                                Repeater {
                                    model: root.services.network.lanDevice?.network?.nmSettings ?? []

                                    EthernetProfileRow {
                                        required property var modelData
                                        width: parent.width
                                        profile: modelData
                                        active: modelData.uuid === root.services.network.ethernetInfo.activeUuid
                                        busy: root.services.network.ethernetProfileBusy
                                        pending: modelData.uuid === root.services.network.ethernetProfilePendingUuid
                                        theme: root.theme
                                        onToggleRequested: profile => root.services.network.setEthernetProfileEnabled(
                                                                          profile)
                                    }
                                }
                            }
                        }

                        Item {
                            id: bluetoothDetails
                            visible: root.expandedNetworkSection === "bluetooth"
                            width: parent.width
                            height: bluetoothDetailsColumn.implicitHeight + root.theme.spacing.space24

                            Column {
                                id: bluetoothDetailsColumn
                                readonly property var bluetoothDevices: ControlCenterLogic.bluetoothUniqueDevices(
                                                                            root.services.bluetooth.bluetoothDevices)
                                readonly property var connectedDevices: bluetoothDevices.filter(device
                                                                                                => ControlCenterLogic.bluetoothDeviceCategory(
                                                                                                       device)
                                                                                                   === "connected")
                                readonly property var knownDevices: bluetoothDevices.filter(device
                                                                                            => ControlCenterLogic.bluetoothDeviceCategory(
                                                                                                   device)
                                                                                               === "known-disconnected")
                                readonly property var availableDevices: bluetoothDevices.filter(device
                                                                                                => ControlCenterLogic.bluetoothDeviceCategory(
                                                                                                       device)
                                                                                                   === "available" &&
                                                                                                   !device.blocked
                                                                                                   && root.scanningBluetooth)
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space6

                                Item {
                                    id: bluetoothInfoHeader
                                    width: parent.width
                                    height: Math.max(bluetoothInfoTitle.implicitHeight,
                                                     scanButton.visible ? scanButton.height : 0)

                                    AppText {
                                        id: bluetoothInfoTitle
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Bluetooth info"
                                        color: Colors.on_surface_variant
                                        font.pixelSize: root.theme.typography.sizeMd
                                        font.styleName: root.theme.typography.styleRegular
                                    }

                                    Rectangle {
                                        id: scanButton
                                        visible: root.services.bluetooth.bluetoothPowered
                                        width: scanContent.implicitWidth + root.theme.spacing.space12
                                        height: scanContent.implicitHeight + root.theme.spacing.space4
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: height / 2
                                        color: scanInput.containsMouse || scanInput.activeFocus ? Colors.hover :
                                                                                                   "transparent"

                                        Row {
                                            id: scanContent
                                            anchors.centerIn: parent
                                            spacing: root.theme.spacing.space6

                                            AppText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.icons.search
                                                color: scanInput.containsMouse ? Colors.on_hover : Colors.primary
                                                font.family: root.theme.typography.iconFontFamily
                                                font.pixelSize: root.theme.typography.sizeSm
                                            }

                                            AppText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.scanningBluetooth ? "Scanning…" :
                                                                                                     "Scan"
                                                color: scanInput.containsMouse ? Colors.on_hover : Colors.primary
                                                font.pixelSize: root.theme.typography.sizeSm
                                                font.styleName: root.theme.typography.styleMedium
                                            }
                                        }

                                        MouseArea {
                                            id: scanInput
                                            anchors.fill: parent
                                            enabled: root.services.bluetooth.bluetoothPowered
                                            hoverEnabled: true
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            activeFocusOnTab: enabled
                                            Accessible.role: Accessible.Button
                                            Accessible.name: root.scanningBluetooth
                                                             ? "Scanning Bluetooth" : "Scan Bluetooth"
                                            onClicked: root.toggleBluetoothScan()
                                            Keys.onSpacePressed: root.toggleBluetoothScan()
                                            Keys.onReturnPressed: root.toggleBluetoothScan()
                                            Keys.onEnterPressed: root.toggleBluetoothScan()
                                        }
                                    }
                                }

                                BluetoothInfoCard {
                                    width: parent.width
                                    theme: root.theme
                                    adapterName: root.services.bluetooth.bluetoothAdapterName
                                    available: root.services.bluetooth.bluetoothAvailable
                                    powered: root.services.bluetooth.bluetoothPowered
                                    discoverable: root.services.bluetooth.bluetoothDiscoverable
                                    connectedCount: root.services.bluetooth.bluetoothConnectedCount
                                    onVisibilityToggleRequested: root.services.bluetooth.toggleBluetoothDiscoverable()
                                }

                                AppText {
                                    visible: root.services.bluetooth.bluetoothError.length > 0
                                    width: parent.width
                                    text: root.services.bluetooth.bluetoothError
                                    color: Colors.error
                                    font.pixelSize: root.theme.typography.sizeSm
                                    font.styleName: root.theme.typography.styleRegular
                                    wrapMode: Text.Wrap
                                }

                                Column {
                                    id: bluetoothConnectedSection
                                    visible: bluetoothDetailsColumn.connectedDevices.length > 0
                                    width: parent.width
                                    spacing: root.theme.spacing.space6

                                    AppText {
                                        width: parent.width
                                        text: "Connected devices"
                                        color: Colors.on_surface_variant
                                        font.pixelSize: root.theme.typography.sizeMd
                                        font.styleName: root.theme.typography.styleRegular
                                    }
                                    Repeater {
                                        model: bluetoothDetailsColumn.connectedDevices

                                        delegate: BluetoothDeviceRow {
                                            required property var modelData

                                            width: bluetoothConnectedSection.width
                                            device: modelData
                                            theme: root.theme
                                            powered: root.services.bluetooth.bluetoothPowered
                                            primaryActionVisible: root.services.bluetooth.bluetoothPowered
                                            pending: {
                                                root.services.bluetooth.bluetoothPendingRevision
                                                return root.services.bluetooth.bluetoothDeviceBusy(device)
                                            }
                                            onPrimaryActionRequested: root.services.bluetooth.disconnectBluetoothDevice(
                                                                          device)
                                            onForgetRequested: root.services.bluetooth.forgetBluetoothDevice(device)
                                        }
                                    }
                                }

                                Column {
                                    id: bluetoothKnownSection
                                    visible: bluetoothDetailsColumn.knownDevices.length > 0
                                    width: parent.width
                                    spacing: root.theme.spacing.space6

                                    AppText {
                                        width: parent.width
                                        text: "Known devices"
                                        color: Colors.on_surface_variant
                                        font.pixelSize: root.theme.typography.sizeMd
                                        font.styleName: root.theme.typography.styleRegular
                                    }
                                    Repeater {
                                        model: bluetoothDetailsColumn.knownDevices

                                        delegate: BluetoothDeviceRow {
                                            required property var modelData

                                            width: bluetoothKnownSection.width
                                            device: modelData
                                            theme: root.theme
                                            powered: root.services.bluetooth.bluetoothPowered
                                            primaryActionVisible: root.services.bluetooth.bluetoothPowered
                                            pending: {
                                                root.services.bluetooth.bluetoothPendingRevision
                                                return root.services.bluetooth.bluetoothDeviceBusy(device)
                                            }
                                            onPrimaryActionRequested: root.services.bluetooth.connectBluetoothDevice(
                                                                          device)
                                            onForgetRequested: root.services.bluetooth.forgetBluetoothDevice(device)
                                        }
                                    }
                                }

                                Column {
                                    id: bluetoothAvailableSection
                                    visible: root.scanningBluetooth
                                             && bluetoothDetailsColumn.availableDevices.length > 0
                                    width: parent.width
                                    spacing: root.theme.spacing.space6

                                    AppText {
                                        width: parent.width
                                        text: "Available devices"
                                        color: Colors.on_surface_variant
                                        font.pixelSize: root.theme.typography.sizeMd
                                        font.styleName: root.theme.typography.styleRegular
                                    }
                                    Repeater {
                                        model: bluetoothDetailsColumn.availableDevices

                                        delegate: BluetoothDeviceRow {
                                            required property var modelData

                                            width: bluetoothAvailableSection.width
                                            device: modelData
                                            theme: root.theme
                                            powered: root.services.bluetooth.bluetoothPowered
                                            primaryActionVisible: root.services.bluetooth.bluetoothPowered
                                            pending: {
                                                root.services.bluetooth.bluetoothPendingRevision
                                                return root.services.bluetooth.bluetoothDeviceBusy(device)
                                            }
                                            onPrimaryActionRequested: root.services.bluetooth.pairBluetoothDevice(
                                                                          device)
                                        }
                                    }
                                }

                                ControlEmptyState {
                                    visible: root.scanningBluetooth
                                             && bluetoothDetailsColumn.availableDevices.length === 0
                                    width: parent.width
                                    theme: root.theme
                                    title: "Scanning…"
                                    description: "Looking for Bluetooth devices nearby"
                                }
                            }
                        }

                        Item {
                            id: wifiCard
                            visible: root.expandedNetworkSection === "wifi"
                            width: parent.width
                            height: wifiColumn.implicitHeight + root.theme.spacing.space24

                            Column {
                                id: wifiColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space6

                                AppText {
                                    text: "Wi-Fi info"
                                    color: Colors.on_surface_variant
                                    font.pixelSize: root.theme.typography.sizeMd
                                    font.styleName: root.theme.typography.styleRegular
                                }

                                WifiInfoCard {
                                    width: parent.width
                                    theme: root.theme
                                    interfaceName: root.services.network.wifiInterface || ""
                                    address: root.services.network.wifiInfo.ipv4Address || ""
                                    hardwareEnabled: Networking.wifiHardwareEnabled
                                    radioEnabled: Networking.wifiEnabled
                                    activating: root.wifiActivationPending
                                    online: root.services.network.wifiUp
                                }

                                AppText {
                                    visible: !root.wifiActivationPending && root.services.network.wifiUp
                                             && root.services.network.wifiInfoAvailability !== "available"
                                    width: parent.width
                                    text: root.services.network.wifiInfoAvailability === "unavailable"
                                          ? "Network details unavailable" : "Loading network details…"
                                    color: Colors.on_surface_variant
                                    font.pixelSize: root.theme.typography.sizeSm
                                    font.styleName: root.theme.typography.styleRegular
                                    wrapMode: Text.WordWrap
                                }

                                AppText {
                                    visible: root.connectionError.length > 0
                                    width: parent.width
                                    text: root.connectionError
                                    color: Colors.error
                                    font.pixelSize: root.theme.typography.sizeSm
                                    font.styleName: root.theme.typography.styleRegular
                                    wrapMode: Text.Wrap
                                }

                                AppText {
                                    text: "Available networks"
                                    color: Colors.on_surface_variant
                                    font.pixelSize: root.theme.typography.sizeMd
                                    font.styleName: root.theme.typography.styleRegular
                                }

                                Repeater {
                                    model: root.availableWifiNetworks

                                    WifiNetworkRow {
                                        id: networkRow
                                        required property var modelData
                                        width: parent.width
                                        network: modelData
                                        theme: root.theme
                                        openSecurityValue: WifiSecurityType.None

                                        Connections {
                                            target: networkRow.modelData
                                            function onConnectedChanged() {
                                                controlCenterController.handleWifiNetworkConnectedChanged(
                                                            networkRow.modelData)
                                            }
                                            function onConnectionFailed(reason) {
                                                controlCenterController.handleWifiNetworkConnectionFailed(networkRow.modelData,
                                                                                                    reason)
                                            }
                                        }

                                        onPrimaryActionRequested: controlCenterController.connectNetwork(modelData)
                                        onForgetRequested: controlCenterController.forgetNetwork(modelData)
                                    }
                                }

                                ControlEmptyState {
                                    visible: root.availableWifiNetworks.length === 0
                                    width: parent.width
                                    theme: root.theme
                                    title: root.wifiEmptyTitle
                                    description: root.wifiEmptyDescription
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
        theme: root.theme
        network: root.pendingNetwork
        errorText: root.connectionError
        onSubmitted: password => controlCenterController.submitPassword(password)
        onCancelled: controlCenterController.cancelPasswordEntry()
    }
}
