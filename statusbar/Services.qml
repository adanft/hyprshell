import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Notifications

Scope {
    id: service

    readonly property string lanInterface: "enp6s0"
    readonly property string wifiInterface: "wlan0"
    readonly property var powerProfiles: ["performance", "balanced", "power-saver"]
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
    readonly property int notificationCount: notificationServer.trackedNotifications.values.length
    readonly property bool hasNotifications: notificationCount > 0
    readonly property var notifications: notificationServer.trackedNotifications.values
    readonly property int maxVisibleNotifications: 4
    readonly property int maxPopupIngressPerSecond: 6
    readonly property int maxNotificationQueueSize: 32
    readonly property int notificationDedupBurstMs: 5000
    property int notificationTimeoutLow: 5000
    property int notificationTimeoutNormal: 10000
    property int notificationTimeoutCritical: 0
    property var notificationRules: []
    property var notificationQueue: []
    property var visibleNotifications: []
    property var recentNotificationDedupKeys: []
    property int notificationPopupSequence: 0
    property int notificationIngressSecond: 0
    property int notificationIngressCount: 0
    property bool notificationTimeUpdateTick: false
    property bool notificationCenterOpen: false

    property string time: ""
    property string date: ""
    property string powerProfile: ""
    property int sinkVolume: 0
    property bool sinkMuted: false
    property int sourceVolume: 0
    property bool sourceMuted: false
    property real previousLanRx: 0
    property real previousLanTx: 0
    property real lanRxRate: 0
    property real lanTxRate: 0
    property bool lanUp: false
    property bool wifiUp: false
    property int wifiSignal: 0
    property bool notificationDnd: false

    FileView {
        id: lanState
        path: `/sys/class/net/${service.lanInterface}/operstate`
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: wifiState
        path: `/sys/class/net/${service.wifiInterface}/operstate`
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: lanRxBytes
        path: `/sys/class/net/${service.lanInterface}/statistics/rx_bytes`
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: lanTxBytes
        path: `/sys/class/net/${service.lanInterface}/statistics/tx_bytes`
        blockLoading: true
        printErrors: false
    }

    Process {
        id: sinkVolumeProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: service.parseAudio(text, false)
        }
    }

    Process {
        id: sourceVolumeProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: service.parseAudio(text, true)
        }
    }

    Process {
        id: wifiProcess
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "dev", "wifi"]

        stdout: StdioCollector {
            onStreamFinished: service.parseWifi(text)
        }
    }

    Process {
        id: powerProfileProcess
        command: ["powerprofilesctl", "get"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: service.powerProfile = text.trim()
        }
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
            if (policy.drop || service.notificationDnd) {
                notification.dismiss()
                return
            }

            notification.tracked = !notification.transient && !policy.hideFromCenter

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
            service.refreshAudio()
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            service.refreshNetwork()
            service.refreshPowerProfile()
        }
    }

    Timer {
        interval: 30000
        running: visibleNotifications.length > 0 || notificationQueue.length > 0
        repeat: true
        onTriggered: notificationTimeUpdateTick = !notificationTimeUpdateTick
    }

    Timer {
        id: audioRefreshTimer
        interval: 80
        onTriggered: service.refreshAudio()
    }

    Timer {
        id: powerRefreshTimer
        interval: 120
        onTriggered: service.refreshPowerProfile()
    }

    Component.onCompleted: {
        updateClock()
        refreshAudio()
        refreshNetwork()
        refreshPowerProfile()
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

    function refreshAudio() {
        sinkVolumeProcess.running = true
        sourceVolumeProcess.running = true
    }

    function parseAudio(output, isSource) {
        const match = output.match(/Volume:\s+([0-9.]+)/)
        const volume = match ? Math.round(parseFloat(match[1]) * 100) : 0
        const muted = output.includes("MUTED")

        if (isSource) {
            sourceVolume = volume
            sourceMuted = muted
        } else {
            sinkVolume = volume
            sinkMuted = muted
        }
    }

    function toggleMute(isSource) {
        if (isSource)
            sourceMuted = !sourceMuted
        else
            sinkMuted = !sinkMuted

        Quickshell.execDetached(["wpctl", "set-mute", isSource ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@", "toggle"])
        audioRefreshTimer.restart()
    }

    function changeVolume(isSource, delta) {
        const currentVolume = isSource ? sourceVolume : sinkVolume
        const nextVolume = Math.max(0, Math.min(currentVolume + delta, 100))

        if (isSource) {
            sourceVolume = nextVolume
            sourceMuted = false
        } else {
            sinkVolume = nextVolume
            sinkMuted = false
        }

        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", isSource ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@", `${nextVolume}%`])
        audioRefreshTimer.restart()
    }

    function refreshNetwork() {
        lanState.reload()
        wifiState.reload()
        lanRxBytes.reload()
        lanTxBytes.reload()

        lanUp = lanState.text().trim() === "up"
        wifiUp = wifiState.text().trim() === "up"

        const rx = Number(lanRxBytes.text().trim())
        const tx = Number(lanTxBytes.text().trim())

        if (previousLanRx > 0 && previousLanTx > 0) {
            lanRxRate = (rx - previousLanRx) / 5
            lanTxRate = (tx - previousLanTx) / 5
        }

        previousLanRx = rx
        previousLanTx = tx

        if (wifiUp)
            wifiProcess.running = true
        else
            wifiSignal = 0
    }

    function parseWifi(output) {
        const active = output.split("\n").find(line => line.startsWith("*:"))
        wifiSignal = active ? Number(active.split(":")[1]) : 0
    }

    function refreshPowerProfile() {
        powerProfileProcess.running = true
    }

    function dismissNotifications() {
        notificationServer.trackedNotifications.values.forEach(notification => notification.dismiss())
        notificationQueue = []
        visibleNotifications = []
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

        const dedupKey = notificationDedupKey(notification)
        if (findActiveDuplicate(dedupKey) || hasRecentDuplicate(dedupKey)) {
            notification.dismiss()
            return false
        }

        notificationIngressCount += 1
        recordDedupKey(dedupKey)

        return true
    }

    function createNotificationPopup(notification, policy) {
        notificationPopupSequence += 1

        const appName = notification.appName || "App"
        const appIcon = notification.appIcon || ""
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
            image: image,
            urgency: policy && typeof policy.urgency === "number" ? policy.urgency : notification.urgency,
            actions: notification.actions || [],
            transient: notification.transient,
            dedupKey: notificationDedupKey(notification),
            createdAt: Date.now()
        }
    }

    function processNotificationPopupQueue() {
        let visible = visibleNotifications.slice()
        let queued = notificationQueue.slice()

        while (visible.length < maxVisibleNotifications && queued.length > 0)
            visible.unshift(queued.shift())

        visibleNotifications = visible
        notificationQueue = queued
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

        if (!popup || !popup.createdAt)
            return "now"

        const time = new Date(popup.createdAt)
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

    function notificationDedupKey(notification) {
        return `${notification.appName || ""}|${notification.desktopEntry || ""}|${notification.summary || ""}|${notification.body || ""}`.toLowerCase()
    }

    function findActiveDuplicate(key) {
        return visibleNotifications.concat(notificationQueue).find(item => item && item.dedupKey === key)
    }

    function pruneRecentDedupKeys() {
        const cutoff = Date.now() - notificationDedupBurstMs
        recentNotificationDedupKeys = recentNotificationDedupKeys.filter(item => item && item.at >= cutoff)
    }

    function hasRecentDuplicate(key) {
        pruneRecentDedupKeys()
        return recentNotificationDedupKeys.some(item => item && item.key === key)
    }

    function recordDedupKey(key) {
        pruneRecentDedupKeys()
        recentNotificationDedupKeys = recentNotificationDedupKeys.concat([{ key: key, at: Date.now() }])
    }

    function evaluateNotificationPolicy(notification) {
        const policy = {
            drop: false,
            disablePopup: false,
            hideFromCenter: false,
            urgency: typeof notification.urgency === "number" ? notification.urgency : NotificationUrgency.Normal
        }

        for (const rule of notificationRules) {
            if (!matchesNotificationRule(rule, notification))
                continue

            const action = String(rule.action || "default").toLowerCase()
            if (action === "ignore")
                policy.drop = true
            else if (action === "mute")
                policy.disablePopup = true
            else if (action === "popup_only")
                policy.hideFromCenter = true
            else if (action === "no_popup")
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
        const currentIndex = Math.max(0, powerProfiles.indexOf(powerProfile))
        const next = powerProfiles[(currentIndex + 1) % powerProfiles.length]

        powerProfile = next
        Quickshell.execDetached(["powerprofilesctl", "set", next])
        powerRefreshTimer.restart()
    }

}
