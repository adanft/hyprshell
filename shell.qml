//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "applauncher" as Applauncher
import "notifications" as Notifications
import "powermenu" as Powermenu
import "screenshot" as Screenshot
import "services" as Services
import "statusbar" as Statusbar
import "theme" as Theme
import "theme/runtime" as ThemeRuntime
import "themeselector" as Themeselector
import "wallpaperselector" as Wallpaperselector

ShellRoot {
    id: shell

    // Eager on purpose: it is the read of Hyprland.monitors that makes
    // focusedMonitor answer, and the overlays it serves are lazily loaded.
    OverlayScreenResolver {
        id: overlayScreenResolver
    }

    OverlayArbiter {
        id: overlayArbiter

        loaders: [appLauncherLoader, powerMenuLoader, wallpaperSelectorLoader, themeSelectorLoader, screenshotToolLoader]
        screenResolver: overlayScreenResolver
    }

    Services.Services {
        id: serviceState
    }

    OverlayLifecycleLoader {
        id: appLauncherLoader

        Applauncher.AppLauncher {}
    }
    OverlayLifecycleLoader {
        id: powerMenuLoader

        Powermenu.PowerMenu {}
    }
    OverlayLifecycleLoader {
        id: wallpaperSelectorLoader

        Wallpaperselector.WallpaperSelector {}
    }
    OverlayLifecycleLoader {
        id: themeSelectorLoader

        Themeselector.ThemeSelector {}
    }
    OverlayLifecycleLoader {
        id: screenshotToolLoader

        Screenshot.ScreenshotTool {}
    }

    // IpcHandler publishes every property it carries, and a loader property is
    // not serialisable, so these stay as plain declarations calling their own
    // loader rather than being collapsed into a shared handler type.
    IpcHandler {
        target: "applauncher"

        function open(): void {
            overlayArbiter.open(appLauncherLoader)
        }

        function toggle(): void {
            overlayArbiter.toggle(appLauncherLoader)
        }
    }
    IpcHandler {
        target: "powermenu"

        function open(): void {
            overlayArbiter.open(powerMenuLoader)
        }

        function toggle(): void {
            overlayArbiter.toggle(powerMenuLoader)
        }
    }
    IpcHandler {
        target: "wallpaperselector"

        function open(): void {
            overlayArbiter.open(wallpaperSelectorLoader)
        }

        function toggle(): void {
            overlayArbiter.toggle(wallpaperSelectorLoader)
        }
    }
    IpcHandler {
        target: "screenshot"

        function open(): void {
            overlayArbiter.open(screenshotToolLoader)
        }

        function toggle(): void {
            overlayArbiter.toggle(screenshotToolLoader)
        }
    }
    IpcHandler {
        target: "themeselector"

        function open(): void {
            overlayArbiter.open(themeSelectorLoader)
        }

        function toggle(): void {
            overlayArbiter.toggle(themeSelectorLoader)
        }

        function set(name: string): void {
            ThemeRuntime.StockThemes.setTheme(name)
        }
    }

    Variants {
        model: Quickshell.screens

        Statusbar.BarWindow {
            id: barWindow

            required property var modelData

            screen: modelData
            services: serviceState

            function toggleNotificationCenter() {
                notificationCenterLoader.toggle()
            }

            onOpenNotificationCenterRequested: toggleNotificationCenter()

            OverlayLifecycleLoader {
                id: notificationCenterLoader

                directVisibility: true

                property var ownerWindow: barWindow

                Notifications.NotificationCenter {
                    services: serviceState
                    barWindow: notificationCenterLoader.ownerWindow
                }
            }

            Notifications.NotificationPopupManager {
                services: serviceState
                barWindow: barWindow
            }
        }
    }
}
