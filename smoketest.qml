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

    // Touch one value from each theme singleton so that a broken qmldir entry
    // surfaces as a failed lookup instead of passing unnoticed.
    Component.onCompleted: console.log("SMOKETEST: all components instantiated"
                                       + ` | colors=${Theme.AppTheme.colors.text}`
                                       + ` | typography=${Theme.AppTheme.typography.textFontFamily}`
                                       + ` | shape=${Theme.AppTheme.shape.radius16}`
                                       + ` | spacing=${Theme.AppTheme.spacing.space6}`
                                       + ` | sizing=${Theme.AppTheme.sizing.size24}`
                                       + ` | motion=${Theme.AppTheme.motion.durationNormal}`
                                       + ` | icons=${Theme.Icons.search}`)

    Timer {
        interval: smoketest.settleMs
        running: true
        repeat: false
        onTriggered: Qt.quit()
    }
}
