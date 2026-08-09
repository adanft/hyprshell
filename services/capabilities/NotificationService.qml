import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import "../../notifications/NotificationImagePersistence.js" as NotificationImagePersistence
import "NotificationTimeActivity.js" as NotificationTimeActivity

Scope {
    id: root

    required property var theme
    readonly property int notificationCount: root.notificationHistory.length
    readonly property bool hasNotifications: root.notificationCount > 0
    readonly property var notifications: root.notificationHistory
    readonly property int minVisibleNotifications: 1
    readonly property int notificationPopupEstimatedHeight: root.theme.sizing.notificationPopupEstimatedHeight
    readonly property int maxNotificationHistory: 100
    readonly property string notificationHistoryFile: `${Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")
                                                      }/.cache`}/statusbar-notifications.json`
    readonly property string focusedNotificationScreenName: Hyprland.focusedMonitor?.name || (Quickshell.screens.length
                                                                                              > 0 ? Quickshell.screens[0].name :
                                                                                                    "")
    readonly property int maxPopupIngressPerSecond: 6
    readonly property int maxNotificationQueueSize: 32
    readonly property string notificationImageCacheDirectory: `${Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env(
                                                                  "HOME")}/.cache`}/qsrice/notification-images`
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
    property bool notificationHistoryWritePending: false
    // Session-scoped quarantine; entries live only as long as this capability.
    property var invalidLiveImageSources: ({})
    property var notificationImagePersistence: NotificationImagePersistence.createState()
    property var notificationImageCaptureHosts: []
    property var notificationImageCaptureJobs: ({})
    property int notificationImageCaptureGeneration: 0
    readonly property var notificationImageCaptureHost: notificationImageCaptureHosts.length > 0
                                                         ? notificationImageCaptureHosts[0] : null

    property bool notificationImageLifecycleActive: true

    Component {
        id: notificationImageMkdirComponent
        Process {}
    }
    Component {
        id: notificationImageCaptureComponent

        Image {
            required property string entryId
            required property string targetPath
            required property int captureGeneration
            required property var captureHost
            property bool captureFinished: false

            width: root.theme.sizing.notificationCardIconSaveSize
            height: width
            asynchronous: false
            cache: true
            sourceSize: Qt.size(0, 0)
            fillMode: Image.PreserveAspectFit
            Component.onDestruction: {
                if (!captureFinished && root.notificationImageLifecycleActive)
                    root.notificationImageItemDestroyed(entryId, captureGeneration)
            }
            onStatusChanged: {
                if (status === Image.Ready)
                    root.prepareNotificationImageCapture(entryId, captureGeneration)
                else if (status === Image.Error)
                    root.failNotificationImageCapture(entryId, captureGeneration, true)
            }
        }
    }
    Component {
        id: notificationImageCleanupComponent
        Process {}
    }
    Component {
        id: notificationImageSweepComponent

        Process {
            id: sweepProcess

            stdout: StdioCollector {
                onStreamFinished: {
                    if (root.notificationImageLifecycleActive)
                        root.removeNotificationImageOrphans(this.text)
                }
            }
            onExited: Qt.callLater(function () {
                sweepProcess.destroy()
            })
        }
    }

    FileView {
        id: historyFileView

        path: root.notificationHistoryFile
        printErrors: false
        blockWrites: true
        atomicWrites: true
        onLoaded: {
            root.loadNotificationHistory()
            root.sweepNotificationImageCache()
        }
        onLoadFailed: error => {
            if (error === 2) {
                historyFileView.writeAdapter()
                root.sweepNotificationImageCache()
            }
        }

        JsonAdapter {
            id: historyAdapter

            property var notifications: []
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
            const policy = root.evaluateNotificationPolicy(notification)
            if (policy.block || root.notificationDnd) {
                notification.dismiss()
                return
            }

            notification.tracked = !notification.transient && !policy.hideFromCenter
            const historyEntry = notification.tracked ? root.addNotificationToHistory(notification, policy) : null
            if (policy.hide) {
                notification.dismiss()
                return
            }

            if (!policy.disablePopup && !root.notificationCenterOpen)
                root.enqueueNotificationPopup(notification, policy, historyEntry ? historyEntry.id : "")
        }
    }

    Timer {
        interval: 30000
            running: NotificationTimeActivity.shouldUpdateNotificationTime({
                centerOpen: root.notificationCenterOpen,
                visiblePopup: root.visibleNotifications.length > 0,
                queuedPopup: root.notificationQueue.length > 0,
            })
        repeat: true
        onTriggered: root.notificationTimeUpdateTick = !root.notificationTimeUpdateTick
    }

    Timer {
        id: saveTimer

        interval: 500
        repeat: false
        onTriggered: root.saveNotificationHistory()
    }

    Component.onDestruction: {
        root.notificationImageLifecycleActive = false
        root.cancelAllNotificationImageJobs(false)
        if (root.notificationHistoryWritePending)
            root.saveNotificationHistory()
    }

    function dismissNotifications() {
        notificationServer.trackedNotifications.values.forEach(notification => notification.dismiss())
        root.notificationHistory.forEach(entry => root.removeOwnedNotificationImage(entry))
        root.notificationHistory = []
        root.saveNotificationHistory()
        root.notificationQueue = []
        root.visibleNotifications = []
    }

    function dismissNotificationHistoryEntry(entry) {
        if (!entry)
            return
        if (entry.notification && entry.notification.dismiss)
            entry.notification.dismiss()
        root.notificationHistory = root.notificationHistory.filter(item => item && item.id !== entry.id)
        root.removeOwnedNotificationImage(entry)
        root.saveNotificationHistory()
    }

    function setNotificationCenterOpen(open) {
        root.notificationCenterOpen = open
        if (root.notificationCenterOpen) {
            root.notificationTimeUpdateTick = !root.notificationTimeUpdateTick
            root.clearNotificationPopups()
        }
    }

    function clearNotificationPopups() {
        root.notificationQueue = []
        root.visibleNotifications = []
    }

    function toggleNotificationDnd() {
        root.notificationDnd = !root.notificationDnd
        if (root.notificationDnd)
            root.clearNotificationPopups()
    }

    function enqueueNotificationPopup(notification, policy, historyEntryId) {
        if (!root.shouldShowNotificationPopup(notification, policy))
            return
        const popup = root.createNotificationPopup(notification, policy, historyEntryId)
        let queued = root.notificationQueue.slice()
        if (queued.length >= root.maxNotificationQueueSize) {
            let victimIndex = queued.findIndex(item => item && item.urgency !== NotificationUrgency.Critical)
            if (victimIndex < 0 && popup.urgency !== NotificationUrgency.Critical)
                return
            if (victimIndex < 0)
                victimIndex = 0
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

        if (urgency !== NotificationUrgency.Critical && root.notificationIngressCount >= root.maxPopupIngressPerSecond)
            return false

        root.notificationIngressCount += 1
        return true
    }

    function createNotificationPopup(notification, policy, historyEntryId) {
        root.notificationPopupSequence += 1
        const body = root.stripImages(notification.body || "")
        return {
            id: root.notificationPopupSequence,
            summary: root.stripImages(notification.summary || "Notification"),
            body: body,
            htmlBody: root.resolveHtmlBody(body),
            appName: notification.appName || "App",
            appIcon: notification.appIcon || "",
            desktopEntry: notification.desktopEntry || "",
            image: notification.image || "",
            urgency: policy && typeof policy.urgency === "number" ? policy.urgency : notification.urgency,
            actions: notification.actions || [],
            transient: notification.transient,
            historyEntryId: historyEntryId || "",
            createdAt: Date.now()
        }
    }

    function addNotificationToHistory(notification, policy) {
        let history = root.notificationHistory.slice()
        const entry = root.createNotificationHistoryEntry(notification, policy)
        history.unshift(entry)
        if (history.length > root.maxNotificationHistory) {
            const removed = history.slice(root.maxNotificationHistory)
            removed.forEach(item => root.removeOwnedNotificationImage(item))
            history = history.slice(0, root.maxNotificationHistory)
        }

        root.notificationHistory = history
        root.scheduleNotificationHistorySave()
        root.materializeNotificationImage(entry.id)
        return entry
    }

    function createNotificationHistoryEntry(notification, policy) {
        const body = root.stripImages(notification.body || "")
        const createdAt = Date.now()
        return {
            id: `${createdAt}-${Math.random()}`,
            notification: notification,
            summary: root.stripImages(notification.summary || "Notification"),
            body: body,
            htmlBody: root.resolveHtmlBody(body),
            appName: notification.appName || "App",
            appIcon: notification.appIcon || "",
            desktopEntry: notification.desktopEntry || "",
            image: notification.image || "",
            urgency: policy && typeof policy.urgency === "number" ? policy.urgency : notification.urgency,
            actions: notification.actions || [],
            createdAt: createdAt,
            timestamp: createdAt
        }
    }

    function isInvalidLiveImageSource(source) {
        const imageSource = String(source || "")
        return imageSource.startsWith("image://qsimage/") && root.invalidLiveImageSources[imageSource] === true
    }

    function quarantineInvalidLiveImageSource(source, excludedEntryId, excludedGeneration) {
        const imageSource = String(source || "")
        if (!imageSource.startsWith("image://qsimage/") || root.invalidLiveImageSources[imageSource] === true)
            return
        const next = Object.assign({}, root.invalidLiveImageSources)
        next[imageSource] = true
        root.invalidLiveImageSources = next
        let historyChanged = false
        root.notificationHistory.forEach(entry => {
            if (entry && String(entry.image || "") === imageSource) {
                entry.image = ""
                historyChanged = true
            }
        })
        root.notificationQueue.forEach(popup => {
            if (popup && String(popup.image || "") === imageSource)
                popup.image = ""
        })
        root.visibleNotifications.forEach(popup => {
            if (popup && String(popup.image || "") === imageSource)
                popup.image = ""
        })
        if (historyChanged) {
            root.notificationHistory = root.notificationHistory.slice()
            root.scheduleNotificationHistorySave()
        }
        root.notificationQueue = root.notificationQueue.slice()
        root.visibleNotifications = root.visibleNotifications.slice()
        Object.keys(root.notificationImageCaptureJobs).forEach(entryId => {
            const job = root.notificationImageCaptureJobs[entryId]
            if (job && job.source === imageSource
                    && (entryId !== excludedEntryId || job.generation !== excludedGeneration))
                root.cancelNotificationImageJob(entryId, job.generation, false)
        })
    }

    function scheduleNotificationHistorySave() {
        root.notificationHistoryWritePending = true
        saveTimer.restart()
    }

    function registerNotificationImageCaptureHost(host) {
        if (!host || root.notificationImageCaptureHosts.indexOf(host) !== -1)
            return
        const hosts = root.notificationImageCaptureHosts.filter(candidate => candidate)
        hosts.push(host)
        hosts.sort((left, right) => String(left.captureHostKey || "").localeCompare(String(right.captureHostKey || "")))
        root.notificationImageCaptureHosts = hosts
    }

    function unregisterNotificationImageCaptureHost(host) {
        root.notificationImageCaptureHosts = root.notificationImageCaptureHosts.filter(candidate => candidate && candidate !== host)
        Object.keys(root.notificationImageCaptureJobs).forEach(entryId => {
            const job = root.notificationImageCaptureJobs[entryId]
            if (job && job.host === host)
                root.cancelNotificationImageJob(entryId, job.generation, true)
        })
    }

    function notificationImageEntry(entryId) {
        return root.notificationHistory.find(item => item && item.id === entryId) || null
    }

    function activeNotificationImageJob(entryId, generation) {
        const job = root.notificationImageCaptureJobs[entryId]
        return job && job.generation === generation ? job : null
    }

    function notificationImageHostReady(host) {
        return Boolean(host && root.notificationImageCaptureHosts.indexOf(host) !== -1 && host.Window.window)
    }

    function notificationImageItemReady(job) {
        const imageItem = job ? job.imageItem : null
        return Boolean(imageItem && imageItem.parent === job.host && imageItem.Window.window
                       && imageItem.Window.window === job.host.Window.window
                       && typeof imageItem.grabToImage === "function" && imageItem.status === Image.Ready)
    }

    function materializeNotificationImage(entryId) {
        if (!entryId || !root.notificationImageLifecycleActive)
            return
        const entry = root.notificationImageEntry(entryId)
        const captureParent = root.notificationImageCaptureHost
        if (!root.notificationImageHostReady(captureParent)
                || !NotificationImagePersistence.canMaterialize(root.notificationImagePersistence, entry, true))
            return
        root.startNotificationImageCapture(entry, captureParent, entry.image)
    }

    function startNotificationImageCapture(entry, captureParent, imageSource) {
        const path = NotificationImagePersistence.notificationImagePath(entry, root.notificationImageCacheDirectory)
        NotificationImagePersistence.begin(root.notificationImagePersistence, entry.id, path)
        root.notificationImageCaptureGeneration += 1
        const generation = root.notificationImageCaptureGeneration
        const imageItem = notificationImageCaptureComponent.createObject(captureParent, {
            entryId: entry.id,
            targetPath: path,
            captureGeneration: generation,
            captureHost: captureParent,
            source: ""
        })
        if (!imageItem) {
            root.finishNotificationImageJob(entry.id, generation, path, false, true)
            return
        }
        const jobs = Object.assign({}, root.notificationImageCaptureJobs)
        jobs[entry.id] = {
            generation: generation,
            host: captureParent,
            imageItem: imageItem,
            path: path,
            source: String(entry.image || ""),
            mkdir: null
        }
        root.notificationImageCaptureJobs = jobs
        imageItem.source = imageSource
    }

    function prepareNotificationImageCapture(entryId, generation) {
        const job = root.activeNotificationImageJob(entryId, generation)
        if (!root.notificationImageLifecycleActive || !job || !root.notificationImageEntry(entryId)
                || !root.notificationImageHostReady(job.host) || !root.notificationImageItemReady(job)) {
            root.cancelNotificationImageJob(entryId, generation, true)
            return
        }
        const mkdir = notificationImageMkdirComponent.createObject(root)
        if (!mkdir) {
            root.cancelNotificationImageJob(entryId, generation, true)
            return
        }
        job.mkdir = mkdir
        mkdir.onExited.connect(function (exitCode) {
            mkdir.destroy()
            const currentJob = root.activeNotificationImageJob(entryId, generation)
            if (!currentJob)
                return
            currentJob.mkdir = null
            if (exitCode !== 0) {
                root.cancelNotificationImageJob(entryId, generation, true)
                return
            }
            if (!root.notificationImageLifecycleActive || !root.notificationImageEntry(entryId)
                    || !root.notificationImageHostReady(currentJob.host)
                    || !root.notificationImageItemReady(currentJob)) {
                root.cancelNotificationImageJob(entryId, generation, true)
                return
            }
            const saveSize = root.theme.sizing.notificationCardIconSaveSize
            currentJob.imageItem.grabToImage(function (result) {
                const completedJob = root.activeNotificationImageJob(entryId, generation)
                if (!completedJob)
                    return
                let saved = false
                try {
                    saved = Boolean(result && result.saveToFile(completedJob.path))
                } catch (error) {
                    console.warn(`Failed to save notification image: ${error}`)
                }
                root.finishNotificationImageJob(entryId, generation, completedJob.path, saved, true)
            }, Qt.size(saveSize, saveSize))
        })
        mkdir.exec(["mkdir", "-p", "--", root.notificationImageCacheDirectory])
    }

    function notificationImageItemDestroyed(entryId, generation) {
        const job = root.activeNotificationImageJob(entryId, generation)
        if (job)
            root.finishNotificationImageJob(entryId, generation, job.path, false, true)
    }

    function failNotificationImageCapture(entryId, generation, invalidLiveSource) {
        const job = root.activeNotificationImageJob(entryId, generation)
        if (!job)
            return
        if (invalidLiveSource)
            root.quarantineInvalidLiveImageSource(job.source, entryId, generation)
        root.finishNotificationImageJob(entryId, generation, job.path, false, !invalidLiveSource)
    }

    function cancelNotificationImageJob(entryId, generation, retry) {
        const job = root.activeNotificationImageJob(entryId, generation)
        if (job)
            root.finishNotificationImageJob(entryId, generation, job.path, false, retry)
    }

    function cancelAllNotificationImageJobs(retry) {
        Object.keys(root.notificationImageCaptureJobs).forEach(entryId => {
            const job = root.notificationImageCaptureJobs[entryId]
            if (job)
                root.cancelNotificationImageJob(entryId, job.generation, retry)
        })
    }

    function finishNotificationImageJob(entryId, generation, path, saved, allowRetry) {
        const job = root.activeNotificationImageJob(entryId, generation)
        if (job) {
            const jobs = Object.assign({}, root.notificationImageCaptureJobs)
            delete jobs[entryId]
            root.notificationImageCaptureJobs = jobs
            if (job.imageItem) {
                job.imageItem.captureFinished = true
                job.imageItem.destroy()
            }
        }
        const current = root.notificationImageEntry(entryId)
        const completionActive = root.notificationImageLifecycleActive && (saved || allowRetry)
        const outcome = NotificationImagePersistence.complete(root.notificationImagePersistence, entryId, path, saved,
                                                               Boolean(current), completionActive)
        if (outcome.orphan)
            root.deleteOwnedNotificationImage(outcome.orphan, true)
        if (outcome.persisted) {
            current.image = `file://${path}`
            current.persistedImagePath = path
            current.ownedImage = true
            root.scheduleNotificationHistorySave()
            return
        }

        if (outcome.retry && allowRetry)
            Qt.callLater(function () {
                if (root.notificationImageLifecycleActive)
                    root.materializeNotificationImage(entryId)
            })
    }

    function sweepNotificationImageCache() {
        if (!root.notificationImageLifecycleActive)
            return
        const sweep = notificationImageSweepComponent.createObject(root)
        sweep.exec(["find", root.notificationImageCacheDirectory, "-maxdepth", "1", "-type", "f", "-name", "notif_*.png",
                    "-print",])
    }

    function removeNotificationImageOrphans(output) {
        const paths = String(output || "").split("\n").filter(path => path.length > 0)
        const orphans = NotificationImagePersistence.orphanPaths(paths, root.notificationHistory,
                                                                 root.notificationImageCacheDirectory)
        orphans.forEach(path => root.deleteOwnedNotificationImage(path, true))
    }

    function deleteOwnedNotificationImage(path, owned) {
        if (owned !== true || !NotificationImagePersistence.isOwnedPath(path, root.notificationImageCacheDirectory))
            return
        const cleanup = notificationImageCleanupComponent.createObject(root)
        if (!cleanup)
            return
        cleanup.onExited.connect(function (exitCode) {
            if (exitCode !== 0)
                console.warn(`Failed to remove cached notification image: ${path}`)
            cleanup.destroy()
        })
        cleanup.exec(["rm", "-f", "--", path])
    }

    function removeOwnedNotificationImage(entry) {
        if (!entry)
            return
        const ownedPath = NotificationImagePersistence.removeEntry(root.notificationImagePersistence, entry.id)
        const persistedPath = entry.ownedImage ? entry.persistedImagePath : ""
        root.deleteOwnedNotificationImage(ownedPath || persistedPath, Boolean(ownedPath) || entry.ownedImage === true)
    }

    function saveNotificationHistory() {
        saveTimer.stop()
        historyAdapter.notifications = root.notificationHistory.map(item => ({
            id: item.id,
            summary: item.summary || "Notification",
            body: item.body || "",
            htmlBody: item.htmlBody || root.resolveHtmlBody(item.body || ""),
            appName: item.appName || "App",
            appIcon: item.appIcon || "",
            desktopEntry: item.desktopEntry || "",
            image: NotificationImagePersistence.historyImageSource(item.image),
            persistedImagePath: item.ownedImage ? item.persistedImagePath || "" : "",
            ownedImage: item.ownedImage === true,
            urgency: typeof item.urgency === "number" ? item.urgency : NotificationUrgency.Normal,
            actions: [],
            createdAt: item.createdAt || item.timestamp || Date.now(),
            timestamp: item.timestamp || item.createdAt || Date.now()
        }))
        historyFileView.writeAdapter()
        root.notificationHistoryWritePending = false
    }

    function loadNotificationHistory() {
        root.notificationHistory = (historyAdapter.notifications || []).map(item => ({
            id: item.id || `${item.timestamp || Date.now()}-${Math.random()}`,
            summary: item.summary || "Notification",
            body: item.body || "",
            htmlBody: item.htmlBody || root.resolveHtmlBody(item.body || ""),
            appName: item.appName || "App",
            appIcon: item.appIcon || "",
            desktopEntry: item.desktopEntry || "",
            image: NotificationImagePersistence.historyImageSource(item.image),
            persistedImagePath: item.ownedImage === true ? item.persistedImagePath || "" : "",
            ownedImage: item.ownedImage === true,
            urgency: typeof item.urgency === "number" ? item.urgency : NotificationUrgency.Normal,
            actions: [],
            createdAt: item.createdAt || item.timestamp || Date.now(),
            timestamp: item.timestamp || item.createdAt || Date.now()
        }))
    }

    function processNotificationPopupQueue() {
        let visible = root.visibleNotifications.slice()
        let queued = root.notificationQueue.slice()
        const capacity = Math.max(root.minVisibleNotifications, root.notificationPopupCapacity)
        while (visible.length > capacity)
            queued.unshift(visible.pop())
        while (visible.length < capacity && queued.length > 0)
            visible.unshift(queued.shift())
        root.visibleNotifications = visible
        root.notificationQueue = queued
    }

    function setNotificationPopupAvailableHeight(height) {
        const availableHeight = Math.max(0, height || 0)
        const popupSpacing = root.theme.spacing.notificationPopupSpacing
        const capacity = Math.max(root.minVisibleNotifications, Math.floor((availableHeight + popupSpacing) / (root.notificationPopupEstimatedHeight
                                                                                                               + popupSpacing)))
        if (root.notificationPopupCapacity === capacity)
            return
        root.notificationPopupCapacity = capacity
        root.processNotificationPopupQueue()
    }

    function closeNotificationPopup(id) {
        root.visibleNotifications = root.visibleNotifications.filter(popup => popup.id !== id)
        root.processNotificationPopupQueue()
    }

    function invokeNotificationPopupAction(id, action) {
        if (action && action.invoke)
            action.invoke()
        root.closeNotificationPopup(id)
    }

    function notificationPopupTimeout(urgency) {
        switch (urgency) {
        case NotificationUrgency.Low:
            return root.notificationTimeoutLow
        case NotificationUrgency.Critical:
            return root.notificationTimeoutCritical
        default:
            return root.notificationTimeoutNormal
        }
    }

    function notificationTimeText(popup) {
        root.notificationTimeUpdateTick
        const timestamp = popup ? (popup.createdAt || popup.timestamp) : 0
        if (!timestamp)
            return "now"

        const time = new Date(timestamp)
        const now = new Date()
        const minutes = Math.floor((now.getTime() - time.getTime()) / 60000)
        const hours = Math.floor(minutes / 60)
        if (hours < 1)
            return minutes < 1 ? "now" : `${minutes}m ago`

        const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const timeDate = new Date(time.getFullYear(), time.getMonth(), time.getDate())
        const dateText = time.toLocaleDateString(Qt.locale(), "dddd")
        return Math.floor((nowDate - timeDate) / 86400000) === 0 ? root.formatNotificationTime(time) : [dateText, ", ",
                                                                                                        root.formatNotificationTime(
                                                                                                            time)].join(
                                                                       "")
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
        for (const rule of root.notificationRules) {
            if (!root.matchesNotificationRule(rule, notification))
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
                policy.urgency = root.coerceNotificationUrgency(rule.urgency, policy.urgency)
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
            if (!root.matchesRuleValue(fields[key] || "", rule[key]))
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
        return String(text || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g,
                                                                                                             "&quot;").replace(
                    /'/g, "&#39;")
    }

    function resolveHtmlBody(body) {
        return root.escapeHtml(body).replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1">$1</a>')
    }
}
