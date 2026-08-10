const assert = require("node:assert/strict");
const overlayScreen = require("./OverlayScreen.js");

const hdmi = { name: "HDMI-A-1" };
const dp3 = { name: "DP-3" };
const dp1 = { name: "DP-1" };
const screens = [hdmi, dp3, dp1];

// The focused monitor wins even when it is not the first screen, which is the
// whole point: overlays used to always land on screens[0].
assert.equal(overlayScreen.focusedScreen(screens, "DP-1"), dp1);
assert.equal(overlayScreen.focusedScreen(screens, "DP-3"), dp3);
assert.equal(overlayScreen.focusedScreen(screens, "HDMI-A-1"), hdmi);

// Hyprland.focusedMonitor reads null until something touches Hyprland.monitors,
// and a monitor can be unplugged between the read and the open. Neither may
// leave the overlay unable to map.
assert.equal(overlayScreen.focusedScreen(screens, ""), hdmi);
assert.equal(overlayScreen.focusedScreen(screens, null), hdmi);
assert.equal(overlayScreen.focusedScreen(screens, undefined), hdmi);
assert.equal(overlayScreen.focusedScreen(screens, "DP-9"), hdmi);

// A single screen is the common case and must not be treated as a mismatch.
assert.equal(overlayScreen.focusedScreen([hdmi], "HDMI-A-1"), hdmi);
assert.equal(overlayScreen.focusedScreen([hdmi], "DP-1"), hdmi);

// No screens at all: there is nothing to return, and null must not become
// screens[0] of an empty list.
assert.equal(overlayScreen.focusedScreen([], "DP-1"), null);
assert.equal(overlayScreen.focusedScreen(null, "DP-1"), null);
assert.equal(overlayScreen.focusedScreen(undefined, "DP-1"), null);

// A hole in the screen list must not throw on the way to the match.
assert.equal(overlayScreen.focusedScreen([null, dp1], "DP-1"), dp1);
assert.equal(overlayScreen.focusedScreen([null, dp1], "DP-9"), null);

// focusedmon payloads, captured from the event socket rather than assumed:
// name and data only, data being the raw comma-joined arguments.
assert.equal(overlayScreen.monitorNameFromFocusedMon("DP-1,6"), "DP-1");
assert.equal(overlayScreen.monitorNameFromFocusedMon("HDMI-A-1,2"), "HDMI-A-1");

// A workspace name may itself contain a comma; only the first one ends the
// monitor, so the rest cannot bleed into it.
assert.equal(overlayScreen.monitorNameFromFocusedMon("DP-3,my,ws"), "DP-3");

// A payload with no workspace at all is still a monitor name.
assert.equal(overlayScreen.monitorNameFromFocusedMon("DP-3"), "DP-3");
assert.equal(overlayScreen.monitorNameFromFocusedMon(" DP-3 ,6"), "DP-3");

// Junk must resolve to no name rather than to a bogus one, so that
// focusedScreen falls back instead of matching nothing.
for (const junk of ["", ",6", null, undefined, 42, {}])
	assert.equal(overlayScreen.monitorNameFromFocusedMon(junk), "");

// The two halves compose: an event payload has to land on its screen.
assert.equal(
	overlayScreen.focusedScreen(
		screens,
		overlayScreen.monitorNameFromFocusedMon("DP-1,6"),
	),
	dp1,
);

console.log("OverlayScreen: overlays open on the focused monitor");
