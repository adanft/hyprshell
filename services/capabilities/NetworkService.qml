import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../NetworkState.js" as NetworkState
import "../FileViewState.js" as FileViewState

Scope {
    id: root
    readonly property int networkRefreshMs: 1000
    readonly property var networkDevices: Networking.devices?.values ?? []
    readonly property var lanDevice: networkDevices.find(device => device.type === DeviceType.Wired) ?? null
    readonly property var wifiDevice: networkDevices.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property string lanInterface: lanDevice?.name ?? ""
    readonly property string wifiInterface: wifiDevice?.name ?? ""
    property var ethernetInfo: NetworkState.parseNmcliDeviceInfo("")
    property string ethernetInfoRequestedInterface: ""
    property int ethernetInfoRequestGeneration: 0
    property int ethernetInfoProcessGeneration: 0
    property bool ethernetInfoProcessRefreshesProfile: false
    property var wifiInfo: NetworkState.parseNmcliDeviceInfo("")
    property string wifiInfoRequestedInterface: ""
    property string wifiInfoAvailability: "idle"
    property int wifiInfoRequestGeneration: 0
    property int wifiInfoProcessGeneration: 0
    property bool ethernetProfileBusy: false
    property bool ethernetProfileAwaitingRefresh: false
    property int ethernetProfileActionGeneration: 0
    property int ethernetProfileActionProcessGeneration: 0
    property string ethernetProfilePendingUuid: ""
    property string ethernetProfileError: ""
    property real previousNetworkRx: 0
    property real previousNetworkTx: 0
    property real activeNetworkRxRate: 0
    property real activeNetworkTxRate: 0
    property int networkThroughputSubscriberCount: 0
    property int networkDetailsSubscriberCount: 0
    readonly property bool networkThroughputEnabled: networkThroughputSubscriberCount > 0
    readonly property bool networkDetailsEnabled: networkDetailsSubscriberCount > 0
    readonly property bool lanUp: lanDevice?.connected ?? false
    readonly property bool wifiUp: wifiDevice?.connected ?? false
    readonly property string activeNetworkInterface: lanUp ? lanInterface : (wifiUp ? wifiInterface : "")
    readonly property var connectedWifiNetwork: (wifiDevice?.networks?.values ?? []).find(network => network.connected)
                                                ?? null
    readonly property int wifiSignal: Math.round((connectedWifiNetwork?.signalStrength ?? 0) * 100)
    property string previousNetworkInterface: ""
    property real previousNetworkSampleMs: 0

    onLanInterfaceChanged: {
        ethernetInfoRequestGeneration += 1
        ethernetInfoRequestedInterface = ""
        ethernetInfo = NetworkState.parseNmcliDeviceInfo("")
        ethernetProfileActionGeneration += 1
        if (ethernetProfileBusy || ethernetProfileAwaitingRefresh) {
            ethernetProfileAwaitingRefresh = false
            ethernetProfileBusy = false
            ethernetProfilePendingUuid = ""
            if (ethernetProfileError.length === 0)
                ethernetProfileError = "Ethernet interface changed"
        }
        Qt.callLater(refreshEthernetInfo)
    }
    onWifiInterfaceChanged: resetWifiInfo()
    onWifiUpChanged: resetWifiInfo()

    FileView {
        id: networkRxBytes
        path: `/sys/class/net/${root.activeNetworkInterface}/statistics/rx_bytes`
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: networkTxBytes
        path: `/sys/class/net/${root.activeNetworkInterface}/statistics/tx_bytes`
        blockLoading: true
        printErrors: false
    }
    Timer {
        interval: root.networkRefreshMs
        running: root.networkThroughputEnabled
        repeat: true
        onTriggered: root.refreshNetwork()
    }
    Timer {
        interval: 3000
        running: root.networkDetailsEnabled && root.lanDevice !== null
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshEthernetInfo()
    }
    Timer {
        interval: 3000
        running: root.networkDetailsEnabled && root.wifiDevice !== null
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshWifiInfo()
    }
    Timer {
        id: ethernetActionRefreshTimer
        interval: 750
        repeat: false
        onTriggered: root.refreshEthernetInfo()
    }

    Process {
        id: ethernetInfoProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.ethernetInfoProcessGeneration === root.ethernetInfoRequestGeneration
                        && root.ethernetInfoRequestedInterface === root.lanInterface)
                    root.ethernetInfo = NetworkState.parseNmcliDeviceInfo(this.text)
            }
        }
        onExited: (exitCode, exitStatus) => {
            const current = root.ethernetInfoProcessGeneration === root.ethernetInfoRequestGeneration
                  && root.ethernetInfoRequestedInterface === root.lanInterface
            if (current && root.ethernetInfoProcessRefreshesProfile && root.ethernetProfileAwaitingRefresh) {
                root.ethernetProfileAwaitingRefresh = false
                root.ethernetProfileBusy = false
                root.ethernetProfilePendingUuid = ""
                if (exitCode !== 0 && root.ethernetProfileError.length === 0)
                    root.ethernetProfileError = `Ethernet refresh failed (${exitCode})`
            }
            if ((!current || (root.ethernetProfileAwaitingRefresh && !root.ethernetInfoProcessRefreshesProfile))
                    && root.lanInterface.length > 0)
                Qt.callLater(root.refreshEthernetInfo)
        }
    }
    Process {
        id: wifiInfoProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.wifiInfoProcessGeneration === root.wifiInfoRequestGeneration
                        && root.wifiInfoRequestedInterface === root.wifiInterface) {
                    root.wifiInfo = NetworkState.parseNmcliDeviceInfo(this.text)
                    root.wifiInfoAvailability = "available"
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            const current = root.wifiInfoProcessGeneration === root.wifiInfoRequestGeneration
                  && root.wifiInfoRequestedInterface === root.wifiInterface
            if (exitCode !== 0 && current) {
                root.wifiInfo = NetworkState.parseNmcliDeviceInfo("")
                root.wifiInfoAvailability = "unavailable"
            }
            if (!current && root.wifiInterface.length > 0)
                Qt.callLater(root.refreshWifiInfo)
        }
    }
    Process {
        id: ethernetProfileActionProcess
        stderr: StdioCollector {
            onStreamFinished: {
                if (root.ethernetProfileActionProcessGeneration === root.ethernetProfileActionGeneration)
                    root.ethernetProfileError = String(this.text || "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.ethernetProfileActionProcessGeneration !== root.ethernetProfileActionGeneration)
                return
            if (exitCode !== 0 && root.ethernetProfileError.length === 0)
                root.ethernetProfileError = `NetworkManager command failed (${exitCode})`
            root.ethernetProfileAwaitingRefresh = true
            ethernetActionRefreshTimer.restart()
        }
    }
    Component.onCompleted: refreshNetwork()

    function resetWifiInfo() {
        wifiInfoRequestGeneration += 1
        wifiInfoRequestedInterface = ""
        wifiInfoAvailability = "idle"
        wifiInfo = NetworkState.parseNmcliDeviceInfo("")
        Qt.callLater(refreshWifiInfo)
    }
    function toggleWifiEnabled() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }
    function enableNetworkThroughput() {
        networkThroughputSubscriberCount++
        refreshNetwork()
    }
    function disableNetworkThroughput() {
        networkThroughputSubscriberCount = Math.max(0, networkThroughputSubscriberCount - 1)
        if (!networkThroughputEnabled)
            refreshNetwork()
    }
    function enableNetworkDetails() {
        networkDetailsSubscriberCount++
    }
    function disableNetworkDetails() {
        networkDetailsSubscriberCount = Math.max(0, networkDetailsSubscriberCount - 1)
    }
    function resetNetworkSample(clearInterface) {
        activeNetworkRxRate = 0
        activeNetworkTxRate = 0
        previousNetworkRx = 0
        previousNetworkTx = 0
        previousNetworkSampleMs = 0
        if (clearInterface)
            previousNetworkInterface = ""
    }
    function refreshEthernetInfo() {
        if (!/^[A-Za-z0-9._:-]{1,64}$/.test(lanInterface)) {
            ethernetInfo = NetworkState.parseNmcliDeviceInfo("")
            if (ethernetProfileAwaitingRefresh) {
                ethernetProfileAwaitingRefresh = false
                ethernetProfileBusy = false
                ethernetProfilePendingUuid = ""
                if (ethernetProfileError.length === 0)
                    ethernetProfileError = "Ethernet interface unavailable"
            }
            return
        }
        if (ethernetInfoProcess.running)
            return
        ethernetInfoRequestedInterface = lanInterface
        ethernetInfoProcessGeneration = ethernetInfoRequestGeneration
        ethernetInfoProcessRefreshesProfile = ethernetProfileAwaitingRefresh
        // Only what the wired card shows plus what profile switching needs:
        // IP4.ADDRESS for the address, GENERAL.CON-UUID to know which profile
        // is live. Wi-Fi still asks for the full set because its panel shows it.
        ethernetInfoProcess.exec(["timeout", "2s", "nmcli", "--terse", "--escape", "no", "--fields", "GENERAL.CON-UUID,IP4.ADDRESS",
                                  "device", "show", lanInterface])
    }
    function refreshWifiInfo() {
        if (wifiInfoProcess.running)
            return
        if (!/^[A-Za-z0-9._:-]{1,64}$/.test(wifiInterface)) {
            wifiInfoRequestedInterface = ""
            wifiInfoAvailability = "idle"
            wifiInfo = NetworkState.parseNmcliDeviceInfo("")
            return
        }
        if (wifiInfoAvailability !== "available")
            wifiInfoAvailability = "loading"
        wifiInfoRequestedInterface = wifiInterface
        wifiInfoProcessGeneration = wifiInfoRequestGeneration
        // Only what the wireless card shows. The SSID comes from the network
        // list, and with no profile switching here the uuid is not needed.
        wifiInfoProcess.exec(["timeout", "2s", "nmcli", "--terse", "--escape", "no", "--fields", "IP4.ADDRESS",
                              "device", "show", wifiInterface])
    }
    function setEthernetProfileEnabled(profile) {
        const uuid = String(profile?.uuid || "")
        if (ethernetProfileActionProcess.running)
            return
        const action = NetworkState.ethernetProfileAction(ethernetInfo.activeUuid, uuid, ethernetProfileBusy)
        if (!action)
            return
        ethernetProfileBusy = true
        ethernetProfileAwaitingRefresh = false
        ethernetProfilePendingUuid = uuid
        ethernetProfileError = ""
        ethernetProfileActionProcessGeneration = ethernetProfileActionGeneration
        ethernetProfileActionProcess.exec(["timeout", "10s", "nmcli", "connection", action === "disable" ? "down" : "up",
                                           "uuid", uuid])
    }
    function refreshNetwork() {
        if (!networkThroughputEnabled || !activeNetworkInterface) {
            resetNetworkSample(true)
            return
        }
        if (previousNetworkInterface !== activeNetworkInterface) {
            previousNetworkInterface = activeNetworkInterface
            resetNetworkSample(false)
        }
        const rxText = FileViewState.safeText(networkRxBytes, "network RX bytes", true)
        const txText = FileViewState.safeText(networkTxBytes, "network TX bytes", true)
        if (rxText === null || txText === null) {
            resetNetworkSample(false)
            return
        }
        const now = Date.now()
        const rx = Number(rxText.trim())
        const tx = Number(txText.trim())
        const elapsed = previousNetworkSampleMs > 0 ? (now - previousNetworkSampleMs) / 1000 : 0
        if (!Number.isFinite(rx) || !Number.isFinite(tx)) {
            resetNetworkSample(false)
            return
        }
        if (previousNetworkRx > 0 && previousNetworkTx > 0 && Number.isFinite(elapsed) && elapsed > 0) {
            activeNetworkRxRate = Math.max(0, (rx - previousNetworkRx) / elapsed)
            activeNetworkTxRate = Math.max(0, (tx - previousNetworkTx) / elapsed)
        }
        previousNetworkRx = rx
        previousNetworkTx = tx
        previousNetworkSampleMs = now
    }
}
