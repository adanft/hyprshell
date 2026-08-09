import QtQuick
import Quickshell
import "../theme"
import "capabilities" as Capabilities
import "FileViewState.js" as FileViewState

Scope {
    id: root

    readonly property var theme: AppTheme
    readonly property string activeUserAvatarSource: activeUserAvatar.source
    readonly property string activeUserAvatarState: activeUserAvatar.state
    readonly property string time: Qt.formatDateTime(systemClock.date, "HH:mm")
    readonly property string date: Qt.formatDateTime(systemClock.date, "MM-dd")

    Capabilities.AudioService {
        id: audioService
    }
    Capabilities.BrightnessService {
        id: brightnessService
    }
    Capabilities.NetworkService {
        id: networkService
    }
    Capabilities.NotificationService {
        id: notificationService
        theme: root.theme
    }
    Capabilities.BatteryPowerService {
        id: batteryPowerService
    }
    Capabilities.BluetoothService {
        id: bluetoothService
    }
    Capabilities.SystemStatsService {
        id: systemStatsService
    }
    Capabilities.WorkspaceService {
        id: workspaceService
    }

    readonly property alias audio: audioService
    readonly property alias brightness: brightnessService
    readonly property alias network: networkService
    readonly property alias notification: notificationService
    readonly property alias notificationsCapability: notificationService
    readonly property alias notificationCapability: notificationService
    readonly property alias batteryPower: batteryPowerService
    readonly property alias bluetooth: bluetoothService
    readonly property alias systemStats: systemStatsService
    readonly property alias workspace: workspaceService

    readonly property alias networkRefreshMs: networkService.networkRefreshMs
    readonly property alias systemStatsRefreshMs: systemStatsService.systemStatsRefreshMs
    readonly property alias networkDevices: networkService.networkDevices
    readonly property alias lanDevice: networkService.lanDevice
    readonly property alias wifiDevice: networkService.wifiDevice
    readonly property alias lanInterface: networkService.lanInterface
    readonly property alias wifiInterface: networkService.wifiInterface
    property alias ethernetInfo: networkService.ethernetInfo
    property alias ethernetInfoRequestedInterface: networkService.ethernetInfoRequestedInterface
    property alias ethernetInfoRequestGeneration: networkService.ethernetInfoRequestGeneration
    property alias ethernetInfoProcessGeneration: networkService.ethernetInfoProcessGeneration
    property alias ethernetInfoProcessRefreshesProfile: networkService.ethernetInfoProcessRefreshesProfile
    readonly property alias wifiInfo: networkService.wifiInfo
    readonly property alias wifiInfoAvailability: networkService.wifiInfoAvailability
    property alias ethernetProfileBusy: networkService.ethernetProfileBusy
    property alias ethernetProfileAwaitingRefresh: networkService.ethernetProfileAwaitingRefresh
    property alias ethernetProfileActionGeneration: networkService.ethernetProfileActionGeneration
    property alias ethernetProfileActionProcessGeneration: networkService.ethernetProfileActionProcessGeneration
    property alias ethernetProfilePendingUuid: networkService.ethernetProfilePendingUuid
    property alias ethernetProfileError: networkService.ethernetProfileError
    property alias previousNetworkRx: networkService.previousNetworkRx
    property alias previousNetworkTx: networkService.previousNetworkTx
    property alias activeNetworkRxRate: networkService.activeNetworkRxRate
    property alias activeNetworkTxRate: networkService.activeNetworkTxRate
    property alias networkThroughputSubscriberCount: networkService.networkThroughputSubscriberCount
    property alias networkDetailsSubscriberCount: networkService.networkDetailsSubscriberCount
    readonly property alias networkThroughputEnabled: networkService.networkThroughputEnabled
    readonly property alias networkDetailsEnabled: networkService.networkDetailsEnabled
    readonly property alias lanUp: networkService.lanUp
    readonly property alias wifiUp: networkService.wifiUp
    readonly property alias activeNetworkInterface: networkService.activeNetworkInterface
    readonly property alias connectedWifiNetwork: networkService.connectedWifiNetwork
    readonly property alias wifiSignal: networkService.wifiSignal
    property alias previousNetworkInterface: networkService.previousNetworkInterface
    property alias previousNetworkSampleMs: networkService.previousNetworkSampleMs

    readonly property alias powerProfiles: batteryPowerService.powerProfiles
    readonly property alias batteries: batteryPowerService.batteries
    readonly property alias readyBatteries: batteryPowerService.readyBatteries
    readonly property alias batteryAvailable: batteryPowerService.batteryAvailable
    readonly property alias batteryCharging: batteryPowerService.batteryCharging
    readonly property alias batteryEmpty: batteryPowerService.batteryEmpty
    readonly property alias batteryFull: batteryPowerService.batteryFull
    readonly property alias batteryPendingCharge: batteryPowerService.batteryPendingCharge
    readonly property alias batteryPendingDischarge: batteryPowerService.batteryPendingDischarge
    readonly property alias batteryUnknown: batteryPowerService.batteryUnknown
    readonly property alias batteryLow: batteryPowerService.batteryLow
    readonly property alias batteryCritical: batteryPowerService.batteryCritical
    readonly property alias batteryLevel: batteryPowerService.batteryLevel
    readonly property alias powerProfile: batteryPowerService.powerProfile

    readonly property alias sink: audioService.sink
    readonly property alias source: audioService.source
    readonly property alias audioSources: audioService.audioSources
    readonly property alias audioOutputs: audioService.audioOutputs
    readonly property alias playbackStreams: audioService.playbackStreams
    readonly property alias sinkVolume: audioService.sinkVolume
    readonly property alias sinkMuted: audioService.sinkMuted
    readonly property alias microphoneAvailable: audioService.microphoneAvailable
    readonly property alias sourceVolume: audioService.sourceVolume
    readonly property alias sourceMuted: audioService.sourceMuted
    property alias quickVolume: audioService.quickVolume

    readonly property alias bluetoothAdapter: bluetoothService.bluetoothAdapter
    readonly property alias bluetoothAvailable: bluetoothService.bluetoothAvailable
    readonly property alias bluetoothPowered: bluetoothService.bluetoothPowered
    readonly property alias bluetoothConnectedCount: bluetoothService.bluetoothConnectedCount
    readonly property alias bluetoothDiscovering: bluetoothService.bluetoothDiscovering
    readonly property alias bluetoothAdapterName: bluetoothService.bluetoothAdapterName
    readonly property alias bluetoothDiscoverable: bluetoothService.bluetoothDiscoverable
    readonly property alias bluetoothDevices: bluetoothService.bluetoothDevices
    readonly property alias bluetoothBusy: bluetoothService.bluetoothBusy
    readonly property alias bluetoothError: bluetoothService.bluetoothError
    readonly property alias bluetoothPendingRevision: bluetoothService.bluetoothPendingRevision
    function bluetoothDevicePending(device) {
        return bluetoothService.bluetoothDevicePending(device)
    }

    readonly property alias notificationCount: notificationService.notificationCount
    readonly property alias hasNotifications: notificationService.hasNotifications
    readonly property alias notifications: notificationService.notifications
    readonly property alias minVisibleNotifications: notificationService.minVisibleNotifications
    readonly property alias notificationPopupEstimatedHeight: notificationService.notificationPopupEstimatedHeight
    readonly property alias maxNotificationHistory: notificationService.maxNotificationHistory
    readonly property alias notificationHistoryFile: notificationService.notificationHistoryFile
    readonly property alias focusedNotificationScreenName: notificationService.focusedNotificationScreenName
    readonly property alias maxPopupIngressPerSecond: notificationService.maxPopupIngressPerSecond
    readonly property alias maxNotificationQueueSize: notificationService.maxNotificationQueueSize
    property alias notificationTimeoutLow: notificationService.notificationTimeoutLow
    property alias notificationTimeoutNormal: notificationService.notificationTimeoutNormal
    property alias notificationTimeoutCritical: notificationService.notificationTimeoutCritical
    property alias notificationRules: notificationService.notificationRules
    property alias notificationQueue: notificationService.notificationQueue
    property alias visibleNotifications: notificationService.visibleNotifications
    property alias notificationPopupCapacity: notificationService.notificationPopupCapacity
    property alias notificationPopupSequence: notificationService.notificationPopupSequence
    property alias notificationIngressSecond: notificationService.notificationIngressSecond
    property alias notificationIngressCount: notificationService.notificationIngressCount
    property alias notificationTimeUpdateTick: notificationService.notificationTimeUpdateTick
    property alias notificationCenterOpen: notificationService.notificationCenterOpen
    property alias notificationHistory: notificationService.notificationHistory
    property alias notificationDnd: notificationService.notificationDnd

    readonly property alias statusWorkspaceIds: workspaceService.statusWorkspaceIds
    readonly property alias statusOccupiedWorkspaceIds: workspaceService.statusOccupiedWorkspaceIds
    readonly property alias statusUrgentWorkspaceIds: workspaceService.statusUrgentWorkspaceIds

    property alias cpuUsageSubscriberCount: systemStatsService.cpuUsageSubscriberCount
    property alias memoryUsageSubscriberCount: systemStatsService.memoryUsageSubscriberCount
    readonly property alias cpuUsageEnabled: systemStatsService.cpuUsageEnabled
    readonly property alias memoryUsageEnabled: systemStatsService.memoryUsageEnabled
    property alias cpuUsage: systemStatsService.cpuUsage
    property alias memoryUsage: systemStatsService.memoryUsage
    property alias previousCpuStats: systemStatsService.previousCpuStats

    property alias brightnessDevice: brightnessService.brightnessDevice
    property alias brightnessAvailable: brightnessService.brightnessAvailable
    property alias brightnessLevel: brightnessService.brightnessLevel
    property alias pendingBrightnessLevel: brightnessService.pendingBrightnessLevel
    readonly property alias brightnessWriteDebounceMs: brightnessService.brightnessWriteDebounceMs
    readonly property alias brightnessPath: brightnessService.brightnessPath
    readonly property alias maxBrightnessPath: brightnessService.maxBrightnessPath
    property alias brightnessDevicePath: brightnessService.brightnessDevicePath
    readonly property alias quickBrightnessPathValid: brightnessService.quickBrightnessPathValid
    readonly property alias quickBrightnessPath: brightnessService.quickBrightnessPath
    readonly property alias quickMaxBrightnessPath: brightnessService.quickMaxBrightnessPath
    property alias quickBrightness: brightnessService.quickBrightness
    property alias quickBrightnessMaximum: brightnessService.quickBrightnessMaximum
    property alias quickBrightnessRequestId: brightnessService.quickBrightnessRequestId

    ActiveUserAvatar {
        id: activeUserAvatar
    }
    // The bar renders HH:mm and MM-dd, so minute precision is the resolution
    // the display actually has. A second-precision clock wakes the process 59
    // extra times per minute to recompute an identical string.
    SystemClock {
        id: systemClock

        precision: SystemClock.Minutes
    }

    function refreshActiveUserAvatar() {
        return activeUserAvatar.refresh()
    }
    function safeFileViewText(fileView, label, reloadFile) {
        return FileViewState.safeText(fileView, label, reloadFile)
    }

    function toggleWifiEnabled() {
        return networkService.toggleWifiEnabled()
    }
    function enableNetworkThroughput() {
        return networkService.enableNetworkThroughput()
    }
    function disableNetworkThroughput() {
        return networkService.disableNetworkThroughput()
    }
    function enableNetworkDetails() {
        return networkService.enableNetworkDetails()
    }
    function disableNetworkDetails() {
        return networkService.disableNetworkDetails()
    }
    function resetNetworkSample(clearInterface) {
        return networkService.resetNetworkSample(clearInterface)
    }
    function refreshEthernetInfo() {
        return networkService.refreshEthernetInfo()
    }
    function refreshWifiInfo() {
        return networkService.refreshWifiInfo()
    }
    function setEthernetProfileEnabled(profile) {
        return networkService.setEthernetProfileEnabled(profile)
    }
    function refreshNetwork() {
        return networkService.refreshNetwork()
    }

    function enableCpuUsage() {
        return systemStatsService.enableCpuUsage()
    }
    function disableCpuUsage() {
        return systemStatsService.disableCpuUsage()
    }
    function enableMemoryUsage() {
        return systemStatsService.enableMemoryUsage()
    }
    function disableMemoryUsage() {
        return systemStatsService.disableMemoryUsage()
    }
    function refreshSystemStats() {
        return systemStatsService.refreshSystemStats()
    }
    function updateCpuUsage(text) {
        return systemStatsService.updateCpuUsage(text)
    }
    function updateMemoryUsage(text) {
        return systemStatsService.updateMemoryUsage(text)
    }

    function focusWorkspace(workspaceId) {
        return workspaceService.focusWorkspace(workspaceId)
    }
    function statusWorkspaceIdsForMonitor(monitor) {
        return workspaceService.statusWorkspaceIdsForMonitor(monitor)
    }

    function toggleBluetoothDiscoverable() {
        return bluetoothService.toggleBluetoothDiscoverable()
    }
    function toggleBluetoothPowered() {
        return bluetoothService.toggleBluetoothPowered()
    }
    function scanBluetooth() {
        return bluetoothService.scanBluetooth()
    }
    function setBluetoothScanning(enabled) {
        return bluetoothService.setBluetoothScanning(enabled)
    }
    function connectBluetoothDevice(device) {
        return bluetoothService.connectBluetoothDevice(device)
    }
    function disconnectBluetoothDevice(device) {
        return bluetoothService.disconnectBluetoothDevice(device)
    }
    function pairBluetoothDevice(device) {
        return bluetoothService.pairBluetoothDevice(device)
    }
    function forgetBluetoothDevice(device) {
        return bluetoothService.forgetBluetoothDevice(device)
    }
    function toggleMute(isSource) {
        return audioService.toggleMute(isSource)
    }
    function setSourceVolume(percent) {
        return audioService.setSourceVolume(percent)
    }
    function selectAudioSource(node) {
        return audioService.selectAudioSource(node)
    }
    function selectAudioSink(node) {
        return audioService.selectAudioSink(node)
    }
    function togglePlaybackStreamMute(node) {
        return audioService.togglePlaybackStreamMute(node)
    }
    function requestPlaybackStreamVolume(node, percent) {
        return audioService.requestPlaybackStreamVolume(node, percent)
    }
    function changeVolume(isSource, delta) {
        return audioService.changeVolume(isSource, delta)
    }
    function refreshQuickVolume() {
        return audioService.refreshQuickVolume()
    }
    function requestSinkVolume(percent, requestId) {
        return audioService.requestSinkVolume(percent, requestId)
    }

    function detectBrightness() {
        return brightnessService.detectBrightness()
    }
    function detectBrightnessDevice(output) {
        return brightnessService.detectBrightnessDevice(output)
    }
    function clearBrightnessState() {
        return brightnessService.clearBrightnessState()
    }
    function updateBrightnessFromFiles(reloadFiles) {
        return brightnessService.updateBrightnessFromFiles(reloadFiles)
    }
    function setBrightness(percent) {
        return brightnessService.setBrightness(percent)
    }
    function scheduleBrightnessWrite() {
        return brightnessService.scheduleBrightnessWrite()
    }
    function flushBrightnessWrite() {
        return brightnessService.flushBrightnessWrite()
    }
    function changeBrightness(delta) {
        return brightnessService.changeBrightness(delta)
    }
    function refreshQuickBrightness(reloadFiles) {
        return brightnessService.refreshQuickBrightness(reloadFiles)
    }
    function failQuickBrightnessRead(message) {
        return brightnessService.failQuickBrightnessRead(message)
    }
    function requestBrightness(percent, requestId) {
        return brightnessService.requestBrightness(percent, requestId)
    }
    function failQuickBrightnessRequest(code, message) {
        return brightnessService.failQuickBrightnessRequest(code, message)
    }

    function computeBatteryLevel() {
        return batteryPowerService.computeBatteryLevel()
    }
    function hasBatteryState(state) {
        return batteryPowerService.hasBatteryState(state)
    }
    function normalizePercentage(value) {
        return batteryPowerService.normalizePercentage(value)
    }
    function nextPowerProfile() {
        return batteryPowerService.nextPowerProfile()
    }
    function profileSlug(profile) {
        return batteryPowerService.profileSlug(profile)
    }

    function dismissNotifications() {
        return notificationService.dismissNotifications()
    }
    function dismissNotificationHistoryEntry(entry) {
        return notificationService.dismissNotificationHistoryEntry(entry)
    }
    function setNotificationCenterOpen(open) {
        return notificationService.setNotificationCenterOpen(open)
    }
    function clearNotificationPopups() {
        return notificationService.clearNotificationPopups()
    }
    function toggleNotificationDnd() {
        return notificationService.toggleNotificationDnd()
    }
    function enqueueNotificationPopup(notification, policy) {
        return notificationService.enqueueNotificationPopup(notification, policy)
    }
    function shouldShowNotificationPopup(notification, policy) {
        return notificationService.shouldShowNotificationPopup(notification, policy)
    }
    function createNotificationPopup(notification, policy) {
        return notificationService.createNotificationPopup(notification, policy)
    }
    function addNotificationToHistory(notification, policy) {
        return notificationService.addNotificationToHistory(notification, policy)
    }
    function createNotificationHistoryEntry(notification, policy) {
        return notificationService.createNotificationHistoryEntry(notification, policy)
    }
    function persistentNotificationImage(source) {
        return notificationService.persistentNotificationImage(source)
    }
    function scheduleNotificationHistorySave() {
        return notificationService.scheduleNotificationHistorySave()
    }
    function saveNotificationHistory() {
        return notificationService.saveNotificationHistory()
    }
    function loadNotificationHistory() {
        return notificationService.loadNotificationHistory()
    }
    function processNotificationPopupQueue() {
        return notificationService.processNotificationPopupQueue()
    }
    function setNotificationPopupAvailableHeight(height) {
        return notificationService.setNotificationPopupAvailableHeight(height)
    }
    function closeNotificationPopup(id) {
        return notificationService.closeNotificationPopup(id)
    }
    function invokeNotificationPopupAction(id, action) {
        return notificationService.invokeNotificationPopupAction(id, action)
    }
    function notificationPopupTimeout(urgency) {
        return notificationService.notificationPopupTimeout(urgency)
    }
    function notificationTimeText(popup) {
        return notificationService.notificationTimeText(popup)
    }
    function formatNotificationTime(date) {
        return notificationService.formatNotificationTime(date)
    }
    function evaluateNotificationPolicy(notification) {
        return notificationService.evaluateNotificationPolicy(notification)
    }
    function matchesNotificationRule(rule, notification) {
        return notificationService.matchesNotificationRule(rule, notification)
    }
    function matchesRuleValue(actual, expected) {
        return notificationService.matchesRuleValue(actual, expected)
    }
    function coerceNotificationUrgency(value, fallback) {
        return notificationService.coerceNotificationUrgency(value, fallback)
    }
    function stripImages(text) {
        return notificationService.stripImages(text)
    }
    function escapeHtml(text) {
        return notificationService.escapeHtml(text)
    }
    function resolveHtmlBody(body) {
        return notificationService.resolveHtmlBody(body)
    }
}
