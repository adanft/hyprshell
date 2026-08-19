import QtQuick
import Quickshell
import "../theme"
import "capabilities" as Capabilities

Scope {
    id: root

    readonly property var theme: AppTheme
    readonly property string activeUserAvatarSource: activeUserAvatar.source
    readonly property string activeUserAvatarState: activeUserAvatar.state
    // Whether this process is the one that owns the pairing agent socket. Off
    // by default so a harness or a smoke test that builds these services does
    // not take it from the shell that is actually running.
    property bool pairingAgentEnabled: false

    readonly property string time: Qt.formatDateTime(systemClock.date, "HH:mm")
    readonly property string date: Qt.formatDateTime(systemClock.date, "MM-dd")

    Capabilities.AudioService {
        id: audioService
    }
    Capabilities.BrightnessService {
        id: brightnessService
    }
    Capabilities.NetworkService {
        id: networkService
    }
    Capabilities.NotificationService {
        id: notificationService
        theme: root.theme
    }
    Capabilities.BatteryPowerService {
        id: batteryPowerService
    }
    Capabilities.BluetoothService {
        id: bluetoothService
    }
    Capabilities.PairingAgentService {
        id: pairingAgentService

        // The one place the two capabilities meet: the agent only has work to
        // do while the adapter is on, and only this root can see both.
        bluetoothPowered: bluetoothService.bluetoothPowered
        pairingAgentEnabled: root.pairingAgentEnabled
    }
    Capabilities.SystemStatsService {
        id: systemStatsService
    }
    Capabilities.WorkspaceService {
        id: workspaceService
    }

    readonly property alias audio: audioService
    readonly property alias brightness: brightnessService
    readonly property alias network: networkService
    readonly property alias notification: notificationService
    readonly property alias batteryPower: batteryPowerService
    readonly property alias bluetooth: bluetoothService
    // Kept apart from `bluetooth` because it is a different authority: one is
    // the adapter, the other is the agent process that answers BlueZ. Folding
    // them together would make a shell without the agent look like a shell
    // without Bluetooth.
    readonly property alias pairingAgent: pairingAgentService
    readonly property alias systemStats: systemStatsService
    readonly property alias workspace: workspaceService

    Capabilities.ActiveUserAvatar {
        id: activeUserAvatar
    }
    // The bar renders HH:mm and MM-dd, so minute precision is the resolution
    // the display actually has. A second-precision clock wakes the process 59
    // extra times per minute to recompute an identical string.
    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }
}
