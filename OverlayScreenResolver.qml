import QtQuick
import Quickshell
import Quickshell.Hyprland
import "OverlayScreen.js" as OverlayScreen

// The compositor half of picking an overlay's monitor. Kept apart from
// OverlayArbiter so the arbiter carries no Quickshell or Hyprland import and
// can be exercised on its own.
//
// Hyprland.focusedMonitor cannot be read at the instant an overlay opens. It is
// a cached view, and the Quickshell docs are explicit that "many actions that
// will invalidate monitor state don't send events" and that monitor properties
// "are not updated unless the monitor object is fetched again"; refreshMonitors()
// only repairs that asynchronously, which is too late for a synchronous open.
// Reading it directly is what made an overlay keep opening on the monitor the
// previous one had used, until some unrelated event happened to refresh it.
//
// The focusedmon event carries the new monitor name in its own payload, so it
// arrives pushed and stays current. That is what is tracked here.
Scope {
    id: resolver

    property string focusedMonitorName: ""

    function focusedScreen() {
        const cached = Hyprland.focusedMonitor
        // The event wins as soon as one has arrived. The cached view only seeds
        // the very first open of a session, before any focus has moved.
        const name = resolver.focusedMonitorName || (cached ? cached.name : "")
        return OverlayScreen.focusedScreen(Quickshell.screens, name)
    }

    // Reading monitors is what makes focusedMonitor answer at all — without it
    // the seed above is null — and the refresh gives it a current value to seed
    // from. Both are startup-only; steady state runs on the event below.
    Component.onCompleted: {
        const monitorCount = (Hyprland.monitors?.values ?? []).length
        if (monitorCount >= 0)
            Hyprland.refreshMonitors()
    }

    Connections {
        target: Hyprland

        // HyprlandIpcEvent carries name and data only, with no parseArgs, so the
        // payload is split by OverlayScreen where it can be tested.
        function onRawEvent(event) {
            if (event.name !== "focusedmon")
                return

            const name = OverlayScreen.monitorNameFromFocusedMon(event.data)
            if (name.length > 0)
                resolver.focusedMonitorName = name
        }
    }
}
