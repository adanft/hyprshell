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

    LazyLoader {
        id: appLauncherLoader
        property bool requestedVisible: false
        active: false

        Applauncher.AppLauncher {}
    }
    LazyLoader {
        id: powerMenuLoader
        property bool requestedVisible: false
        active: false

        Powermenu.PowerMenu {}
    }
    LazyLoader {
        id: wallpaperSelectorLoader
        property bool requestedVisible: false
        active: false

        Wallpaperselector.WallpaperSelector {}
    }
    LazyLoader {
        id: themeSelectorLoader
        property bool requestedVisible: false
        active: false

        Themeselector.ThemeSelector {}
    }
    LazyLoader {
        id: screenshotToolLoader
        property bool requestedVisible: false
        active: false

        Screenshot.ScreenshotTool {}
    }

    Connections {
        target: appLauncherLoader.item
        enabled: target !== null
        function onVisibleChanged() {
            const window = appLauncherLoader.item;
            if (window && !window.visible) {
                appLauncherLoader.requestedVisible = false;
                appLauncherLoader.active = false;
            }
        }
    }
    Connections {
        target: powerMenuLoader.item
        enabled: target !== null
        function onVisibleChanged() {
            const window = powerMenuLoader.item;
            if (window && !window.visible) {
                powerMenuLoader.requestedVisible = false;
                powerMenuLoader.active = false;
            }
        }
    }
    Connections {
        target: wallpaperSelectorLoader.item
        enabled: target !== null
        function onVisibleChanged() {
            const window = wallpaperSelectorLoader.item;
            if (window && !window.visible) {
                wallpaperSelectorLoader.requestedVisible = false;
                wallpaperSelectorLoader.active = false;
            }
        }
    }
    Connections {
        target: themeSelectorLoader.item
        enabled: target !== null
        function onVisibleChanged() {
            const window = themeSelectorLoader.item;
            if (window && !window.visible) {
                themeSelectorLoader.requestedVisible = false;
                themeSelectorLoader.active = false;
            }
        }
    }
    Connections {
        target: screenshotToolLoader.item
        enabled: target !== null
        function onVisibleChanged() {
            const window = screenshotToolLoader.item;
            if (window && !window.visible) {
                screenshotToolLoader.requestedVisible = false;
                screenshotToolLoader.active = false;
            }
        }
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

    IpcHandler {
        target: "themeselector"

        function open(): void {
            shell.openThemeSelector();
        }

        function toggle(): void {
            shell.toggleThemeSelector();
        }

        function set(name: string): void {
            themeColors.setTheme(name);
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
                notificationCenterLoader.requestedVisible = !notificationCenterLoader.requestedVisible;
                if (!notificationCenterLoader.requestedVisible) {
                    if (notificationCenterLoader.item)
                        notificationCenterLoader.item.visible = false;
                    else
                        notificationCenterLoader.active = false;
                    return;
                }

                notificationCenterLoader.active = true;
                Qt.callLater(() => {
                    if (notificationCenterLoader.requestedVisible
                            && notificationCenterLoader.item)
                        notificationCenterLoader.item.visible = true;
                });
            }

            function syncNotificationPopupLoader() {
                if (serviceState.visibleNotifications.length > 0) {
                    notificationPopupLoader.active = true;
                    Qt.callLater(() => {
                        const manager = notificationPopupLoader.item;
                        if (manager && !manager.isFocusedScreen)
                            notificationPopupLoader.active = false;
                    });
                    return;
                }

                if (notificationPopupLoader.item
                        && notificationPopupLoader.item.popupItems.length === 0)
                    notificationPopupLoader.active = false;
            }

            onOpenNotificationCenterRequested: toggleNotificationCenter()

            LazyLoader {
                id: notificationCenterLoader
                property bool requestedVisible: false
                property var ownerWindow: barWindow
                active: false

                Notifications.NotificationCenter {
                    colors: themeColors
                    services: serviceState
                    barWindow: notificationCenterLoader.ownerWindow
                }
            }

            Connections {
                target: notificationCenterLoader.item
                enabled: target !== null
                function onVisibleChanged() {
                    const center = notificationCenterLoader.item;
                    if (center && !center.visible) {
                        notificationCenterLoader.requestedVisible = false;
                        notificationCenterLoader.active = false;
                    }
                }
            }

            LazyLoader {
                id: notificationPopupLoader
                property var ownerWindow: barWindow
                active: false

                Notifications.NotificationPopupManager {
                    colors: themeColors
                    services: serviceState
                    barWindow: notificationPopupLoader.ownerWindow
                }
            }

            Connections {
                target: notificationPopupLoader.item
                enabled: target !== null
                function onVisibleChanged() {
                    const manager = notificationPopupLoader.item;
                    if (manager && !manager.visible
                            && serviceState.visibleNotifications.length === 0)
                        notificationPopupLoader.active = false;
                }
            }

            Connections {
                target: serviceState

                function onVisibleNotificationsChanged() {
                    barWindow.syncNotificationPopupLoader();
                }

                function onFocusedNotificationScreenNameChanged() {
                    barWindow.syncNotificationPopupLoader();
                }
            }

            Component.onCompleted: syncNotificationPopupLoader()
        }
    }

    function openLoader(loader) {
        loader.requestedVisible = true;
        loader.active = true;
        Qt.callLater(() => {
            if (loader.requestedVisible && loader.item)
                loader.item.open();
        });
    }

    function toggleLoader(loader) {
        loader.requestedVisible = !loader.requestedVisible;
        if (!loader.requestedVisible) {
            if (loader.item && loader.item.visible)
                loader.item.toggle();
            else
                loader.active = false;
            return;
        }

        loader.active = true;
        Qt.callLater(() => {
            if (loader.requestedVisible && loader.item)
                loader.item.open();
        });
    }

    function openPowerMenu() {
        openLoader(powerMenuLoader);
    }

    function openAppLauncher() {
        openLoader(appLauncherLoader);
    }

    function toggleAppLauncher() {
        toggleLoader(appLauncherLoader);
    }

    function togglePowerMenu() {
        toggleLoader(powerMenuLoader);
    }

    function openWallpaperSelector() {
        openLoader(wallpaperSelectorLoader);
    }

    function toggleWallpaperSelector() {
        toggleLoader(wallpaperSelectorLoader);
    }

    function openScreenshotTool() {
        openLoader(screenshotToolLoader);
    }

    function toggleScreenshotTool() {
        toggleLoader(screenshotToolLoader);
    }

    function openThemeSelector() {
        openLoader(themeSelectorLoader);
    }

    function toggleThemeSelector() {
        toggleLoader(themeSelectorLoader);
    }
}
