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

console.log("OverlayScreen: overlays open on the focused monitor");
