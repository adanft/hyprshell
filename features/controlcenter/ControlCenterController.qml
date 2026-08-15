import QtQuick
import "ControlCenterWorkflow.js" as Workflow

QtObject {
    id: root

    required property var networkService
    required property var networking
    required property bool menuOpen
    required property var uptimeSource
    required property var failureReasonText
    required property var openSecurityValue
    required property var noSecretsValue

    property var reducerState: Workflow.initialState()
    readonly property var scannerDevice: reducerState.scannerDevice
    readonly property var scannerOwnedDevice: reducerState.scannerOwnedDevice
    readonly property bool wifiActivationPending: reducerState.wifiActivationPending
    readonly property bool wifiActivationRequested: reducerState.wifiActivationRequested
    readonly property int wifiActivationGeneration: reducerState.wifiActivationGeneration
    readonly property string expandedNetworkSection: reducerState.expandedNetworkSection
    readonly property bool detailsSubscribed: reducerState.detailsSubscribed
    readonly property var pendingNetwork: reducerState.pendingNetwork
    readonly property var suppressedPasswordNetwork: reducerState.suppressedPasswordNetwork
    readonly property string connectionError: reducerState.connectionError

    readonly property int scannerStartDelayMs: 300
    // The same twenty-five seconds Bluetooth gives its own scan. Long enough
    // for the far side of the flat to answer, short enough that a panel left
    // open does not hold the radio all afternoon.
    readonly property int scannerBurstMs: 25000
    // Read from the device, not kept alongside it. While this is true the
    // radio really is sweeping, so the wheel the interface turns is a report
    // rather than an animation played to look busy.
    readonly property bool wifiScanning: Boolean(root.networkService?.wifiDevice?.scannerEnabled)
    readonly property int activationSettleDelayMs: 900
    readonly property int uptimeRefreshIntervalMs: 60000
    property real uptimeSeconds: 0
    property var scannerDelayDevice: null
    property int scannerDelayGeneration: 0
    property int activationSettleGeneration: 0

    signal closeRequested

    property Timer wifiScannerStartTimer: Timer {
        interval: root.scannerStartDelayMs
        repeat: false
        onTriggered: root.handleScannerDelayElapsed(root.scannerDelayDevice, root.scannerDelayGeneration)
    }

    // Carries the device the scan was started for, so a timer that fires after
    // the scanner changed hands can be recognized as stale and ignored.
    property var scannerBurstDevice: null

    property Timer wifiScannerBurstTimer: Timer {
        interval: root.scannerBurstMs
        repeat: false
        onTriggered: root.handleScannerBurstElapsed(root.scannerBurstDevice)
    }

    property Timer wifiActivationSettleTimer: Timer {
        interval: root.activationSettleDelayMs
        repeat: false
        onTriggered: root.handleActivationSettleElapsed(root.activationSettleGeneration)
    }

    property Timer uptimeRefreshTimer: Timer {
        interval: root.uptimeRefreshIntervalMs
        running: root.menuOpen
        repeat: true
        onTriggered: root.refreshUptime()
    }

    function refreshUptime() {
        root.uptimeSource.reload()
        const value = Number.parseFloat(String(root.uptimeSource.text() || "0").split(/\s+/)[0])
        if (!Number.isNaN(value))
            root.uptimeSeconds = value
    }

    function prepareOpen() {
        root.dispatch({
                          type: "prepareOpen"
                      })
        root.refreshUptime()
    }

    function context(type, values) {
        return Object.assign({
                                 type,
                                 menuOpen: root.menuOpen,
                                 expandedNetworkSection: root.expandedNetworkSection,
                                 wifiEnabled: Boolean(root.networking?.wifiEnabled),
                                 wifiHardwareEnabled: Boolean(root.networking?.wifiHardwareEnabled),
                                 wifiDevice: root.networkService?.wifiDevice ?? null
                             }, values || {})
    }

    function dispatch(event) {
        const result = Workflow.transition(root.reducerState, event)
        root.reducerState = result.state
        for (const nextEffect of result.effects)
            root.executeEffect(nextEffect)
    }

    function executeEffect(nextEffect) {
        switch (nextEffect.type) {
        case "setWifiEnabled":
            root.networking.wifiEnabled = nextEffect.enabled
            break
        case "setScannerEnabled":
            if (nextEffect.device)
                nextEffect.device.scannerEnabled = nextEffect.enabled
            break
        case "startScannerDelay":
            root.scannerDelayDevice = nextEffect.device
            root.scannerDelayGeneration = nextEffect.generation
            root.wifiScannerStartTimer.restart()
            break
        case "stopScannerDelay":
            root.wifiScannerStartTimer.stop()
            break
        case "startScannerBurst":
            root.scannerBurstDevice = nextEffect.device
            root.wifiScannerBurstTimer.restart()
            break
        case "stopScannerBurst":
            root.wifiScannerBurstTimer.stop()
            break
        case "startActivationSettle":
            root.activationSettleGeneration = nextEffect.generation
            root.wifiActivationSettleTimer.restart()
            break
        case "stopActivationSettle":
            root.wifiActivationSettleTimer.stop()
            break
        case "enableNetworkDetails":
            root.networkService.enableNetworkDetails()
            break
        case "disableNetworkDetails":
            root.networkService.disableNetworkDetails()
            break
        case "connectNetwork":
            nextEffect.network.connect()
            break
        case "disconnectNetwork":
            nextEffect.network.disconnect()
            break
        case "connectNetworkWithPsk":
            nextEffect.network.connectWithPsk(nextEffect.password)
            break
        case "forgetNetwork":
            nextEffect.network.forget()
            break
        }
    }

    function toggleWifiEnabled() {
        root.dispatch(root.context("toggleWifi"))
    }

    function toggleNetworkSection(section) {
        root.dispatch(root.context("toggleSection", {
                                       section
                                   }))
    }

    // Opening the panel on a section is not the same gesture as clicking that
    // section's header. A section stays expanded across a close, so toggling it
    // on the way in would collapse the very thing the click asked to see.
    function expandNetworkSection(section) {
        if (!section || section.length === 0 || root.expandedNetworkSection === section)
            return
        root.toggleNetworkSection(section)
    }

    function requestClose() {
        root.dispatch({
                          type: "requestClose"
                      })
        root.closeRequested()
        root.dispatch({
                          type: "completeClose"
                      })
    }

    function connectNetwork(network) {
        root.dispatch({
                          type: "connectRequested",
                          network,
                          openSecurityValue: root.openSecurityValue
                      })
    }

    function submitPassword(password) {
        root.dispatch({
                          type: "submitPassword",
                          password
                      })
    }

    function cancelPasswordEntry() {
        root.dispatch({
                          type: "cancelPassword"
                      })
    }

    function forgetNetwork(network) {
        root.dispatch({
                          type: "forgetRequested",
                          network
                      })
    }

    function toggleEthernet() {
        const network = root.networkService.lanDevice?.network
        if (!network || network.stateChanging)
            return
        if (network.connected)
            network.disconnect()
        else
            network.connect()
    }

    function errorText(network, reason) {
        return `${network.name}: ${root.failureReasonText(reason)}`
    }

    function handleWifiNetworkConnectedChanged(network) {
        root.dispatch({
                          type: "wifiConnectedChanged",
                          network
                      })
    }

    function handleWifiNetworkConnectionFailed(network, reason) {
        root.dispatch({
                          type: "wifiConnectionFailed",
                          network,
                          reason,
                          noSecretsValue: root.noSecretsValue,
                          errorText: root.errorText(network, reason)
                      })
    }

    function handleScannerDelayElapsed(device, generation) {
        root.dispatch(root.context("scannerDelayElapsed", {
                                       scheduledDevice: device,
                                       scheduledGeneration: generation
                                   }))
    }

    // The scan is over: let the scanner go. What it found stays on screen
    // because the view kept its own copy — Quickshell empties the device's
    // list here, and that copy is the only reason stopping is survivable.
    function handleScannerBurstElapsed(device) {
        root.dispatch(root.context("scannerBurstElapsed", {
                                       scheduledDevice: device
                                   }))
    }

    // Look again. The only way back once a scan is spent.
    function rescanWifi() {
        if (root.wifiScanning)
            return
        root.dispatch(root.context("rescanRequested"))
    }

    function handleActivationSettleElapsed(generation) {
        root.dispatch({
                          type: "activationSettleElapsed",
                          generation
                      })
    }

    onMenuOpenChanged: root.dispatch(root.context("menuOpenChanged"))

    property Connections networkingConnections: Connections {
        target: root.networking
        ignoreUnknownSignals: true
        function onWifiEnabledChanged() {
            root.dispatch(root.context("wifiEnabledChanged"))
        }
        function onWifiHardwareEnabledChanged() {
            root.dispatch(root.context("wifiHardwareEnabledChanged"))
        }
    }

    property Connections serviceConnections: Connections {
        target: root.networkService
        ignoreUnknownSignals: true
        function onWifiDeviceChanged() {
            root.dispatch(root.context("wifiDeviceChanged"))
        }
    }

    property Connections pendingConnections: Connections {
        target: root.pendingNetwork
        ignoreUnknownSignals: true
        function onConnectedChanged() {
            root.dispatch({
                              type: "pendingConnectedChanged"
                          })
        }
        function onConnectionFailed(reason) {
            const network = root.pendingNetwork
            if (network)
                root.dispatch({
                                  type: "pendingConnectionFailed",
                                  errorText: root.errorText(network, reason)
                              })
        }
    }

    property Connections lanConnections: Connections {
        target: root.networkService.lanDevice?.network ?? null
        ignoreUnknownSignals: true
        function onConnectionFailed(reason) {
            root.dispatch({
                              type: "ethernetConnectionFailed",
                              errorText: `Ethernet: ${root.failureReasonText(reason)}`
                          })
        }
    }

    Component.onCompleted: {
        root.dispatch(root.context("syncScanner"))
        root.refreshUptime()
    }
    Component.onDestruction: root.dispatch({
                                               type: "destroy"
                                           })
}
