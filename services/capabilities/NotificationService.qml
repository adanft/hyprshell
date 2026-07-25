import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

Scope {
    id: root
    required property var theme
    readonly property int notificationCount: root.notificationHistory.length
    readonly property bool hasNotifications: root.notificationCount > 0
    readonly property var notifications: root.notificationHistory
    readonly property int minVisibleNotifications: 1
    readonly property int notificationPopupEstimatedHeight: root.theme.sizing.notificationPopupEstimatedHeight
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
    property bool notificationDnd: false
    // Session-scoped quarantine; entries live only as long as this capability.
    property var invalidLiveImageSources: ({})

    FileView {
        id: historyFileView
        path: root.notificationHistoryFile
        printErrors: false
        onLoaded: root.loadNotificationHistory()
        onLoadFailed: error => { if (error === 2) historyFileView.writeAdapter() }
        JsonAdapter { id: historyAdapter; property var notifications: [] }
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
            const policy = root.evaluateNotificationPolicy(notification)
            if (policy.block || root.notificationDnd) { notification.dismiss(); return }
            notification.tracked = !notification.transient && !policy.hideFromCenter
            if (!notification.transient && !policy.hideFromCenter) root.addNotificationToHistory(notification, policy)
            if (policy.hide) { notification.dismiss(); return }
            if (!policy.disablePopup && !root.notificationCenterOpen) root.enqueueNotificationPopup(notification, policy)
        }
    }
    Timer {
        interval: 30000
        running: root.notificationCenterOpen || root.notificationHistory.length > 0 || root.visibleNotifications.length > 0 || root.notificationQueue.length > 0
        repeat: true
        onTriggered: root.notificationTimeUpdateTick = !root.notificationTimeUpdateTick
    }
    Timer { id: saveTimer; interval: 500; repeat: false; onTriggered: root.saveNotificationHistory() }
    Component.onDestruction: { if (saveTimer.running) root.saveNotificationHistory() }

    function dismissNotifications() {
        notificationServer.trackedNotifications.values.forEach(notification => notification.dismiss())
        root.notificationHistory = []
        root.saveNotificationHistory()
        root.notificationQueue = []
        root.visibleNotifications = []
    }
    function dismissNotificationHistoryEntry(entry) {
        if (!entry) return
        if (entry.notification && entry.notification.dismiss) entry.notification.dismiss()
        root.notificationHistory = root.notificationHistory.filter(item => item && item.id !== entry.id)
        root.saveNotificationHistory()
    }
    function setNotificationCenterOpen(open) {
        root.notificationCenterOpen = open
        if (root.notificationCenterOpen) root.clearNotificationPopups()
    }
    function clearNotificationPopups() { root.notificationQueue = []; root.visibleNotifications = [] }
    function toggleNotificationDnd() {
        root.notificationDnd = !root.notificationDnd
        if (root.notificationDnd) { root.notificationQueue = []; root.visibleNotifications = [] }
    }
    function enqueueNotificationPopup(notification, policy) {
        if (!root.shouldShowNotificationPopup(notification, policy)) return
        const popup = root.createNotificationPopup(notification, policy)
        let queued = root.notificationQueue.slice()
        if (queued.length >= root.maxNotificationQueueSize) {
            let victimIndex = queued.findIndex(item => item && item.urgency !== NotificationUrgency.Critical)
            if (victimIndex < 0 && popup.urgency !== NotificationUrgency.Critical) return
            if (victimIndex < 0) victimIndex = 0
            queued.splice(victimIndex, 1)
        }
        root.notificationQueue = queued.concat([popup])
        root.processNotificationPopupQueue()
    }
    function shouldShowNotificationPopup(notification, policy) {
        const currentSecond = Math.floor(Date.now() / 1000)
        const urgency = policy && typeof policy.urgency === "number" ? policy.urgency : notification.urgency
        if (root.notificationIngressSecond !== currentSecond) {
            root.notificationIngressSecond = currentSecond
            root.notificationIngressCount = 0
        }
        if (urgency !== NotificationUrgency.Critical && root.notificationIngressCount >= root.maxPopupIngressPerSecond) return false
        root.notificationIngressCount += 1
        return true
    }
    function createNotificationPopup(notification, policy) {
        root.notificationPopupSequence += 1
        const body = root.stripImages(notification.body || "")
        return { id: root.notificationPopupSequence, notification: notification, summary: root.stripImages(notification.summary || "Notification"), body: body,
            htmlBody: root.resolveHtmlBody(body), appName: notification.appName || "App", appIcon: notification.appIcon || "",
            desktopEntry: notification.desktopEntry || "", image: notification.image || "",
            urgency: policy && typeof policy.urgency === "number" ? policy.urgency : notification.urgency,
            actions: notification.actions || [], transient: notification.transient, createdAt: Date.now() }
    }
    function addNotificationToHistory(notification, policy) {
        let history = root.notificationHistory.slice()
        history.unshift(root.createNotificationHistoryEntry(notification, policy))
        if (history.length > root.maxNotificationHistory) history = history.slice(0, root.maxNotificationHistory)
        root.notificationHistory = history
        root.scheduleNotificationHistorySave()
    }
    function createNotificationHistoryEntry(notification, policy) {
        const body = root.stripImages(notification.body || "")
        const createdAt = Date.now()
        return { id: `${createdAt}-${Math.random()}`, notification: notification, summary: root.stripImages(notification.summary || "Notification"),
            body: body, htmlBody: root.resolveHtmlBody(body), appName: notification.appName || "App", appIcon: notification.appIcon || "",
            desktopEntry: notification.desktopEntry || "", image: notification.image || "",
            urgency: policy && typeof policy.urgency === "number" ? policy.urgency : notification.urgency,
            actions: [], createdAt: createdAt, timestamp: createdAt }
    }
        function isInvalidLiveImageSource(source) {
            const imageSource = String(source || "")
            return imageSource.startsWith("image://qsimage/") && root.invalidLiveImageSources[imageSource] === true
        }
        function quarantineInvalidLiveImageSource(source) {
            const imageSource = String(source || "")
            if (!imageSource.startsWith("image://qsimage/") || root.invalidLiveImageSources[imageSource] === true) return
            const next = Object.assign({}, root.invalidLiveImageSources)
            next[imageSource] = true
            root.invalidLiveImageSources = next
        }
        function persistentNotificationImage(source) {
        const imageSource = source || ""
        return imageSource.startsWith("image://qsimage/") ? "" : imageSource
    }
    function scheduleNotificationHistorySave() { saveTimer.restart() }
    function saveNotificationHistory() {
        saveTimer.stop()
        historyAdapter.notifications = root.notificationHistory.map(item => ({ id: item.id, summary: item.summary || "Notification", body: item.body || "",
            htmlBody: item.htmlBody || root.resolveHtmlBody(item.body || ""), appName: item.appName || "App", appIcon: item.appIcon || "",
            desktopEntry: item.desktopEntry || "", image: root.persistentNotificationImage(item.image),
            urgency: typeof item.urgency === "number" ? item.urgency : NotificationUrgency.Normal, actions: [],
            createdAt: item.createdAt || item.timestamp || Date.now(), timestamp: item.timestamp || item.createdAt || Date.now() }))
        historyFileView.writeAdapter()
    }
    function loadNotificationHistory() {
        root.notificationHistory = (historyAdapter.notifications || []).map(item => ({ id: item.id || `${item.timestamp || Date.now()}-${Math.random()}`,
            summary: item.summary || "Notification", body: item.body || "", htmlBody: item.htmlBody || root.resolveHtmlBody(item.body || ""),
            appName: item.appName || "App", appIcon: item.appIcon || "", desktopEntry: item.desktopEntry || "",
            image: root.persistentNotificationImage(item.image), urgency: typeof item.urgency === "number" ? item.urgency : NotificationUrgency.Normal,
            actions: [], createdAt: item.createdAt || item.timestamp || Date.now(), timestamp: item.timestamp || item.createdAt || Date.now() }))
    }
    function processNotificationPopupQueue() {
        let visible = root.visibleNotifications.slice()
        let queued = root.notificationQueue.slice()
        const capacity = Math.max(root.minVisibleNotifications, root.notificationPopupCapacity)
        while (visible.length > capacity) queued.unshift(visible.pop())
        while (visible.length < capacity && queued.length > 0) visible.unshift(queued.shift())
        root.visibleNotifications = visible
        root.notificationQueue = queued
    }
    function setNotificationPopupAvailableHeight(height) {
        const availableHeight = Math.max(0, height || 0)
        const popupSpacing = root.theme.spacing.notificationPopupSpacing
        const capacity = Math.max(root.minVisibleNotifications, Math.floor((availableHeight + popupSpacing) / (root.notificationPopupEstimatedHeight + popupSpacing)))
        if (root.notificationPopupCapacity === capacity) return
        root.notificationPopupCapacity = capacity
        root.processNotificationPopupQueue()
    }
    function closeNotificationPopup(id) {
        root.visibleNotifications = root.visibleNotifications.filter(popup => popup.id !== id)
        root.processNotificationPopupQueue()
    }
    function invokeNotificationPopupAction(id, action) {
        if (action && action.invoke) action.invoke()
        root.closeNotificationPopup(id)
    }
    function notificationPopupTimeout(urgency) {
        switch (urgency) {
        case NotificationUrgency.Low: return root.notificationTimeoutLow
        case NotificationUrgency.Critical: return root.notificationTimeoutCritical
        default: return root.notificationTimeoutNormal
        }
    }
    function notificationTimeText(popup) {
        root.notificationTimeUpdateTick
        const timestamp = popup ? (popup.createdAt || popup.timestamp) : 0
        if (!timestamp) return "now"
        const time = new Date(timestamp)
        const now = new Date()
        const minutes = Math.floor((now.getTime() - time.getTime()) / 60000)
        const hours = Math.floor(minutes / 60)
        if (hours < 1) return minutes < 1 ? "now" : `${minutes}m ago`
        const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const timeDate = new Date(time.getFullYear(), time.getMonth(), time.getDate())
        return Math.floor((nowDate - timeDate) / 86400000) === 0
            ? root.formatNotificationTime(time)
            : `${time.toLocaleDateString(Qt.locale(), "dddd")}, ${root.formatNotificationTime(time)}`
    }
    function formatNotificationTime(date) { return date.toLocaleTimeString(Qt.locale(), "HH:mm") }
    function evaluateNotificationPolicy(notification) {
        const policy = { block: false, disablePopup: false, hideFromCenter: false, hide: false, mute: false,
            urgency: typeof notification.urgency === "number" ? notification.urgency : NotificationUrgency.Normal }
        for (const rule of root.notificationRules) {
            if (!root.matchesNotificationRule(rule, notification)) continue
            const action = String(rule.action || "default").toLowerCase()
            if (action === "block" || action === "ignore") policy.block = true
            else if (action === "hide" || action === "no_popup") policy.hide = true
            else if (action === "mute") policy.mute = true
            else if (action === "popup_only") policy.hideFromCenter = true
            else if (action === "disable_popup") policy.disablePopup = true
            if (rule.urgency !== undefined) policy.urgency = root.coerceNotificationUrgency(rule.urgency, policy.urgency)
            return policy
        }
        return policy
    }
    function matchesNotificationRule(rule, notification) {
        const fields = { appName: notification.appName || "", desktopEntry: notification.desktopEntry || "", summary: notification.summary || "", body: notification.body || "" }
        for (const key of Object.keys(rule)) {
            if (["action", "urgency"].includes(key)) continue
            if (!root.matchesRuleValue(fields[key] || "", rule[key])) return false
        }
        return true
    }
    function matchesRuleValue(actual, expected) {
        if (expected === undefined || expected === null || expected === "") return true
        return String(actual).toLowerCase().includes(String(expected).toLowerCase())
    }
    function coerceNotificationUrgency(value, fallback) {
        if (typeof value === "number") return value
        const normalized = String(value).toLowerCase()
        if (normalized === "low") return NotificationUrgency.Low
        if (normalized === "critical") return NotificationUrgency.Critical
        if (normalized === "normal") return NotificationUrgency.Normal
        return fallback
    }
    function stripImages(text) { return String(text || "").replace(/<img\b[^>]*>/gi, "") }
    function escapeHtml(text) { return String(text || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;") }
    function resolveHtmlBody(body) { return root.escapeHtml(body).replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1">$1</a>') }
}
