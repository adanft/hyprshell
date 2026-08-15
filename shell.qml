//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "features/applauncher" as Applauncher
import "features/bluetoothpairing" as Bluetoothpairing
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

        // This is the shell a person is looking at, so this is the one that
        // owns the pairing socket.
        pairingAgentEnabled: true
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

    // Not a loader, and deliberately absent from the arbiter's list.
    //
    // The other five are opened by the person using them, so the arbiter may
    // close any of them to make room. This one is opened by a device asking a
    // question BlueZ is waiting on, and closing it means refusing that pairing
    // — not something another overlay should be able to do by opening. So it
    // displaces the others and nothing displaces it.
    //
    // It stays instantiated rather than lazily loaded because it has no toggle
    // to hang the loading off: the request arrives on its own schedule, and a
    // dialog that had to be built first would miss the moment.
    Bluetoothpairing.BluetoothPairing {
        id: bluetoothPairing

        services: serviceState
        onActiveChanged: {
            if (active)
                overlayArbiter.closeOthers(null)
        }
    }

    // IpcHandler publishes every property it carries, and a loader property is
    // not serializable, so these stay as plain declarations calling their own
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
