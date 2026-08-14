import QtQuick
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
    // True while the radio really is sweeping, read from the device itself.
    readonly property bool wifiScanning: controlCenterController.wifiScanning
    readonly property bool wifiUsable: Networking.wifiHardwareEnabled && Boolean(services.network.wifiDevice)
    // The wifi section carries no empty state, so the copy that fed one is
    // gone with it rather than left here waiting for a reader to prove it
    // dead. Wi-Fi unavailable, Enabling Wi-Fi, No networks found: all of it
    // said, in the moment it appeared, less than the heading and the wheel
    // beside it were already saying.
    // What the device is reporting this instant.
    readonly property var liveWifiNetworks: Networking.wifiHardwareEnabled && Networking.wifiEnabled &&
                                            !wifiActivationPending && services.network.wifiDevice
                                            ? ControlCenterLogic.sortedWifiNetworks(
                                                  services.network.wifiDevice.networks?.values ?? []) : []

    // And what is drawn, which is not the same thing.
    //
    // Quickshell empties `WifiDevice.networks` the moment the scanner stops,
    // so a scan that ends would take its own results off the screen with it —
    // the list would vanish at the twenty-fifth second and leave nothing to
    // connect to. Holding the last non-empty answer is what lets the radio
    // stop without the panel going blank, and it is the whole reason a scan
    // here can be a burst rather than a vigil.
    //
    // Kept as the rows themselves rather than as copied text: a row has to
    // stay clickable to be worth drawing, and only the real object can
    // connect, forget or report that it is already connected.
    property var retainedWifiNetworks: []

    // Only while the sweep is running, and that condition is the whole fix.
    //
    // Measured, not assumed: with the scanner on the device reported nine
    // networks; with it off, one — the connected one. It does not empty, it
    // collapses. So "keep the last non-empty answer" kept the collapse, and
    // the panel fell to a single row a moment after the wheel stopped.
    //
    // Tracking only while scanning freezes the list at whatever the sweep last
    // saw, and every reading after the radio stops is ignored.
    onLiveWifiNetworksChanged: {
        if (wifiScanning && liveWifiNetworks.length > 0)
            retainedWifiNetworks = liveWifiNetworks
    }

    // Turning the radio off is the one case where the memory has to go too.
    // Networks held from a previous session are not "available" by any reading
    // of the word, and the section says the radio is off two lines above.
    onWifiUsableChanged: if (!wifiUsable)
        retainedWifiNetworks = []

    // Always the retained copy, never the device's own list.
    //
    // Choosing between them per reading was the mistake: the device's list is
    // only trustworthy while it is being filled, and the moment the radio
    // stops it starts shedding what it found. The retained copy is the same
    // list while the sweep runs and the only honest one afterwards, so there
    // is nothing to choose.
    readonly property var availableWifiNetworks: (Networking.wifiHardwareEnabled
                                                  && Networking.wifiEnabled) ? retainedWifiNetworks : []
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
    readonly property string outputIcon: root.outputIconKind === "unavailable" ? root.icons.audio.volumeUnavailable : (root.outputIconKind
                                                                                                                 === "muted"
                                                                                                                 ? root.icons.audio.volumeMuted :
                                                                                                                   (root.outputIconKind
                                                                                                                    === "low"
                                                                                                                    ? root.icons.audio.volumeLow :
                                                                                                                      (root.outputIconKind
                                                                                                                       === "medium"
                                                                                                                       ? root.icons.audio.volumeMedium :
                                                                                                                         root.icons.audio.volumeHigh)))

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

            width: Math.max(0, Math.min(ControlCenterSizing.panelWidth, menuWindow.width
                                        - root.theme.spacing.space16))
            height: ControlCenterLogic.menuCenterHeight(menuWindow.height, root.theme.spacing.space16, 360,
                                                      root.theme.spacing.space24, fixedShell.implicitHeight,
                                                      root.theme.spacing.space8, root.activeDetail,
                                                      detailContent.implicitHeight,
                                                      ControlCenterSizing.quickControlHeight,
                                                      ControlCenterSizing.panelMaxHeight)
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
                        height: ControlCenterSizing.userCardHeight
                        radius: root.theme.shape.radius12
                        color: Colors.surface
                        border.width: 0

                        Row {
                            anchors.fill: parent
                            anchors.margins: root.theme.spacing.space12
                            spacing: root.theme.spacing.space12

                            Rectangle {
                                width: ControlCenterSizing.avatarSize
                                height: ControlCenterSizing.avatarSize
                                anchors.verticalCenter: parent.verticalCenter
                                radius: width / 2
                                color: Colors.primary

                                AppText {
                                    anchors.centerIn: parent
                                    text: root.userInitial
                                    visible: avatarImage.status !== Image.Ready
                                    color: Colors.shadow
                                    font.family: root.theme.typography.textFontFamily
                                    font.pixelSize: root.theme.typography.glyphLg
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
                                        sourceSize.width: ControlCenterSizing.avatarSize * 2
                                        sourceSize.height: ControlCenterSizing.avatarSize * 2
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
                                width: parent.width - ControlCenterSizing.userTextReserve
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space2

                                AppText {
                                    width: parent.width
                                    text: root.username
                                    color: Colors.on_surface
                                    font.family: root.theme.typography.textFontFamily
                                    font.pixelSize: root.theme.typography.textBase
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
                                    font.pixelSize: root.theme.typography.textSm
                                    font.styleName: root.theme.typography.styleRegular
                                }
                            }
                        }
                    }

                    Item {
                        id: quickControlsRow
                        width: parent.width
                        height: ControlCenterSizing.quickControlHeight

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
                                        width: ControlCenterSizing.quickControlIconWidth
                                        anchors.verticalCenter: parent.verticalCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.outputIcon
                                        color: volumeSlider.enabled ? Colors.on_surface : Colors.on_surface_variant
                                        font.family: root.theme.typography.iconFontFamily
                                        font.pixelSize: root.theme.typography.textLg
                                        font.styleName: root.theme.typography.styleRegular
                                    }

                                    QuickControlSlider {
                                        id: volumeSlider
                                        theme: root.theme
                                        width: parent.width - ControlCenterSizing.quickControlIconWidth
                                               - parent.spacing
                                        height: ControlCenterSizing.quickControlSliderHeight
                                        anchors.verticalCenter: parent.verticalCenter
                                        trackHeight: ControlCenterSizing.quickControlTrackHeight
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
                                        width: ControlCenterSizing.quickControlIconWidth
                                        anchors.verticalCenter: parent.verticalCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.icons.display.brightness
                                        color: brightnessSlider.enabled ? Colors.on_surface : Colors.on_surface_variant
                                        font.family: root.theme.typography.iconFontFamily
                                        font.pixelSize: root.theme.typography.textLg
                                        font.styleName: root.theme.typography.styleRegular
                                    }

                                    QuickControlSlider {
                                        id: brightnessSlider
                                        theme: root.theme
                                        width: parent.width - ControlCenterSizing.quickControlIconWidth
                                               - parent.spacing
                                        height: ControlCenterSizing.quickControlSliderHeight
                                        anchors.verticalCenter: parent.verticalCenter
                                        trackHeight: ControlCenterSizing.quickControlTrackHeight
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
                        height: ControlCenterSizing.quickControlHeight

                        Row {
                            anchors.fill: parent
                            spacing: root.theme.spacing.space6

                            NetworkControlCard {
                                width: (parent.width - parent.spacing) / 2
                                height: parent.height
                                theme: root.theme
                                icon: root.services.network.lanUp ? root.icons.network.ethernet :
                                                                    root.icons.network.ethernetDisconnected

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
                                icon: root.services.network.wifiUp ? root.icons.network.wifiConnected : (Networking.wifiEnabled
                                                                                                 ? root.icons.network.wifiEnabled :
                                                                                                   root.icons.network.wifiDisconnected)
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
                        height: ControlCenterSizing.quickControlHeight

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
                                icon: root.services.audio.sourceMuted ? root.icons.audio.microphoneMuted :
                                                                        root.icons.audio.microphone

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
                        height: ControlCenterSizing.quickControlHeight
                        theme: root.theme
                        icon: !root.services.bluetooth.bluetoothAvailable ? root.icons.bluetooth.off : (
                                                                                root.services.bluetooth.bluetoothConnectedCount
                                                                                > 0 ? root.icons.bluetooth.connected : (
                                                                                          root.services.bluetooth.bluetoothPowered
                                                                                          ? root.icons.bluetooth.on :
                                                                                            root.icons.bluetooth.off))
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
                                                                                                   0), ControlCenterSizing.quickControlHeight)
                    visible: root.activeDetail && height > 0
                    contentWidth: width
                    contentHeight: detailContent.implicitHeight
                    clip: true
                    // No scrollbar: wheel and drag only, matching the notification
                    // centre. interactive already gates on overflow, so the pane stops
                    // taking flicks when everything fits.
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    interactive: root.activeDetail && height > 0 && contentHeight > height
                    onContentHeightChanged: root.clampDetailContentY()
                    onHeightChanged: root.clampDetailContentY()
                    Component.onCompleted: root.clampDetailContentY()

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
                                    font.pixelSize: root.theme.typography.textMd
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
                                    font.pixelSize: root.theme.typography.textSm
                                    font.styleName: root.theme.typography.styleRegular
                                    wrapMode: Text.Wrap
                                }

                                AppText {
                                    visible: root.hasEthernetProfiles
                                    text: "Connection profiles"
                                    color: Colors.on_surface_variant
                                    font.pixelSize: root.theme.typography.textMd
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
                                // No `&& root.scanningBluetooth` here, and that
                                // removal is the whole fix: it emptied the
                                // list the instant the sweep ended, twenty-five
                                // seconds after it filled.
                                //
                                // Nothing is held in its place, unlike Wi-Fi,
                                // because nothing needs to be. BlueZ keeps a
                                // device it discovered for a while after
                                // discovery stops, so simply asking the
                                // adapter what it knows already outlives the
                                // scan, and each device drops out on its own
                                // when BlueZ finally forgets it.
                                //
                                // A retained copy was tried and is worse than
                                // useless here. Wi-Fi can hold its rows —
                                // measured, nine of nine still answered after
                                // the scanner stopped — but a Bluetooth device
                                // BlueZ deletes leaves a null behind, which
                                // drew as "Unknown device / Working…". Worse,
                                // a copy taken during the sweep would keep
                                // showing a device under "Available" after you
                                // paired it, when the adapter had already
                                // moved it to the known list.
                                readonly property var availableDevices: bluetoothDevices.filter(device
                                                                                                => ControlCenterLogic.bluetoothDeviceCategory(
                                                                                                       device)
                                                                                                   === "available"
                                                                                                   && !device.blocked)

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacing.space6

                                // The label alone now. Scanning used to share
                                // this line as a pill reading "Scan" or
                                // "Scanning…", which put the control over the
                                // adapter's details rather than over the list
                                // it refreshes. It moved down to the heading
                                // of "Available devices", where the thing it
                                // affects actually is.
                                AppText {
                                    id: bluetoothInfoTitle

                                    width: parent.width
                                    text: "Bluetooth info"
                                    color: Colors.on_surface_variant
                                    font.pixelSize: root.theme.typography.textMd
                                    font.styleName: root.theme.typography.styleRegular
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
                                    font.pixelSize: root.theme.typography.textSm
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
                                        font.pixelSize: root.theme.typography.textMd
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
                                        font.pixelSize: root.theme.typography.textMd
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

                                    // Shown whenever the adapter is on, not
                                    // only while it is sweeping. The list it
                                    // heads outlives the sweep now, so hiding
                                    // the heading with the scan would take the
                                    // rescan away with it and leave no way to
                                    // ask again.
                                    visible: root.services.bluetooth.bluetoothPowered
                                    width: parent.width
                                    spacing: root.theme.spacing.space6

                                    // The heading and its rescan share one
                                    // line, the same as Wi-Fi: a wheel while
                                    // the adapter is discovering, an arrow you
                                    // can press once it has stopped.
                                    Item {
                                        id: availableDevicesHeader

                                        width: parent.width
                                        height: availableDevicesLabel.implicitHeight

                                        AppText {
                                            id: availableDevicesLabel

                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Available devices"
                                            color: Colors.on_surface_variant
                                            font.pixelSize: root.theme.typography.textMd
                                            font.styleName: root.theme.typography.styleRegular
                                        }

                                        Rectangle {
                                            id: bluetoothRescanButton

                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: bluetoothRescanGlyph.implicitWidth + root.theme.spacing.space8
                                            height: width
                                            radius: height / 2
                                            color: bluetoothRescanInput.containsMouse
                                                   || bluetoothRescanInput.activeFocus ? Colors.hover : "transparent"

                                            AppText {
                                                id: bluetoothRescanGlyph

                                                anchors.centerIn: parent
                                                text: root.scanningBluetooth ? root.icons.ui.spinner : root.icons.ui.refresh
                                                color: bluetoothRescanInput.containsMouse ? Colors.on_hover : Colors.primary
                                                font.family: root.theme.typography.iconFontFamily
                                                font.pixelSize: root.theme.typography.textSm

                                                RotationAnimator on rotation {
                                                    running: root.scanningBluetooth
                                                    loops: Animation.Infinite
                                                    from: 0
                                                    to: 360
                                                    duration: root.theme.motion.spinnerRotationMs

                                                    // Upright again the moment
                                                    // it stops: an arrow left
                                                    // at whatever angle the
                                                    // wheel died on reads as
                                                    // broken.
                                                    onRunningChanged: if (!running)
                                                        bluetoothRescanGlyph.rotation = 0
                                                }
                                            }

                                            MouseArea {
                                                id: bluetoothRescanInput

                                                anchors.fill: parent
                                                enabled: !root.scanningBluetooth
                                                hoverEnabled: true
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                activeFocusOnTab: enabled
                                                Accessible.role: Accessible.Button
                                                Accessible.name: root.scanningBluetooth
                                                                 ? "Scanning for devices" : "Scan for devices"
                                                onClicked: root.startBluetoothScan()
                                                Keys.onSpacePressed: root.startBluetoothScan()
                                                Keys.onReturnPressed: root.startBluetoothScan()
                                                Keys.onEnterPressed: root.startBluetoothScan()
                                            }
                                        }
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

                                // No empty state here either. Under "Available
                                // devices" there is the heading, its rescan
                                // and devices — a box that appears only when
                                // the list is empty shows up exactly when
                                // there is least to look at, and it said
                                // "Scanning…" about something the wheel beside
                                // the heading already says.
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
                                    font.pixelSize: root.theme.typography.textMd
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
                                    font.pixelSize: root.theme.typography.textSm
                                    font.styleName: root.theme.typography.styleRegular
                                    wrapMode: Text.WordWrap
                                }

                                AppText {
                                    visible: root.connectionError.length > 0
                                    width: parent.width
                                    text: root.connectionError
                                    color: Colors.error
                                    font.pixelSize: root.theme.typography.textSm
                                    font.styleName: root.theme.typography.styleRegular
                                    wrapMode: Text.Wrap
                                }

                                // The heading and its rescan share one line.
                                //
                                // Hidden with the radio off, because a list of
                                // networks headed "Available" while the wifi
                                // is off promises something that cannot be
                                // true. The rest of the section already says
                                // the radio is off; this would argue with it.
                                Item {
                                    id: availableNetworksHeader

                                    visible: Networking.wifiHardwareEnabled && Networking.wifiEnabled
                                    width: parent.width
                                    height: availableNetworksLabel.implicitHeight

                                    AppText {
                                        id: availableNetworksLabel

                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Available networks"
                                        color: Colors.on_surface_variant
                                        font.pixelSize: root.theme.typography.textMd
                                        font.styleName: root.theme.typography.styleRegular
                                    }

                                    // The scan runs in bursts, so this is both
                                    // the report and the way to ask for
                                    // another: a wheel while the radio is
                                    // listening, an arrow you can press once
                                    // it has stopped.
                                    Rectangle {
                                        id: rescanButton

                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: rescanGlyph.implicitWidth + root.theme.spacing.space8
                                        height: width
                                        radius: height / 2
                                        color: rescanInput.containsMouse
                                               || rescanInput.activeFocus ? Colors.hover : "transparent"

                                        AppText {
                                            id: rescanGlyph

                                            anchors.centerIn: parent
                                            text: root.wifiScanning ? root.icons.ui.spinner : root.icons.ui.refresh
                                            color: rescanInput.containsMouse ? Colors.on_hover : Colors.primary
                                            font.family: root.theme.typography.iconFontFamily
                                            font.pixelSize: root.theme.typography.textSm

                                            // Only the wheel turns, and only
                                            // while the radio is listening. An
                                            // animation left running on the
                                            // arrow would say the scan never
                                            // ends, which is the one thing
                                            // this change was made to stop.
                                            RotationAnimator on rotation {
                                                running: root.wifiScanning
                                                loops: Animation.Infinite
                                                from: 0
                                                to: 360
                                                duration: root.theme.motion.spinnerRotationMs

                                                // Put back upright the moment
                                                // it stops. An arrow left at
                                                // whatever angle the wheel
                                                // died on reads as broken, and
                                                // the animation stopping is
                                                // the only honest signal for
                                                // when that matters.
                                                onRunningChanged: if (!running)
                                                    rescanGlyph.rotation = 0
                                            }
                                        }

                                        MouseArea {
                                            id: rescanInput

                                            anchors.fill: parent
                                            enabled: !root.wifiScanning
                                            hoverEnabled: true
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            activeFocusOnTab: enabled
                                            Accessible.role: Accessible.Button
                                            Accessible.name: root.wifiScanning
                                                             ? "Scanning for networks" : "Scan for networks"
                                            onClicked: controlCenterController.rescanWifi()
                                            Keys.onSpacePressed: controlCenterController.rescanWifi()
                                            Keys.onReturnPressed: controlCenterController.rescanWifi()
                                            Keys.onEnterPressed: controlCenterController.rescanWifi()
                                        }
                                    }
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

                                // No empty state here, deliberately.
                                //
                                // Under "Available networks" there is the
                                // heading, its rescan, and networks. A box
                                // that appears only when the list is empty is
                                // a fourth thing that shows up exactly when
                                // there is least to look at — and it was worst
                                // at the one moment it was most visible, the
                                // first seconds after switching the radio on,
                                // where it announced "no networks" about a
                                // scan that had not finished. The wheel beside
                                // the heading already says a scan is running,
                                // and an empty list under it is not ambiguous.
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
