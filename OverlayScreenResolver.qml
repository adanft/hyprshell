import QtQuick
import Quickshell
import Quickshell.Hyprland
import "OverlayScreen.js" as OverlayScreen

// The compositor half of picking an overlay's monitor. Kept apart from
// OverlayArbiter so the arbiter carries no Quickshell or Hyprland import and
// can be exercised on its own.
QtObject {
    id: resolver

    // Hyprland.focusedMonitor reads null until something reads Hyprland.monitors
    // and never recovers on its own, so this binding is load-bearing: it is the
    // read that makes focusedMonitor answer at all. Verified against a shell
    // that omitted it and got null every time.
    readonly property var hyprlandMonitors: Hyprland.monitors

    function focusedScreen() {
        const focused = Hyprland.focusedMonitor
        return OverlayScreen.focusedScreen(Quickshell.screens, focused ? focused.name : "")
    }
}
