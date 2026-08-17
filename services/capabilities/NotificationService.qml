import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import "NotificationImagePersistence.js" as NotificationImagePersistence
import "NotificationTimeActivity.js" as NotificationTimeActivity
import "NotificationPopupTimeoutState.js" as NotificationPopupTimeoutState
import "NotificationFileActions.js" as NotificationFileActions

Scope {
    id: root

    signal notificationPopupClosed(int popupId)

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
                                                                  "HOME")}/.cache`}/hyprshell/notification-images`
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
    property int notificationPopupManagerSequence: 0
    property var notificationPopupTimeoutState: NotificationPopupTimeoutState.createState()
    property bool notificationTimeUpdateTick: false
    property bool notificationCenterOpen: false
    property var notificationHistory: []
    property bool notificationDnd: false
    property bool notificationHistoryWritePending: false
    // Session-scoped quarantine; entries live only as long as this capability.
    property var invalidLiveImageSources: ({})
    property var invalidOwnedImageSources: ({})
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
        id: notificationImageOperationComponent
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
        // How a sender learns this shell will do something with the hint. KDE
        // advertises the same string, and winbar copied it for the same reason.
        extraHints: [NotificationFileActions.HINT_KEY]
        onNotification: notification => {
            const policy = root.evaluateNotificationPolicy(notification)
            if (policy.block) {
                notification.dismiss()
                return
            }

            notification.tracked = !notification.transient && !policy.hideFromCenter
            const historyEntry = notification.tracked ? root.addNotificationToHistory(notification, policy) : null
            if (policy.hide) {
                notification.dismiss()
                return
            }

            // Do not disturb suppresses the popup, never the notification
            // itself: it is tracked above first, so the center still lists
            // everything that arrived. Critical passes through, because the
            // point of it is the message you cannot afford to miss.
            if (root.notificationSuppressedByDnd(policy, notification)) {
                notification.dismiss()
                return
            }

            if (!policy.disablePopup && !root.notificationCenterOpen)
                root.enqueueNotificationPopup(notification, policy, historyEntry ? historyEntry.id : "")
        }
    }

    Timer {
        interval: 50
        running: root.visibleNotifications.length > 0
        repeat: true
        onTriggered: root.expireNotificationPopups()
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
        root.clearNotificationPopups()
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
        const popupIds = root.notificationQueue.concat(root.visibleNotifications).filter(popup => popup).map(popup => popup.id)
        popupIds.forEach(id => NotificationPopupTimeoutState.removePopup(root.notificationPopupTimeoutState, id))
        root.notificationQueue = []
        root.visibleNotifications = []
    }

    // Critical is the one urgency do not disturb does not silence, matching
    // the two places that already treat it as special: it never expires, and
    // it is the last thing evicted when the popup queue overflows.
    function notificationSuppressedByDnd(policy, notification) {
        if (!root.notificationDnd)
            return false

        const urgency = policy && typeof policy.urgency === "number" ? policy.urgency : notification.urgency
        return urgency !== NotificationUrgency.Critical
    }

    // clearNotificationPopups() stays absolute, because its other two callers
    // are the user clearing everything and the center taking over the display.
    // Turning do not disturb on is neither: it must leave criticals standing.
    function clearNonCriticalNotificationPopups() {
        const isCritical = popup => popup && popup.urgency === NotificationUrgency.Critical
        const dropped = root.notificationQueue.concat(root.visibleNotifications).filter(popup => popup && !isCritical(popup))
        dropped.forEach(popup => NotificationPopupTimeoutState.removePopup(root.notificationPopupTimeoutState, popup.id))
        root.notificationQueue = root.notificationQueue.filter(isCritical)
        root.visibleNotifications = root.visibleNotifications.filter(isCritical)
    }

    function toggleNotificationDnd() {
        root.notificationDnd = !root.notificationDnd
        if (root.notificationDnd)
            root.clearNonCriticalNotificationPopups()
    }

    function enqueueNotificationPopup(notification, policy, historyEntryId) {
        if (!root.shouldShowNotificationPopup(notification, policy))
            return
        const popup = root.createNotificationPopup(notification, policy, historyEntryId)
        let queued = root.notificationQueue.slice()
        if (queued.length >= root.maxNotificationQueueSize) {
            let victimIndex = queued.findIndex(item => item && item.urgency !== NotificationUrgency.Critical)
            if (victimIndex < 0 && popup.urgency !== NotificationUrgency.Critical) {
                NotificationPopupTimeoutState.removePopup(root.notificationPopupTimeoutState, popup.id)
                return
            }
            if (victimIndex < 0)
                victimIndex = 0
            const removed = queued.splice(victimIndex, 1)[0]
            if (removed)
                NotificationPopupTimeoutState.removePopup(root.notificationPopupTimeoutState, removed.id)
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

    // The capture script names the file it just wrote in a hint, because the
    // shell cannot hand itself a notification and so still hears about its own
    // screenshot the same way it hears about anything else. Built here rather
    // than sent as `notify-send -A` buttons, which would belong to the script
    // and die with it — these are plain data, so they outlive the popup and
    // still work from the notification center.
    function notificationFileActions(path) {
        return NotificationFileActions.actionsFor(path, function (args) {
            Quickshell.execDetached(args)
        })
    }

    function notificationFilePath(notification) {
        return NotificationFileActions.firstLocalPath(notification ? notification.hints : null)
    }

    function resolveNotificationActions(notification) {
        return NotificationFileActions.resolveActions(notification ? notification.actions : null,
                                                      notification ? notification.hints : null,
                                                      function (args) {
                                                          Quickshell.execDetached(args)
                                                      })
    }

    function createNotificationPopup(notification, policy, historyEntryId) {
        root.notificationPopupSequence += 1
        const body = root.stripImages(notification.body || "")
        const filePath = root.notificationFilePath(notification)
        const popup = {
            id: root.notificationPopupSequence,
            summary: root.stripImages(notification.summary || "Notification"),
            body: body,
            htmlBody: root.resolveHtmlBody(body),
            appName: notification.appName || "App",
            appIcon: notification.appIcon || "",
            desktopEntry: notification.desktopEntry || "",
            image: notification.image || "",
            persistedImagePath: "",
            ownedImage: false,
            urgency: policy && typeof policy.urgency === "number" ? policy.urgency : notification.urgency,
            actions: root.resolveNotificationActions(notification),
            filePath: filePath,
            transient: notification.transient,
            historyEntryId: historyEntryId || "",
            createdAt: Date.now()
        }
        NotificationPopupTimeoutState.addPopup(root.notificationPopupTimeoutState, popup.id,
                                                root.notificationPopupTimeout(popup.urgency), Date.now())
        return popup
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
        const filePath = root.notificationFilePath(notification)
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
            actions: root.resolveNotificationActions(notification),
            filePath: filePath,
            createdAt: createdAt,
            timestamp: createdAt
        }
    }

    function isInvalidLiveImageSource(source) {
        const imageSource = String(source || "")
        return imageSource.startsWith("image://qsimage/") && root.invalidLiveImageSources[imageSource] === true
    }

    function isInvalidOwnedImageSource(source) {
        return root.invalidOwnedImageSources[String(source || "")] === true
    }

    function invalidateOwnedNotificationImage(source) {
        const imageSource = String(source || "")
        if (!imageSource.startsWith("file://") || root.invalidOwnedImageSources[imageSource] === true)
            return
        const path = imageSource.slice("file://".length)
        if (!NotificationImagePersistence.isOwnedPath(path, root.notificationImageCacheDirectory))
            return
        const affected = root.notificationHistory.some(entry => entry && entry.ownedImage === true
                                                              && entry.persistedImagePath === path)
        if (!affected)
            return
        const invalid = Object.assign({}, root.invalidOwnedImageSources)
        invalid[imageSource] = true
        root.invalidOwnedImageSources = invalid
        let historyChanged = false
        root.notificationHistory.forEach(entry => {
            if (entry && entry.ownedImage === true && entry.persistedImagePath === path) {
                entry.image = ""
                entry.persistedImagePath = ""
                entry.ownedImage = false
                NotificationImagePersistence.removeEntry(root.notificationImagePersistence, entry.id)
                historyChanged = true
            }
        })
        const invalidatePopups = popups => popups.forEach(popup => {
            if (popup && popup.ownedImage === true && popup.persistedImagePath === path) {
                popup.image = ""
                popup.persistedImagePath = ""
                popup.ownedImage = false
            }
        })
        invalidatePopups(root.notificationQueue)
        invalidatePopups(root.visibleNotifications)
        if (historyChanged) {
            root.notificationHistory = root.notificationHistory.slice()
            root.scheduleNotificationHistorySave()
        }
        root.notificationQueue = root.notificationQueue.slice()
        root.visibleNotifications = root.visibleNotifications.slice()
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
        root.notificationImageCaptureGeneration += 1
        const generation = root.notificationImageCaptureGeneration
        const path = NotificationImagePersistence.notificationImagePath(entry, root.notificationImageCacheDirectory,
                                                                        generation)
        const tempPath = NotificationImagePersistence.notificationImageTempPath(path, entry.id, generation)
        NotificationImagePersistence.begin(root.notificationImagePersistence, entry.id, generation, path, tempPath)
        const imageItem = notificationImageCaptureComponent.createObject(captureParent, {
            entryId: entry.id,
            targetPath: path,
            captureGeneration: generation,
            captureHost: captureParent,
            source: ""
        })
        if (!imageItem) {
            const outcome = NotificationImagePersistence.complete(root.notificationImagePersistence, entry.id, generation,
                                                                  false, Boolean(root.notificationImageEntry(entry.id)), true)
            if (outcome.retry)
                Qt.callLater(function () { root.materializeNotificationImage(entry.id) })
            return
        }
        const jobs = Object.assign({}, root.notificationImageCaptureJobs)
        jobs[entry.id] = {
            generation: generation,
            host: captureParent,
            imageItem: imageItem,
            path: path,
            tempPath: tempPath,
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
                    saved = Boolean(result && result.saveToFile(completedJob.tempPath))
                } catch (error) {
                    console.warn(`Failed to save notification image: ${error}`)
                }
                if (saved)
                    root.verifyNotificationImageTemp(entryId, generation)
                else
                    root.finishNotificationImageJob(entryId, generation, false, true)
            }, Qt.size(saveSize, saveSize))
        })
        mkdir.exec(["mkdir", "-p", "--", root.notificationImageCacheDirectory])
    }

    function runNotificationImageOperation(argumentsList, callback) {
        const operation = notificationImageOperationComponent.createObject(root)
        if (!operation) {
            callback(-1)
            return
        }
        operation.onExited.connect(function (exitCode) {
            operation.destroy()
            callback(exitCode)
        })
        operation.exec(argumentsList)
    }

    function verifyNotificationImageTemp(entryId, generation) {
        const job = root.activeNotificationImageJob(entryId, generation)
        if (!job)
            return
        root.runNotificationImageOperation(["test", "-s", job.tempPath], function (exitCode) {
            const currentJob = root.activeNotificationImageJob(entryId, generation)
            if (!currentJob) {
                root.deleteNotificationImageTemp(job.tempPath)
                root.deleteOwnedNotificationImage(job.path, true)
                return
            }
            if (exitCode !== 0) {
                root.finishNotificationImageJob(entryId, generation, false, true)
                return
            }
            root.runNotificationImageOperation(["mv", "-f", "--", currentJob.tempPath, currentJob.path], function (moveExitCode) {
                const movedJob = root.activeNotificationImageJob(entryId, generation)
                if (!movedJob) {
                    root.deleteNotificationImageTemp(job.tempPath)
                    root.deleteOwnedNotificationImage(job.path, true)
                    return
                }
                if (moveExitCode !== 0) {
                    root.finishNotificationImageJob(entryId, generation, false, true)
                    return
                }
                root.runNotificationImageOperation(["test", "-r", movedJob.path], function (readExitCode) {
                    if (!root.activeNotificationImageJob(entryId, generation)) {
                        root.deleteOwnedNotificationImage(job.path, true)
                        return
                    }
                    root.finishNotificationImageJob(entryId, generation, readExitCode === 0, readExitCode !== 0)
                })
            })
        })
    }

    function notificationImageItemDestroyed(entryId, generation) {
        const job = root.activeNotificationImageJob(entryId, generation)
        if (job)
            root.finishNotificationImageJob(entryId, generation, false, true)
    }

    function failNotificationImageCapture(entryId, generation, invalidLiveSource) {
        const job = root.activeNotificationImageJob(entryId, generation)
        if (!job)
            return
        if (invalidLiveSource)
            root.quarantineInvalidLiveImageSource(job.source, entryId, generation)
        root.finishNotificationImageJob(entryId, generation, false, !invalidLiveSource)
    }

    function cancelNotificationImageJob(entryId, generation, retry) {
        const job = root.activeNotificationImageJob(entryId, generation)
        if (job)
            root.finishNotificationImageJob(entryId, generation, false, retry)
    }

    function cancelAllNotificationImageJobs(retry) {
        Object.keys(root.notificationImageCaptureJobs).forEach(entryId => {
            const job = root.notificationImageCaptureJobs[entryId]
            if (job)
                root.cancelNotificationImageJob(entryId, job.generation, retry)
        })
    }

    function finishNotificationImageJob(entryId, generation, committed, allowRetry) {
        const job = root.activeNotificationImageJob(entryId, generation)
        if (!job)
            return
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
        const completionActive = root.notificationImageLifecycleActive && (committed || allowRetry)
        const outcome = NotificationImagePersistence.complete(root.notificationImagePersistence, entryId, generation, committed,
                                                               Boolean(current), completionActive)
        if (outcome.persisted) {
            const imageSource = `file://${job.path}`
            current.image = imageSource
            current.persistedImagePath = job.path
            current.ownedImage = true
            const updatePopups = popups => popups.forEach(popup => {
                if (popup && popup.historyEntryId === entryId) {
                    popup.image = imageSource
                    popup.persistedImagePath = job.path
                    popup.ownedImage = true
                }
            })
            updatePopups(root.notificationQueue)
            updatePopups(root.visibleNotifications)
            root.notificationHistory = root.notificationHistory.slice()
            root.notificationQueue = root.notificationQueue.slice()
            root.visibleNotifications = root.visibleNotifications.slice()
            root.scheduleNotificationHistorySave()
            return
        }

        root.deleteNotificationImageTemp(job.tempPath)
        root.deleteOwnedNotificationImage(job.path, true)

        if (outcome.retry && allowRetry)
            Qt.callLater(function () {
                if (root.notificationImageLifecycleActive)
                    root.materializeNotificationImage(entryId)
            })
    }

    function deleteNotificationImageTemp(path) {
        if (typeof path !== "string" || !path.startsWith(`${root.notificationImageCacheDirectory}/.notif_`)
                || path.indexOf(".png.part-") < 0 || !path.endsWith(".png"))
            return
        root.runNotificationImageOperation(["rm", "-f", "--", path], function () {})
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
        orphans.forEach(path => {
            if (NotificationImagePersistence.canDeleteOrphan(root.notificationImagePersistence, root.notificationHistory,
                                                             path, root.notificationImageCacheDirectory))
                root.deleteOwnedNotificationImage(path, true)
        })
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
            // A sender's action carries a callback into a process that may be
            // gone by the next run, so none of them survive the file. A
            // file path is a string, and the buttons it stands for are built on
            // this side, so it does — which is the whole reason they still work
            // in the center days later, and why they outlive the sender's own.
            actions: [],
            filePath: item.filePath || "",
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
            // Rebuilt from the stored path rather than restored, because an
            // action is a live callback and only its subject can be written
            // down. The guard runs again here: the file is editable by hand,
            // and last run's check says nothing about this run's contents.
            actions: root.notificationFileActions(item.filePath || ""),
            filePath: NotificationFileActions.isUsablePath(item.filePath) ? item.filePath : "",
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
        const now = Date.now()
        visible.forEach(popup => NotificationPopupTimeoutState.setActive(root.notificationPopupTimeoutState, popup.id, true,
                                                                          now))
        queued.forEach(popup => NotificationPopupTimeoutState.setActive(root.notificationPopupTimeoutState, popup.id, false,
                                                                         now))
    }

    function setNotificationPopupAvailableHeight(height) {
        const availableHeight = Math.max(0, height || 0)
        const popupSpacing = root.theme.spacing.space6
        const capacity = Math.max(root.minVisibleNotifications, Math.floor((availableHeight + popupSpacing) / (root.notificationPopupEstimatedHeight
                                                                                                               + popupSpacing)))
        if (root.notificationPopupCapacity === capacity)
            return
        root.notificationPopupCapacity = capacity
        root.processNotificationPopupQueue()
    }

    function closeNotificationPopup(id) {
        const wasVisible = root.visibleNotifications.some(popup => popup && popup.id === id)
        if (!wasVisible)
            return
        NotificationPopupTimeoutState.removePopup(root.notificationPopupTimeoutState, id)
        root.visibleNotifications = root.visibleNotifications.filter(popup => popup.id !== id)
        root.processNotificationPopupQueue()
        root.notificationPopupClosed(id)
    }

    function registerNotificationPopupManager() {
        root.notificationPopupManagerSequence += 1
        return `notification-popup-manager-${root.notificationPopupManagerSequence}`
    }

    function unregisterNotificationPopupManager(managerId) {
        NotificationPopupTimeoutState.releaseOwner(root.notificationPopupTimeoutState, managerId, Date.now())
    }

    function setNotificationPopupHovered(managerId, popupId, hovered) {
        NotificationPopupTimeoutState.setHovered(root.notificationPopupTimeoutState, managerId, popupId, hovered, Date.now())
    }

    function notificationPopupRemainingMs(id) {
        return NotificationPopupTimeoutState.remaining(root.notificationPopupTimeoutState, id, Date.now())
    }

    function expireNotificationPopups() {
        const expiredIds = NotificationPopupTimeoutState.tick(root.notificationPopupTimeoutState, Date.now())
        for (const id of expiredIds)
            root.closeNotificationPopup(id)
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
