const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (relativePath) =>
	fs.readFileSync(path.join(root, relativePath), "utf8");

const shell = read("shell.qml");
const overlayLifecycleLoader = read("OverlayLifecycleLoader.qml");
const barWindow = read("statusbar/BarWindow.qml");
const tray = read("statusbar/modules/Tray.qml");
const networkMenu = read("statusbar/components/NetworkMenu.qml");
const networkController = read(
	"statusbar/components/NetworkMenuController.qml",
);
const networkService = read("services/capabilities/NetworkService.qml");

for (const contract of [
	/LazyLoader\s*{/,
	/property bool requestedVisible: false/,
	/property bool directVisibility: false/,
	/property int _lifecycleGeneration: 0/,
	/property var _observedItem: null/,
	/property bool _itemPresented: false/,
	/property int _scheduledGeneration: -1/,
	/property var _scheduledItem: null/,
	/property int _dispatchedGeneration: -1/,
	/property var _dispatchedItem: null/,
	/property bool _openingPending: false/,
	/active: false/,
	/function open\(\)[\s\S]*requestedVisible = true;?[\s\S]*_openingPending = true;?[\s\S]*active = true;?[\s\S]*const generation = \+\+_lifecycleGeneration;?[\s\S]*_scheduleOpen\(generation, item\);?/,
	/function toggle\(\)[\s\S]*if \(!requestedVisible\)[\s\S]*open\(\);?[\s\S]*const loadedItem = item;?[\s\S]*!_openingPending && \(!loadedItem \|\| !loadedItem\.visible\)[\s\S]*open\(\);?[\s\S]*requestedVisible = false;?[\s\S]*_openingPending = false;?[\s\S]*_lifecycleGeneration\+\+;?/,
	/function _scheduleOpen\(generation, loadedItem\)[\s\S]*if \(!loadedItem\)[\s\S]*_scheduledItem\s*===\s*loadedItem[\s\S]*_dispatchedItem\s*===\s*loadedItem[\s\S]*Qt\.callLater/,
	/root\._scheduledGeneration !== generation \|\| root\._scheduledItem !== loadedItem[\s\S]*return;?/,
	/generation !== root\._lifecycleGeneration[\s\S]*!root\.requestedVisible[\s\S]*root\.item !== loadedItem[\s\S]*return;?/,
	/root\._openingPending = false;?[\s\S]*root\.directVisibility[\s\S]*loadedItem\.visible = true;?[\s\S]*loadedItem\.open\(\);?/,
	/function _handleItemChanged\(loadedItem\)[\s\S]*const previousItem = _observedItem;?[\s\S]*_observedItem = loadedItem;?[\s\S]*_itemPresented = loadedItem !== null && loadedItem\.visible;?[\s\S]*loadedItem !== previousItem[\s\S]*_scheduledGeneration = -1;?[\s\S]*_dispatchedGeneration = -1;?[\s\S]*loadedItem && requestedVisible[\s\S]*_scheduleOpen\(_lifecycleGeneration, loadedItem\);?/,
	/function _handleItemVisibleChanged\(loadedItem\)[\s\S]*loadedItem !== _observedItem[\s\S]*loadedItem\.visible[\s\S]*_itemPresented = true;?[\s\S]*_openingPending = false;?[\s\S]*if \(!_itemPresented\)[\s\S]*return;?[\s\S]*requestedVisible = false;?[\s\S]*active = false;?/,
	/onItemChanged: _handleItemChanged\(item\)/,
	/Connections\s*{[\s\S]*target: root\._observedItem[\s\S]*root\._handleItemVisibleChanged\(target\);?/,
]) {
	assert.match(overlayLifecycleLoader, contract);
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
		new RegExp(`OverlayLifecycleLoader\\s*\\{\\s*id: ${loaderId}`),
		`${loaderId} must use the shared lazy lifecycle`,
	);
}

// Each IPC target must call its own overlay directly. IpcHandler publishes
// every property it carries, so the handlers cannot take a loader property and
// stay plain declarations instead.
for (const [target, loaderId] of [
	["applauncher", "appLauncherLoader"],
	["powermenu", "powerMenuLoader"],
	["wallpaperselector", "wallpaperSelectorLoader"],
	["screenshot", "screenshotToolLoader"],
	["themeselector", "themeSelectorLoader"],
]) {
	const handler = new RegExp(
		`IpcHandler\\s*\\{\\s*target: "${target}"([\\s\\S]*?)\\n    \\}`,
	).exec(shell);
	assert.ok(handler, `IpcHandler missing for target ${target}`);
	for (const method of ["open", "toggle"])
		assert.match(
			handler[1],
			new RegExp(
				`function ${method}\\(\\): void \\{\\s*${loaderId}\\.${method}\\(\\);?\\s*\\}`,
			),
			`${target}.${method}() must delegate to ${loaderId}.${method}()`,
		);
	assert.doesNotMatch(
		handler[1],
		/property /,
		`${target} handler must carry no property: IpcHandler publishes them`,
	);
}

// Lifecycle behaviour stays inside OverlayLifecycleLoader; the shell must not
// reimplement it, whether as named helpers or inline in a handler.
assert.equal(shell.includes("function openLoader(loader)"), false);
assert.equal(shell.includes("function toggleLoader(loader)"), false);
assert.equal(shell.includes("requestedVisible"), false);
assert.equal(shell.includes("Qt.callLater"), false);
assert.match(
	shell,
	/function toggleNotificationCenter\(\)\s*{\s*notificationCenterLoader\.toggle\(\);?\s*}/,
);
assert.match(
	shell,
	/OverlayLifecycleLoader\s*{\s*id: notificationCenterLoader\s*directVisibility: true\s*property var ownerWindow: barWindow/s,
);
assert.match(
	shell,
	/Notifications\.NotificationCenter\s*{\s*colors: Theme\.Colors\s*services: serviceState\s*barWindow: notificationCenterLoader\.ownerWindow/,
);

assert.match(
	shell,
	/function set\(name: string\): void\s*{\s*Theme\.Colors\.setTheme\(name\);?\s*}/,
);

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
	/Notifications\.NotificationPopupManager\s*{\s*colors: Theme\.Colors\s*services: serviceState\s*barWindow: barWindow/,
	"notification popup manager must remain resident to preserve stack state",
);
assert.equal(shell.includes("id: notificationPopupLoader"), false);

assert.match(barWindow, /LazyLoader\s*{\s*id: networkMenuLoader/);
assert.match(
	barWindow,
	/if \(menu && !menu\.menuOpen\)\s*{\s*networkMenuLoader\.requestedOpen = false;?\s*networkMenuLoader\.active = false/,
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
	/Component\.onDestruction: root\.dispatch\(\{\s*type: "destroy"\s*\}\)/,
);
assert.match(
	networkService,
	/networkDetailsSubscriberCount = Math\.max\(0, networkDetailsSubscriberCount - 1\)/,
);

console.log(
	"IdleResourceLifecycle: floating windows are lazy and network polling is menu-gated",
);
