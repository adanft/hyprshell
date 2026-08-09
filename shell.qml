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
            appLauncherLoader.open()
        }

        function toggle(): void {
            appLauncherLoader.toggle()
        }
    }
    IpcHandler {
        target: "powermenu"

        function open(): void {
            powerMenuLoader.open()
        }

        function toggle(): void {
            powerMenuLoader.toggle()
        }
    }
    IpcHandler {
        target: "wallpaperselector"

        function open(): void {
            wallpaperSelectorLoader.open()
        }

        function toggle(): void {
            wallpaperSelectorLoader.toggle()
        }
    }
    IpcHandler {
        target: "screenshot"

        function open(): void {
            screenshotToolLoader.open()
        }

        function toggle(): void {
            screenshotToolLoader.toggle()
        }
    }
    IpcHandler {
        target: "themeselector"

        function open(): void {
            themeSelectorLoader.open()
        }

        function toggle(): void {
            themeSelectorLoader.toggle()
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
