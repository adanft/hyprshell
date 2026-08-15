//@ pragma UseQApplication

// Smoke test entrypoint.
//
// Running `qs -p shell.qml` does NOT compile the overlays: they sit behind
// OverlayLifecycleLoader, which is a LazyLoader with `active: false`, so their
// QML is only parsed the first time the user opens them. A change that breaks
// AppLauncher, PowerMenu, ScreenshotTool, ThemeSelector or WallpaperSelector
// therefore starts cleanly and only fails later, in front of the user.
//
// This entrypoint instantiates every window eagerly so that a single run
// compiles the whole tree. Run it with:
//
//     qs -p smoketest.qml
//
// Every component must supply its required properties here; a missing one
// reports as a TypeError against the component rather than against this file.
//
// QML warnings do not affect the process exit code, so a run is only clean when
// the output contains "SMOKETEST: all components instantiated" and no WARN or
// ERROR lines.

import QtQuick
import Quickshell
import "features/applauncher" as Applauncher
import "features/notifications" as Notifications
import "features/powermenu" as Powermenu
import "features/screenshot" as Screenshot
import "services" as Services
import "features/statusbar" as Statusbar
import "features/controlcenter" as Controlcenter
import "features/statusbar/components" as BarComponents
import "theme" as Theme
import "theme/runtime" as ThemeRuntime
import "features/themeselector" as Themeselector
import "features/wallpaperselector" as Wallpaperselector

ShellRoot {
    id: smoketest

    // A ceiling, not a schedule. Nothing waits for it in the ordinary case.
    readonly property int settleTimeoutMs: 15000
    property bool captureCompleted: false
    property bool captureStarted: false
    property bool notificationLifecycleCompleted: false
    property var lifecycleHost: null
    property string lifecyclePublishedEntryId: ""
    readonly property string lifecycleImage: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='8' height='8'%3E%3Crect width='8' height='8' fill='blue'/%3E%3C/svg%3E"

    Services.Services {
        id: serviceState
    }

    Applauncher.AppLauncher {}
    Powermenu.PowerMenu {}
    Screenshot.ScreenshotTool {}
    Themeselector.ThemeSelector {}
    Wallpaperselector.WallpaperSelector {}

    // Reached through ControlCenter at runtime, instantiated here so that a
    // standalone compile error cannot hide behind a closed menu.
    Controlcenter.WifiPasswordModal {
        screen: Quickshell.screens[0]
        theme: Theme.AppTheme
    }

    // Grid delegates. Instantiating their panel is not enough: a delegate is
    // only built when its view lays out, and these views never do here because
    // nothing is shown, so a broken binding inside one raises no warning and the
    // run stays green. That is exactly how a card left referencing an undefined
    // `sizing` reached the user. The control center's rows do not need this —
    // each already has a qmltestrunner case of its own.
    Applauncher.AppLauncherCard {
        app: null
        theme: Theme.AppTheme
    }

    Themeselector.ThemeCard {
        // A whole entry rather than null: the card reads eight fields off it,
        // and the model never hands it nothing, so a null here would assert a
        // guard the shell does not need.
        themeData: ({
                "displayName": "smoke",
                "surface": Theme.Colors.surface,
                "on_surface": Theme.Colors.on_surface,
                "outline": Theme.Colors.outline,
                "primary": Theme.Colors.primary,
                "secondary": Theme.Colors.secondary,
                "tertiary": Theme.Colors.tertiary,
                "hover": Theme.Colors.hover
            })
    }

    Wallpaperselector.WallpaperCard {
        path: ""
        label: "smoke"
    }

    Variants {
        model: Quickshell.screens

        Statusbar.BarWindow {
            id: barWindow

            required property var modelData

            screen: modelData
            services: serviceState

            Notifications.NotificationCenter {
                services: serviceState
                barWindow: barWindow
            }
            Notifications.NotificationPopupManager {
                services: serviceState
                barWindow: barWindow
            }

        }
    }

    Component {
        id: smokeCaptureImageComponent

        Image {
            width: 8
            height: 8
            source: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='8' height='8'%3E%3Crect width='8' height='8' fill='red'/%3E%3C/svg%3E"
            onStatusChanged: {
                if (status === Image.Ready)
                    grabToImage(result => {
                        if (!result) {
                            console.error("SMOKETEST: notification image capture failed")
                            Qt.quit()
                            return
                        }
                        smoketest.captureCompleted = true
                        destroy()
                    })
                else if (status === Image.Error) {
                    console.error("SMOKETEST: notification capture image failed to load")
                    Qt.quit()
                }
            }
        }
    }

    Component {
        id: lifecycleHostComponent

        Item {
            readonly property string captureHostKey: ""
            readonly property var captureWindow: Window.window
            width: 8
            height: 8
            x: -width - 1
        }
    }

    Component {
        id: lifecyclePopupComponent

        Notifications.NotificationPopup {
            width: 320
            services: serviceState
            hoverOwnerId: "smoketest-lifecycle-popup"
        }
    }

    Component {
        id: lifecycleCardComponent

        Notifications.NotificationCard {
            width: 320
            notificationService: serviceState.notification
        }
    }

    function exerciseNotificationImageCapture(host) {
        if (!host || !host.Window.window) {
            console.error("SMOKETEST: notification capture host is not attached to a window")
            Qt.quit()
            return
        }
        if (!host.captureWindow || host.captureWindow.objectName.indexOf("qs-statusbar:") !== 0) {
            console.error("SMOKETEST: notification capture host is not owned by a status bar")
            Qt.quit()
            return
        }
        const hosts = serviceState.notification.notificationImageCaptureHosts
        const hostWindows = hosts.map(candidate => candidate.captureWindow)
        const uniqueHostWindows = hostWindows.filter((candidate, index) => hostWindows.indexOf(candidate) === index)
        if (hosts.length !== Quickshell.screens.length
                || uniqueHostWindows.length !== hosts.length
                || hosts.some(candidate => !candidate.Window.window)) {
            console.error("SMOKETEST: capture hosts do not map one-to-one to status bar windows")
            Qt.quit()
            return
        }
        console.log(`SMOKETEST: capture top-level delta=0 | type=PanelWindow | hosts=${hosts.length} | windows=${hostWindows.length}`)
        smoketest.captureStarted = true
        smokeCaptureImageComponent.createObject(host)
        smoketest.exerciseNotificationLifecycle(host)
    }

    function exerciseNotificationLifecycle(host) {
        const service = serviceState.notification
        const temporaryHost = lifecycleHostComponent.createObject(host)
        smoketest.lifecycleHost = temporaryHost
        service.registerNotificationImageCaptureHost(temporaryHost)
        const first = {
            id: "smoke-lifecycle-first",
            image: "image://qsimage/smoke-first",
            timestamp: 1,
            notification: { id: 1 }
        }
        service.notificationHistory = [first]
        service.startNotificationImageCapture(first, temporaryHost, smoketest.lifecycleImage)

        // Popup/card destruction, center opening and DND must not own the capture.
        const popupData = { id: 1, historyEntryId: first.id, image: smoketest.lifecycleImage }
        const popup = lifecyclePopupComponent.createObject(host, { popupData: popupData })
        popup.destroy()
        service.visibleNotifications = [popupData]
        service.setNotificationCenterOpen(true)
        service.toggleNotificationDnd()
        if (Object.keys(service.notificationImageCaptureJobs).length !== 1) {
            console.error("SMOKETEST: popup cleanup invalidated a service-owned image job")
            Qt.quit()
            return
        }

        // Host removal cancels by generation; the deferred retry may use a bar host.
        service.unregisterNotificationImageCaptureHost(temporaryHost)
        temporaryHost.destroy()
        service.notificationHistory = service.notificationHistory.filter(entry => entry.id !== first.id)
        service.removeOwnedNotificationImage(first)

        const failed = {
            id: "smoke-lifecycle-error",
            image: "image://qsimage/smoke-error",
            timestamp: 2,
            notification: { id: 2 }
        }
        service.notificationHistory = service.notificationHistory.concat([failed])
        const failedSource = failed.image
        service.startNotificationImageCapture(failed, host, smoketest.lifecycleImage)
        const failedJob = service.notificationImageCaptureJobs[failed.id]
        service.failNotificationImageCapture(failed.id, failedJob.generation, true)
        if (!service.isInvalidLiveImageSource(failedSource)
                || service.notificationImageEntry(failed.id).image !== "") {
            console.error("SMOKETEST: live image error did not converge to quarantine")
            Qt.quit()
            return
        }

        const published = {
            id: "smoke-lifecycle-published",
            image: smoketest.lifecycleImage,
            timestamp: 3,
            notification: { id: 3 }
        }
        smoketest.lifecyclePublishedEntryId = published.id
        service.notificationHistory = service.notificationHistory.concat([published])
        service.startNotificationImageCapture(published, host, published.image)

        lifecycleSettleTimer.start()
    }

    Timer {
        interval: 50
        running: !smoketest.captureStarted
        repeat: true
        onTriggered: {
            const host = serviceState.notification.notificationImageCaptureHost
            if (host)
                smoketest.exerciseNotificationImageCapture(host)
        }
    }

    // The second fixed deadline in this file, and it outlived the first by a
    // few minutes: waiting one second for the capture jobs to drain held while
    // the smoke test was the only thing running and stopped holding once other
    // stages ran ahead of it, reporting "left pending jobs" about work that was
    // simply still going. Polled for the same reason and with the same shape as
    // the settle below — a drain that finishes in fifty milliseconds is checked
    // in fifty.
    Timer {
        id: lifecycleSettleTimer

        property int waitedMs: 0

        interval: 50
        repeat: true
        onTriggered: {
            const service = serviceState.notification
            const drained = Object.keys(service.notificationImageCaptureJobs).length === 0
                && Object.keys(service.notificationImagePersistence.pending).length === 0
            if (!drained) {
                lifecycleSettleTimer.waitedMs += lifecycleSettleTimer.interval
                if (lifecycleSettleTimer.waitedMs < smoketest.settleTimeoutMs)
                    return
                lifecycleSettleTimer.running = false
                console.error("SMOKETEST: notification lifecycle left pending jobs or retries")
                Qt.quit()
                return
            }

            lifecycleSettleTimer.running = false

            const published = service.notificationImageEntry(smoketest.lifecyclePublishedEntryId)
            if (!published || published.ownedImage !== true || !String(published.image).startsWith("file://")) {
                console.error("SMOKETEST: notification transaction published no verified owned image")
                Qt.quit()
                return
            }
            const missingPath = `${service.notificationImageCacheDirectory}/notif_4_4_4.png`
            const missingSource = `file://${missingPath}`
            const missingA = { id: "missing-a", image: missingSource, persistedImagePath: missingPath, ownedImage: true }
            const missingB = { id: "missing-b", image: missingSource, persistedImagePath: missingPath, ownedImage: true }
            service.notificationHistory = service.notificationHistory.concat([missingA, missingB])
            service.visibleNotifications = [{ id: 41, historyEntryId: missingA.id, image: missingSource,
                                                persistedImagePath: missingPath, ownedImage: true }]
            service.notificationQueue = [{ id: 42, historyEntryId: missingB.id, image: missingSource,
                                            persistedImagePath: missingPath, ownedImage: true }]
            service.invalidateOwnedNotificationImage(missingSource)
            service.invalidateOwnedNotificationImage(missingSource)
            const cardA = lifecycleCardComponent.createObject(service.notificationImageCaptureHost, { notificationData: missingA })
            const cardB = lifecycleCardComponent.createObject(service.notificationImageCaptureHosts[service.notificationImageCaptureHosts.length - 1],
                                                               { notificationData: missingB })
            if (Object.keys(service.invalidOwnedImageSources).length !== 1 || missingA.image !== "" || missingB.image !== ""
                    || cardA.iconSource === missingSource || cardB.iconSource === missingSource) {
                console.error("SMOKETEST: repeated owned image errors did not converge globally")
                Qt.quit()
                return
            }
            cardA.destroy()
            cardB.destroy()
            service.notificationHistory = service.notificationHistory.filter(entry => entry.id !== missingA.id
                                                                               && entry.id !== missingB.id)
            service.removeOwnedNotificationImage(published)
            service.notificationHistory = service.notificationHistory.filter(entry => entry.id !== published.id)
            smoketest.notificationLifecycleCompleted = true
            console.log("SMOKETEST: notification lifecycle capture/card/center/dnd/host/error passed")
        }
    }

    // Touch one value from each theme singleton so that a broken qmldir entry
    // surfaces as a failed lookup instead of passing unnoticed.
    //
    // This waits for the work to finish rather than for a deadline it was
    // assumed to fit inside. It used to check once at three seconds, which held
    // while the smoke test ran alone and stopped holding once other compositor
    // stages ran before it: every assertion below then reported on work that had
    // simply not finished, so a healthy shell failed on a stopwatch. Polling
    // also makes the ordinary run shorter, because it stops the moment there is
    // something to check.
    Timer {
        id: settleTimer

        property int waitedMs: 0

        interval: 100
        running: true
        repeat: true
        onTriggered: {
            settleTimer.waitedMs += settleTimer.interval

            // The palette arrives over a FileView, so "loaded" is a third thing
            // to wait for. Waiting for the data to exist is not the same as
            // waiting for the comparison to succeed: a role whose binding is
            // dead still fails below, which is the whole point of checking it.
            const palette = ThemeRuntime.StockThemes.themeData
            const paletteLoaded = palette && Object.keys(palette).length > 1

            if (!smoketest.captureCompleted || !smoketest.notificationLifecycleCompleted || !paletteLoaded) {
                if (settleTimer.waitedMs < smoketest.settleTimeoutMs)
                    return
                if (!smoketest.captureCompleted)
                    console.error("SMOKETEST: notification image capture did not complete")
                else if (!smoketest.notificationLifecycleCompleted)
                    console.error("SMOKETEST: notification lifecycle did not complete")
                else
                    console.error("SMOKETEST: the theme palette never loaded")
                Qt.quit()
                return
            }

            settleTimer.running = false

            // A QML color property whose binding never took reads as opaque
            // black, and nothing else in the suite can see that: the theme data
            // is correct, only the property is dead. Compare every role against
            // the palette it came from.
            const unresolved = Object.keys(palette).filter(role => role !== "displayName").filter(role => {
                return String(Theme.Colors[role]).toLowerCase() !== String(palette[role]).toLowerCase()
            })
            if (unresolved.length > 0) {
                console.error(`SMOKETEST: color roles did not resolve: ${unresolved.join(", ")}`)
                Qt.quit()
                return
            }
            console.log(`SMOKETEST: ${Object.keys(palette).length - 1} color roles resolved`)
            console.log("SMOKETEST: all components instantiated"
                        + ` | colors=${Theme.Colors.on_surface}`
                        + ` | typography=${Theme.AppTheme.typography.textFontFamily}`
                        + ` | shape=${Theme.AppTheme.shape.radius16}`
                        + ` | spacing=${Theme.AppTheme.spacing.space6}`
                        + ` | sizing=${Theme.AppTheme.sizing.size24}`
                        + ` | motion=${Theme.AppTheme.motion.durationNormal}`
                        + ` | icons=${Theme.Icons.ui.search}`)
            Qt.quit()
        }
    }
}
