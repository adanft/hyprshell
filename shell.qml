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
import "wallpaperselector" as Wallpaperselector

ShellRoot {
    id: shell

    Theme.Colors {
        id: themeColors
    }
    Services.Services {
        id: serviceState
    }

    Applauncher.AppLauncher {
        id: appLauncher
    }
    Powermenu.PowerMenu {
        id: powerMenu
    }
    Wallpaperselector.WallpaperSelector {
        id: wallpaperSelector
    }
    Screenshot.ScreenshotTool {
        id: screenshotTool
    }

    IpcHandler {
        target: "applauncher"

        function open(): void {
            shell.openAppLauncher();
        }

        function toggle(): void {
            shell.toggleAppLauncher();
        }
    }

    IpcHandler {
        target: "powermenu"

        function open(): void {
            shell.openPowerMenu();
        }

        function toggle(): void {
            shell.togglePowerMenu();
        }
    }

    IpcHandler {
        target: "wallpaperselector"

        function open(): void {
            shell.openWallpaperSelector();
        }

        function toggle(): void {
            shell.toggleWallpaperSelector();
        }
    }

    IpcHandler {
        target: "screenshot"

        function open(): void {
            shell.openScreenshotTool();
        }

        function toggle(): void {
            shell.toggleScreenshotTool();
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

            onOpenNotificationCenterRequested: notificationCenter.visible = !notificationCenter.visible

            Notifications.NotificationCenter {
                id: notificationCenter

                colors: themeColors
                services: serviceState
                barWindow: barWindow
            }

            Notifications.NotificationPopupManager {
                colors: themeColors
                services: serviceState
                barWindow: barWindow
            }
        }
    }

    function openPowerMenu() {
        powerMenu.open();
    }

    function openAppLauncher() {
        appLauncher.open();
    }

    function toggleAppLauncher() {
        appLauncher.toggle();
    }

    function togglePowerMenu() {
        powerMenu.toggle();
    }

    function openWallpaperSelector() {
        wallpaperSelector.open();
    }

    function toggleWallpaperSelector() {
        wallpaperSelector.toggle();
    }

    function openScreenshotTool() {
        screenshotTool.open();
    }

    function toggleScreenshotTool() {
        screenshotTool.toggle();
    }
}
