// Picks the screen a full-screen overlay should open on.
//
// The overlays are single instances rather than one per monitor, so unlike the
// bar-anchored menus they have no barWindow.screen to inherit. The focused
// monitor has to be resolved when the user asks for the overlay.
//
// HyprlandMonitor.screen reads null, so the monitor is matched to a ShellScreen
// by name rather than followed through a reference. An unknown or missing name
// falls back to the first screen, which is what a PanelWindow with no screen
// set picks anyway — the overlay stays reachable instead of failing to map.
function focusedScreen(screens, focusedMonitorName) {
	if (!screens || screens.length === 0) return null;

	if (focusedMonitorName) {
		for (const screen of screens) {
			if (screen && screen.name === focusedMonitorName) return screen;
		}
	}

	return screens[0];
}

if (typeof module !== "undefined") module.exports = { focusedScreen };
