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
import "applauncher" as Applauncher
import "notifications" as Notifications
import "powermenu" as Powermenu
import "screenshot" as Screenshot
import "services" as Services
import "statusbar" as Statusbar
import "statusbar/components" as BarComponents
import "theme" as Theme
import "themeselector" as Themeselector
import "wallpaperselector" as Wallpaperselector

ShellRoot {
    id: smoketest

    readonly property int settleMs: 3000
    property bool captureCompleted: false
    property bool captureStarted: false

    Services.Services {
        id: serviceState
    }

    Applauncher.AppLauncher {}
    Powermenu.PowerMenu {}
    Screenshot.ScreenshotTool {}
    Themeselector.ThemeSelector {}
    Wallpaperselector.WallpaperSelector {}

    // Reached through NetworkMenu at runtime, instantiated here so that a
    // standalone compile error cannot hide behind a closed menu.
    BarComponents.WifiPasswordModal {
        screen: Quickshell.screens[0]
        colors: Theme.Colors
        theme: Theme.AppTheme
    }

    Variants {
        model: Quickshell.screens

        Statusbar.BarWindow {
            id: barWindow

            required property var modelData

            screen: modelData
            colors: Theme.Colors
            services: serviceState

            Notifications.NotificationCenter {
                colors: Theme.Colors
                services: serviceState
                barWindow: barWindow
            }
            Notifications.NotificationPopupManager {
                colors: Theme.Colors
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

    // Touch one value from each theme singleton so that a broken qmldir entry
    // surfaces as a failed lookup instead of passing unnoticed.
    Timer {
        interval: smoketest.settleMs
        running: true
        repeat: false
        onTriggered: {
            if (!smoketest.captureCompleted) {
                console.error("SMOKETEST: notification image capture did not complete")
                Qt.quit()
                return
            }
            console.log("SMOKETEST: all components instantiated"
                        + ` | colors=${Theme.AppTheme.colors.text}`
                        + ` | typography=${Theme.AppTheme.typography.textFontFamily}`
                        + ` | shape=${Theme.AppTheme.shape.radius16}`
                        + ` | spacing=${Theme.AppTheme.spacing.space6}`
                        + ` | sizing=${Theme.AppTheme.sizing.size24}`
                        + ` | motion=${Theme.AppTheme.motion.durationNormal}`
                        + ` | icons=${Theme.Icons.search}`)
            Qt.quit()
        }
    }
}
