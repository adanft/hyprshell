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
import "themeselector" as Themeselector
import "wallpaperselector" as Wallpaperselector

ShellRoot {
    id: shell

    Theme.Colors {
        id: themeColors
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

    IpcHandler {
        target: "applauncher"

        function open(): void {
            shell.openAppLauncher()
        }

        function toggle(): void {
            shell.toggleAppLauncher()
        }
    }

    IpcHandler {
        target: "powermenu"

        function open(): void {
            shell.openPowerMenu()
        }

        function toggle(): void {
            shell.togglePowerMenu()
        }
    }

    IpcHandler {
        target: "wallpaperselector"

        function open(): void {
            shell.openWallpaperSelector()
        }

        function toggle(): void {
            shell.toggleWallpaperSelector()
        }
    }

    IpcHandler {
        target: "screenshot"

        function open(): void {
            shell.openScreenshotTool()
        }

        function toggle(): void {
            shell.toggleScreenshotTool()
        }
    }

    IpcHandler {
        target: "themeselector"

        function open(): void {
            shell.openThemeSelector()
        }

        function toggle(): void {
            shell.toggleThemeSelector()
        }

        function set(name: string): void {
            themeColors.setTheme(name)
        }
    }

    Variants {
        model: Quickshell.screens

        Statusbar.BarWindow {
            id: barWindow

            required property var modelData

            screen: modelData
            colors: themeColors
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
                    colors: themeColors
                    services: serviceState
                    barWindow: notificationCenterLoader.ownerWindow
                }
            }

            Notifications.NotificationPopupManager {
                colors: themeColors
                services: serviceState
                barWindow: barWindow
            }
        }
    }

    function openPowerMenu() {
        powerMenuLoader.open()
    }

    function openAppLauncher() {
        appLauncherLoader.open()
    }

    function toggleAppLauncher() {
        appLauncherLoader.toggle()
    }

    function togglePowerMenu() {
        powerMenuLoader.toggle()
    }

    function openWallpaperSelector() {
        wallpaperSelectorLoader.open()
    }

    function toggleWallpaperSelector() {
        wallpaperSelectorLoader.toggle()
    }

    function openScreenshotTool() {
        screenshotToolLoader.open()
    }

    function toggleScreenshotTool() {
        screenshotToolLoader.toggle()
    }

    function openThemeSelector() {
        themeSelectorLoader.open()
    }

    function toggleThemeSelector() {
        themeSelectorLoader.toggle()
    }
}
