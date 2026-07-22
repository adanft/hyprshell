const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (relativePath) =>
	fs.readFileSync(path.join(root, relativePath), "utf8");

const shell = read("shell.qml");
const barWindow = read("statusbar/BarWindow.qml");
const tray = read("statusbar/modules/Tray.qml");
const networkMenu = read("statusbar/components/NetworkMenu.qml");
const services = read("services/Services.qml");

for (const loaderId of [
	"appLauncherLoader",
	"powerMenuLoader",
	"wallpaperSelectorLoader",
	"themeSelectorLoader",
	"screenshotToolLoader",
	"notificationCenterLoader",
	"notificationPopupLoader",
]) {
	assert.match(
		shell,
		new RegExp(`id: ${loaderId}`),
		`${loaderId} must remain lazy`,
	);
}

for (const loaderId of [
	"appLauncherLoader",
	"powerMenuLoader",
	"wallpaperSelectorLoader",
	"themeSelectorLoader",
	"screenshotToolLoader",
	"notificationCenterLoader",
]) {
	assert.match(
		shell,
		new RegExp(`id: ${loaderId}\\s+property bool requestedVisible: false`),
		`${loaderId} must track pending visibility intent`,
	);
}

for (const eagerWindow of [
	"Applauncher.AppLauncher {\n        id:",
	"Powermenu.PowerMenu {\n        id:",
	"Wallpaperselector.WallpaperSelector {\n        id:",
	"Themeselector.ThemeSelector {\n        id:",
	"Screenshot.ScreenshotTool {\n        id:",
]) {
	assert.equal(
		shell.includes(eagerWindow),
		false,
		`${eagerWindow} must not be eager`,
	);
}

assert.match(barWindow, /LazyLoader\s*{\s*id: networkMenuLoader/);
assert.match(
	barWindow,
	/if \(menu && !menu\.menuOpen\)\s*{\s*networkMenuLoader\.requestedOpen = false;\s*networkMenuLoader\.active = false/,
);
assert.match(tray, /LazyLoader\s*{\s*id: trayMenuLoader/);
assert.match(
	tray,
	/if \(menu && !menu\.menuOpen\)\s*trayMenuLoader\.active = false/,
);

assert.match(
	services,
	/running: service\.networkDetailsEnabled && service\.lanDevice !== null/,
);
assert.match(
	services,
	/running: service\.networkDetailsEnabled && service\.wifiDevice !== null/,
);
assert.match(networkMenu, /services\.enableNetworkDetails\(\)/);
assert.match(networkMenu, /services\.disableNetworkDetails\(\)/);
assert.match(
	networkMenu,
	/Component\.onDestruction:\s*{\s*if \(root\.menuOpen\)\s*root\.services\.disableNetworkDetails\(\)/,
);
assert.match(
	services,
	/networkDetailsSubscriberCount = Math\.max\(0, networkDetailsSubscriberCount - 1\)/,
);

console.log(
	"IdleResourceLifecycle: floating windows are lazy and network polling is menu-gated",
);
