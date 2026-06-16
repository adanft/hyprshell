import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../theme"

Scope {
    id: service

    readonly property var theme: AppTheme {}
    readonly property int networkRefreshMs: 2000
    readonly property var networkDevices: Networking.devices?.values ?? []
    readonly property var lanDevice: networkDevices.find(device => device.type === DeviceType.Wired) ?? null
    readonly property var wifiDevice: networkDevices.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property string lanInterface: lanDevice?.name ?? ""
    readonly property string wifiInterface: wifiDevice?.name ?? ""
    readonly property var powerProfiles: [PowerProfile.Performance, PowerProfile.Balanced, PowerProfile.PowerSaver]
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var batteries: UPower.devices.values.filter(device => device && device.isLaptopBattery)
    readonly property var readyBatteries: batteries.filter(device => device.ready)
    readonly property bool batteryAvailable: batteries.length > 0
    readonly property bool batteryCharging: hasBatteryState(UPowerDeviceState.Charging)
    readonly property bool batteryEmpty: hasBatteryState(UPowerDeviceState.Empty)
    readonly property bool batteryFull: readyBatteries.length > 0 && readyBatteries.every(device => device.state === UPowerDeviceState.FullyCharged)
    readonly property bool batteryPendingCharge: hasBatteryState(UPowerDeviceState.PendingCharge)
    readonly property bool batteryPendingDischarge: hasBatteryState(UPowerDeviceState.PendingDischarge)
    readonly property bool batteryUnknown: !batteryAvailable || readyBatteries.length === 0 || readyBatteries.every(device => device.state === UPowerDeviceState.Unknown)
    readonly property bool batteryLow: !batteryUnknown && batteryLevel <= 30
    readonly property bool batteryCritical: !batteryUnknown && batteryLevel <= 15
    readonly property int batteryLevel: computeBatteryLevel()
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothAvailable: bluetoothAdapter !== null
    readonly property bool bluetoothPowered: bluetoothAvailable ? bluetoothAdapter.enabled : false
    readonly property int bluetoothConnectedCount: {
        if (!bluetoothAdapter || !bluetoothAdapter.devices)
            return 0

        let count = 0
        bluetoothAdapter.devices.values.forEach(device => {
            if (device && device.connected)
                count++
        })
        return count
    }
    readonly property int notificationCount: notificationHistory.length
    readonly property bool hasNotifications: notificationCount > 0
    readonly property var notifications: notificationHistory
    readonly property int minVisibleNotifications: 1
    readonly property int notificationPopupEstimatedHeight: theme.sizing.notificationPopupEstimatedHeight
    readonly property int maxNotificationHistory: 100
    readonly property string notificationHistoryFile: `${Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`}/statusbar-notifications.json`
    readonly property string focusedNotificationScreenName: Hyprland.focusedMonitor?.name || (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
    readonly property int maxPopupIngressPerSecond: 6
    readonly property int maxNotificationQueueSize: 32
    property int notificationTimeoutLow: 5000
    property int notificationTimeoutNormal: 10000
    property int notificationTimeoutCritical: 0
    property var notificationRules: []
    property var notificationQueue: []
    property var visibleNotifications: []
    property int notificationPopupCapacity: 4
    property int notificationPopupSequence: 0
    property int notificationIngressSecond: 0
    property int notificationIngressCount: 0
    property bool notificationTimeUpdateTick: false
    property bool notificationCenterOpen: false
    property var notificationHistory: []

    property string time: ""
    property string date: ""
    readonly property string powerProfile: profileSlug(PowerProfiles.profile)
    readonly property int sinkVolume: Math.round((sink?.audio?.volume ?? 0) * 100)
    readonly property bool sinkMuted: sink?.audio?.muted ?? false
    readonly property int sourceVolume: Math.round((source?.audio?.volume ?? 0) * 100)
    readonly property bool sourceMuted: source?.audio?.muted ?? false
    property real previousNetworkRx: 0
    property real previousNetworkTx: 0
    property real activeNetworkRxRate: 0
    property real activeNetworkTxRate: 0
    property bool networkThroughputEnabled: false
    readonly property bool lanUp: lanDevice?.connected ?? false
    readonly property bool wifiUp: wifiDevice?.connected ?? false
    readonly property string activeNetworkInterface: lanUp ? lanInterface : (wifiUp ? wifiInterface : "")
    readonly property var connectedWifiNetwork: {
        const networks = wifiDevice?.networks?.values ?? []
        return networks.find(network => network.connected) ?? null
    }
    readonly property int wifiSignal: Math.round((connectedWifiNetwork?.signalStrength ?? 0) * 100)
    property bool notificationDnd: false
    property string previousNetworkInterface: ""
    property real previousNetworkSampleMs: 0
    property string brightnessDevice: ""
    property bool brightnessAvailable: false
    property int brightnessLevel: 0
    readonly property string brightnessPath: brightnessDevice.length > 0 ? `/sys/class/backlight/${brightnessDevice}/brightness` : ""
    readonly property string maxBrightnessPath: brightnessDevice.length > 0 ? `/sys/class/backlight/${brightnessDevice}/max_brightness` : ""

    FileView {
        id: notificationHistoryFileView
        path: service.notificationHistoryFile
        printErrors: false
        onLoaded: service.loadNotificationHistory()
        onLoadFailed: error => {
            if (error === 2)
                notificationHistoryFileView.writeAdapter()
        }

        JsonAdapter {
            id: notificationHistoryAdapter
            property var notifications: []
        }
    }

    FileView {
        id: networkRxBytes
        path: `/sys/class/net/${service.activeNetworkInterface}/statistics/rx_bytes`
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: networkTxBytes
        path: `/sys/class/net/${service.activeNetworkInterface}/statistics/tx_bytes`
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: brightnessValueFile

        path: service.brightnessPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: service.updateBrightnessFromFiles()
        onLoadFailed: service.brightnessAvailable = false
        onFileChanged: reload()
    }

    FileView {
        id: maxBrightnessValueFile

        path: service.maxBrightnessPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: service.updateBrightnessFromFiles()
        onLoadFailed: service.brightnessAvailable = false
        onFileChanged: reload()
    }

    PwObjectTracker {
        objects: [service.sink, service.source]
    }

    NotificationServer {
        id: notificationServer

        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            const policy = service.evaluateNotificationPolicy(notification)
            if (policy.block || service.notificationDnd) {
                notification.dismiss()
                return
            }

            notification.tracked = !notification.transient && !policy.hideFromCenter

            if (!notification.transient && !policy.hideFromCenter)
                service.addNotificationToHistory(notification, policy)

            if (policy.hide) {
                notification.dismiss()
                return
            }

            if (!policy.disablePopup && !service.notificationCenterOpen)
                service.enqueueNotificationPopup(notification, policy)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            service.updateClock()
        }
    }

    Timer {
        interval: service.networkRefreshMs
        running: service.networkThroughputEnabled
        repeat: true
        onTriggered: {
            service.refreshNetwork()
        }
    }

    Timer {
        interval: 30000
        running: notificationCenterOpen || notificationHistory.length > 0 || visibleNotifications.length > 0 || notificationQueue.length > 0
        repeat: true
        onTriggered: notificationTimeUpdateTick = !notificationTimeUpdateTick
    }

    Process {
        id: brightnessDetectProcess

        stdout: StdioCollector {
            onStreamFinished: service.detectBrightnessDevice(this.text)
        }
    }

    Process {
        id: brightnessWriteProcess
    }

    Component.onCompleted: {
        updateClock()
        refreshNetwork()
        detectBrightness()
    }

    function updateClock() {
        const now = new Date()
        const month = pad(now.getMonth() + 1)
        const day = pad(now.getDate())

        time = `${pad(now.getHours())}:${pad(now.getMinutes())}`
        date = `${month}-${day}`
    }

    function pad(value) {
        return String(value).padStart(2, "0")
    }

    function toggleMute(isSource) {
        const node = isSource ? source : sink
        if (node?.audio)
            node.audio.muted = !node.audio.muted
    }

    function changeVolume(isSource, delta) {
        const node = isSource ? source : sink
        if (!node?.audio)
            return

        const currentVolume = Math.round(node.audio.volume * 100)
        const nextVolume = Math.max(0, Math.min(currentVolume + delta, 100))

        node.audio.volume = nextVolume / 100
        node.audio.muted = false
    }

    function computeBatteryLevel() {
        if (readyBatteries.length === 0)
            return 0

        const capacity = readyBatteries.reduce((sum, device) => sum + device.energyCapacity, 0)
        let level = 0

        if (capacity > 0) {
            const energy = readyBatteries.reduce((sum, device) => sum + device.energy, 0)
            level = Math.round((energy * 100) / capacity)
        } else {
            const percentage = readyBatteries.reduce((sum, device) => sum + normalizePercentage(device.percentage), 0) / readyBatteries.length
            level = Math.round(percentage)
        }

        return Math.max(0, Math.min(100, level))
    }

    function hasBatteryState(state) {
        return readyBatteries.some(device => device.state === state)
    }

    function normalizePercentage(value) {
        const percentage = Number(value) || 0
        return percentage <= 1 ? percentage * 100 : percentage
    }

    function detectBrightness() {
        if (brightnessDevice.length > 0) {
            updateBrightnessFromFiles()
            return
        }

        brightnessDetectProcess.exec(["sh", "-c", "brightnessctl -m 2>/dev/null || true"])
    }

    function detectBrightnessDevice(output) {
        const fields = String(output || "").trim().split(",")
        if (fields.length === 0 || fields[0].length === 0) {
            brightnessAvailable = false
            return
        }

        brightnessDevice = fields[0]
        const percentageMatch = String(output || "").match(/(\d+)%/)
        if (percentageMatch)
            brightnessLevel = Math.max(0, Math.min(100, parseInt(percentageMatch[1], 10)))

        Qt.callLater(updateBrightnessFromFiles)
    }

    function updateBrightnessFromFiles() {
        if (brightnessDevice.length === 0 || !brightnessValueFile.loaded || !maxBrightnessValueFile.loaded)
            return

        const current = Number(String(brightnessValueFile.text()).trim())
        const maximum = Number(String(maxBrightnessValueFile.text()).trim())
        if (!Number.isFinite(current) || !Number.isFinite(maximum) || maximum <= 0) {
            brightnessAvailable = false
            return
        }

        brightnessAvailable = true
        brightnessLevel = Math.max(0, Math.min(100, Math.round((current * 100) / maximum)))
    }

    function setBrightness(percent) {
        const next = Math.max(0, Math.min(100, Math.round(percent)))
        if (next === brightnessLevel)
            return

        brightnessLevel = next
        brightnessWriteProcess.exec(["brightnessctl", "set", `${next}%`])
    }

    function changeBrightness(delta) {
        setBrightness(brightnessLevel + delta)
    }

    function refreshNetwork() {
        if (!networkThroughputEnabled || !activeNetworkInterface) {
            activeNetworkRxRate = 0
            activeNetworkTxRate = 0
            previousNetworkRx = 0
            previousNetworkTx = 0
            previousNetworkInterface = ""
            previousNetworkSampleMs = 0
            return
        }

        if (previousNetworkInterface !== activeNetworkInterface) {
            previousNetworkInterface = activeNetworkInterface
            previousNetworkRx = 0
            previousNetworkTx = 0
            activeNetworkRxRate = 0
            activeNetworkTxRate = 0
            previousNetworkSampleMs = 0
        }

        networkRxBytes.reload()
        networkTxBytes.reload()

        const now = Date.now()
        const rx = Number(networkRxBytes.text().trim())
        const tx = Number(networkTxBytes.text().trim())
        const elapsedSeconds = previousNetworkSampleMs > 0 ? (now - previousNetworkSampleMs) / 1000 : 0

        if (!Number.isFinite(rx) || !Number.isFinite(tx)) {
            activeNetworkRxRate = 0
            activeNetworkTxRate = 0
        } else if (previousNetworkRx > 0 && previousNetworkTx > 0 && Number.isFinite(elapsedSeconds) && elapsedSeconds > 0) {
            activeNetworkRxRate = Math.max(0, (rx - previousNetworkRx) / elapsedSeconds)
            activeNetworkTxRate = Math.max(0, (tx - previousNetworkTx) / elapsedSeconds)
        }

        previousNetworkRx = Number.isFinite(rx) ? rx : 0
        previousNetworkTx = Number.isFinite(tx) ? tx : 0
        previousNetworkSampleMs = now
    }

    function dismissNotifications() {
        notificationServer.trackedNotifications.values.forEach(notification => notification.dismiss())
        notificationHistory = []
        saveNotificationHistory()
        notificationQueue = []
        visibleNotifications = []
    }

    function dismissNotificationHistoryEntry(entry) {
        if (!entry)
            return

        if (entry.notification && entry.notification.dismiss)
            entry.notification.dismiss()

        notificationHistory = notificationHistory.filter(item => item && item.id !== entry.id)
        saveNotificationHistory()
    }

    function setNotificationCenterOpen(open) {
        notificationCenterOpen = open

        if (notificationCenterOpen)
            clearNotificationPopups()
    }

    function clearNotificationPopups() {
        notificationQueue = []
        visibleNotifications = []
    }

    function toggleNotificationDnd() {
        notificationDnd = !notificationDnd

        if (notificationDnd) {
            notificationQueue = []
            visibleNotifications = []
        }
    }

    function enqueueNotificationPopup(notification, policy) {
        if (!shouldShowNotificationPopup(notification, policy))
            return

        const popup = createNotificationPopup(notification, policy)
        let queued = notificationQueue.slice()

        if (queued.length >= maxNotificationQueueSize) {
            let victimIndex = queued.findIndex(item => item && item.urgency !== NotificationUrgency.Critical)
            if (victimIndex < 0 && popup.urgency !== NotificationUrgency.Critical)
                return
            if (victimIndex < 0)
                victimIndex = 0
            queued.splice(victimIndex, 1)
        }

        notificationQueue = queued.concat([popup])
        processNotificationPopupQueue()
    }

    function shouldShowNotificationPopup(notification, policy) {
        const now = Date.now()
        const currentSecond = Math.floor(now / 1000)
        const urgency = policy && typeof policy.urgency === "number" ? policy.urgency : notification.urgency

        if (notificationIngressSecond !== currentSecond) {
            notificationIngressSecond = currentSecond
            notificationIngressCount = 0
        }

        if (urgency !== NotificationUrgency.Critical && notificationIngressCount >= maxPopupIngressPerSecond)
            return false

        notificationIngressCount += 1

        return true
    }

    function createNotificationPopup(notification, policy) {
        notificationPopupSequence += 1

        const appName = notification.appName || "App"
        const appIcon = notification.appIcon || ""
        const desktopEntry = notification.desktopEntry || ""
        const image = notification.image || ""
        const body = stripImages(notification.body || "")

        return {
            id: notificationPopupSequence,
            notification: notification,
            summary: stripImages(notification.summary || "Notification"),
            body: body,
            htmlBody: resolveHtmlBody(body),
            appName: appName,
            appIcon: appIcon,
            desktopEntry: desktopEntry,
            image: image,
            urgency: policy && typeof policy.urgency === "number" ? policy.urgency : notification.urgency,
            actions: notification.actions || [],
            transient: notification.transient,
            createdAt: Date.now()
        }
    }

    function addNotificationToHistory(notification, policy) {
        const entry = createNotificationHistoryEntry(notification, policy)
        let history = notificationHistory.slice()
        history.unshift(entry)

        if (history.length > maxNotificationHistory)
            history = history.slice(0, maxNotificationHistory)

        notificationHistory = history
        saveNotificationHistory()
    }

    function createNotificationHistoryEntry(notification, policy) {
        const body = stripImages(notification.body || "")
        const createdAt = Date.now()

        return {
            id: `${createdAt}-${Math.random()}`,
            notification: notification,
            summary: stripImages(notification.summary || "Notification"),
            body: body,
            htmlBody: resolveHtmlBody(body),
            appName: notification.appName || "App",
            appIcon: notification.appIcon || "",
            desktopEntry: notification.desktopEntry || "",
            image: notification.image || "",
            urgency: policy && typeof policy.urgency === "number" ? policy.urgency : notification.urgency,
            actions: [],
            createdAt: createdAt,
            timestamp: createdAt
        }
    }

    function saveNotificationHistory() {
        notificationHistoryAdapter.notifications = notificationHistory.map(item => ({
            id: item.id,
            summary: item.summary || "Notification",
            body: item.body || "",
            htmlBody: item.htmlBody || resolveHtmlBody(item.body || ""),
            appName: item.appName || "App",
            appIcon: item.appIcon || "",
            desktopEntry: item.desktopEntry || "",
            image: item.image || "",
            urgency: typeof item.urgency === "number" ? item.urgency : NotificationUrgency.Normal,
            actions: [],
            createdAt: item.createdAt || item.timestamp || Date.now(),
            timestamp: item.timestamp || item.createdAt || Date.now()
        }))
        notificationHistoryFileView.writeAdapter()
    }

    function loadNotificationHistory() {
        notificationHistory = (notificationHistoryAdapter.notifications || []).map(item => ({
            id: item.id || `${item.timestamp || Date.now()}-${Math.random()}`,
            summary: item.summary || "Notification",
            body: item.body || "",
            htmlBody: item.htmlBody || resolveHtmlBody(item.body || ""),
            appName: item.appName || "App",
            appIcon: item.appIcon || "",
            desktopEntry: item.desktopEntry || "",
            image: item.image || "",
            urgency: typeof item.urgency === "number" ? item.urgency : NotificationUrgency.Normal,
            actions: [],
            createdAt: item.createdAt || item.timestamp || Date.now(),
            timestamp: item.timestamp || item.createdAt || Date.now()
        }))
    }

    function processNotificationPopupQueue() {
        let visible = visibleNotifications.slice()
        let queued = notificationQueue.slice()

        const capacity = Math.max(minVisibleNotifications, notificationPopupCapacity)

        while (visible.length > capacity)
            queued.unshift(visible.pop())

        while (visible.length < capacity && queued.length > 0)
            visible.unshift(queued.shift())

        visibleNotifications = visible
        notificationQueue = queued
    }

    function setNotificationPopupAvailableHeight(height) {
        const availableHeight = Math.max(0, height || 0)
        const popupSpacing = theme.spacing.notificationPopupSpacing
        const slotHeight = notificationPopupEstimatedHeight + popupSpacing
        const capacity = Math.max(minVisibleNotifications, Math.floor((availableHeight + popupSpacing) / slotHeight))

        if (notificationPopupCapacity === capacity)
            return

        notificationPopupCapacity = capacity
        processNotificationPopupQueue()
    }

    function closeNotificationPopup(id) {
        visibleNotifications = visibleNotifications.filter(popup => popup.id !== id)
        processNotificationPopupQueue()
    }

    function invokeNotificationPopupAction(id, action) {
        if (action && action.invoke)
            action.invoke()

        closeNotificationPopup(id)
    }

    function notificationPopupTimeout(urgency) {
        switch (urgency) {
        case NotificationUrgency.Low:
            return notificationTimeoutLow
        case NotificationUrgency.Critical:
            return notificationTimeoutCritical
        default:
            return notificationTimeoutNormal
        }
    }

    function notificationTimeText(popup) {
        notificationTimeUpdateTick

        const timestamp = popup ? (popup.createdAt || popup.timestamp) : 0
        if (!timestamp)
            return "now"

        const time = new Date(timestamp)
        const now = new Date()
        const diff = now.getTime() - time.getTime()
        const minutes = Math.floor(diff / 60000)
        const hours = Math.floor(minutes / 60)

        if (hours < 1)
            return minutes < 1 ? "now" : `${minutes}m ago`

        const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const timeDate = new Date(time.getFullYear(), time.getMonth(), time.getDate())
        const daysDiff = Math.floor((nowDate - timeDate) / (1000 * 60 * 60 * 24))

        if (daysDiff === 0)
            return formatNotificationTime(time)

        return `${time.toLocaleDateString(Qt.locale(), "dddd")}, ${formatNotificationTime(time)}`
    }

    function formatNotificationTime(date) {
        return date.toLocaleTimeString(Qt.locale(), "HH:mm")
    }

    function evaluateNotificationPolicy(notification) {
        const policy = {
            block: false,
            disablePopup: false,
            hideFromCenter: false,
            hide: false,
            mute: false,
            urgency: typeof notification.urgency === "number" ? notification.urgency : NotificationUrgency.Normal
        }

        for (const rule of notificationRules) {
            if (!matchesNotificationRule(rule, notification))
                continue

            const action = String(rule.action || "default").toLowerCase()
            if (action === "block" || action === "ignore")
                policy.block = true
            else if (action === "hide" || action === "no_popup")
                policy.hide = true
            else if (action === "mute")
                policy.mute = true
            else if (action === "popup_only")
                policy.hideFromCenter = true
            else if (action === "disable_popup")
                policy.disablePopup = true

            if (rule.urgency !== undefined)
                policy.urgency = coerceNotificationUrgency(rule.urgency, policy.urgency)

            return policy
        }

        return policy
    }

    function matchesNotificationRule(rule, notification) {
        const fields = {
            appName: notification.appName || "",
            desktopEntry: notification.desktopEntry || "",
            summary: notification.summary || "",
            body: notification.body || ""
        }

        for (const key of Object.keys(rule)) {
            if (["action", "urgency"].includes(key))
                continue
            if (!matchesRuleValue(fields[key] || "", rule[key]))
                return false
        }

        return true
    }

    function matchesRuleValue(actual, expected) {
        if (expected === undefined || expected === null || expected === "")
            return true
        return String(actual).toLowerCase().includes(String(expected).toLowerCase())
    }

    function coerceNotificationUrgency(value, fallback) {
        if (typeof value === "number")
            return value

        const normalized = String(value).toLowerCase()
        if (normalized === "low")
            return NotificationUrgency.Low
        if (normalized === "critical")
            return NotificationUrgency.Critical
        if (normalized === "normal")
            return NotificationUrgency.Normal
        return fallback
    }

    function stripImages(text) {
        return String(text || "").replace(/<img\b[^>]*>/gi, "")
    }

    function escapeHtml(text) {
        return String(text || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;")
    }

    function resolveHtmlBody(body) {
        const escaped = escapeHtml(body)
        return escaped.replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1">$1</a>')
    }

    function nextPowerProfile() {
        const currentIndex = Math.max(0, powerProfiles.indexOf(PowerProfiles.profile))
        const next = powerProfiles[(currentIndex + 1) % powerProfiles.length]

        PowerProfiles.profile = next
    }

    function profileSlug(profile) {
        switch (profile) {
        case PowerProfile.Performance:
            return "performance"
        case PowerProfile.PowerSaver:
            return "power-saver"
        default:
            return "balanced"
        }
    }

}
