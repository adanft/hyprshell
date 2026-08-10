//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "features/applauncher" as Applauncher
import "features/notifications" as Notifications
import "features/powermenu" as Powermenu
import "features/screenshot" as Screenshot
import "services" as Services
import "features/statusbar" as Statusbar
import "theme" as Theme
import "theme/runtime" as ThemeRuntime
import "features/themeselector" as Themeselector
import "features/wallpaperselector" as Wallpaperselector

ShellRoot {
    id: shell

    OverlayArbiter {
        id: overlayArbiter

        loaders: [appLauncherLoader, powerMenuLoader, wallpaperSelectorLoader, themeSelectorLoader, screenshotToolLoader]
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
