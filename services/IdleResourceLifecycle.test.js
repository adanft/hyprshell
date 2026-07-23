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
const networkController = read(
	"statusbar/components/NetworkMenuController.qml",
);
const networkService = read("services/capabilities/NetworkService.qml");

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

assert.match(
	shell,
	/Notifications\.NotificationPopupManager\s*{\s*colors: themeColors\s*services: serviceState\s*barWindow: barWindow/,
	"notification popup manager must remain resident to preserve stack state",
);
assert.equal(shell.includes("id: notificationPopupLoader"), false);

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
	networkService,
	/running: root\.networkDetailsEnabled && root\.lanDevice !== null/,
);
assert.match(
	networkService,
	/running: root\.networkDetailsEnabled && root\.wifiDevice !== null/,
);
assert.match(
	networkMenu,
	/pendingNetwork: networkController\.pendingNetwork[\s\S]*NetworkMenuController\s*{[\s\S]*handleWifiNetworkConnectionFailed/,
);
assert.equal(networkMenu.includes("wifiScannerStartTimer"), false);
assert.equal(networkMenu.includes("enableNetworkDetails()"), false);
assert.match(networkController, /networkService\.enableNetworkDetails\(\)/);
assert.match(networkController, /networkService\.disableNetworkDetails\(\)/);
assert.match(
	networkController,
	/Component\.onDestruction: root\.dispatch\({ type: "destroy" }\)/,
);
assert.match(
	networkService,
	/networkDetailsSubscriberCount = Math\.max\(0, networkDetailsSubscriberCount - 1\)/,
);

console.log(
	"IdleResourceLifecycle: floating windows are lazy and network polling is menu-gated",
);
