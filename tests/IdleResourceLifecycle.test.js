const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (relativePath) =>
	fs.readFileSync(path.join(root, relativePath), "utf8");

const shell = read("shell.qml");
const overlayLifecycleLoader = read("OverlayLifecycleLoader.qml");
const barWindow = read("features/statusbar/BarWindow.qml");
const tray = read("features/tray/Tray.qml");
const controlCenter = read("features/controlcenter/ControlCenter.qml");
const controlCenterController = read(
	"features/controlcenter/ControlCenterController.qml",
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
	// toggle() owns the decision and close() owns the teardown, so that opening
	// one overlay can dismiss another without going through a toggle.
	/function toggle\(\)[\s\S]*if \(!requestedVisible\)[\s\S]*open\(\);?[\s\S]*const loadedItem = item;?[\s\S]*!_openingPending && \(!loadedItem \|\| !loadedItem\.visible\)[\s\S]*open\(\);?[\s\S]*close\(\);?\s*\}/,
	/function close\(\)\s*{\s*if \(!requestedVisible\)\s*return;?[\s\S]*requestedVisible = false;?[\s\S]*_openingPending = false;?[\s\S]*_lifecycleGeneration\+\+;?[\s\S]*directVisibility[\s\S]*loadedItem\.visible = false;?[\s\S]*loadedItem\.close\(\);?/,
	/function _scheduleOpen\(generation, loadedItem\)[\s\S]*if \(!loadedItem\)[\s\S]*_scheduledItem\s*===\s*loadedItem[\s\S]*_dispatchedItem\s*===\s*loadedItem[\s\S]*Qt\.callLater/,
	/root\._scheduledGeneration !== generation \|\| root\._scheduledItem !== loadedItem[\s\S]*return;?/,
	/generation !== root\._lifecycleGeneration[\s\S]*!root\.requestedVisible[\s\S]*root\.item !== loadedItem[\s\S]*return;?/,
	/root\._openingPending = false;?[\s\S]*root\.directVisibility[\s\S]*loadedItem\.visible = true;?[\s\S]*loadedItem\.open\(\);?/,
	/function _handleItemChanged\(loadedItem\)[\s\S]*const previousItem = _observedItem;?[\s\S]*_observeItem\(loadedItem\);?[\s\S]*_itemPresented = loadedItem !== null && loadedItem\.visible;?[\s\S]*loadedItem !== previousItem[\s\S]*_scheduledGeneration = -1;?[\s\S]*_dispatchedGeneration = -1;?[\s\S]*loadedItem && requestedVisible[\s\S]*_scheduleOpen\(_lifecycleGeneration, loadedItem\);?/,
	/function _handleItemVisibleChanged\(loadedItem\)[\s\S]*loadedItem !== _observedItem[\s\S]*loadedItem\.visible[\s\S]*_itemPresented = true;?[\s\S]*_openingPending = false;?[\s\S]*if \(!_itemPresented\)[\s\S]*return;?[\s\S]*requestedVisible = false;?[\s\S]*active = false;?/,
	/onItemChanged: _handleItemChanged\(item\)/,
	// The item is observed by hand. This used to assert a Connections block
	// instead, which is how the bug survived: the block was in the source, so
	// the regex passed, but LazyLoader's default property is its component and
	// every use site declared its overlay into the same property, so the block
	// never instantiated. Nothing observed the item, active was never cleared,
	// and closed overlays stayed alive. overlay-lifecycle-harness.qml is the
	// real guard now, because it runs the loader instead of reading it.
	/function _observeItem\(loadedItem\)[\s\S]*_observedItem\.visibleChanged\.disconnect\(_visibleConnection\);?[\s\S]*loadedItem\.visibleChanged\.connect\(_visibleConnection\);?/,
]) {
	assert.match(overlayLifecycleLoader, contract);
}

// A Connections block here is silently swallowed by the component default
// property, so it must never come back — it would look correct and do nothing.
assert.doesNotMatch(
	overlayLifecycleLoader,
	/\bConnections\s*{/,
	"a Connections block inside LazyLoader lands in its default property and never runs",
);

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

// Two full-screen overlays up at once is the case the layer-shell protocol
// leaves undefined, so every one of them has to be registered with the arbiter
// and no IPC target may reach its loader behind the arbiter's back.
const exclusiveOverlayLoaders = [
	"appLauncherLoader",
	"powerMenuLoader",
	"wallpaperSelectorLoader",
	"themeSelectorLoader",
	"screenshotToolLoader",
];
const arbiterDeclaration = /OverlayArbiter\s*{\s*id: overlayArbiter\s*loaders: \[([^\]]*)\]/.exec(
	shell,
);
assert.ok(arbiterDeclaration, "shell must declare the OverlayArbiter");
const registeredLoaders = arbiterDeclaration[1]
	.split(",")
	.map((entry) => entry.trim());
assert.deepEqual(
	registeredLoaders,
	exclusiveOverlayLoaders,
	"every exclusive overlay must be registered with the arbiter",
);

// IpcHandler publishes every property it carries, so the handlers cannot take a
// loader property and stay plain declarations instead.
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
				`function ${method}\\(\\): void \\{\\s*overlayArbiter\\.${method}\\(${loaderId}\\);?\\s*\\}`,
			),
			`${target}.${method}() must go through overlayArbiter.${method}(${loaderId})`,
		);
	assert.doesNotMatch(
		handler[1],
		new RegExp(`${loaderId}\\.(open|toggle)\\(`),
		`${target} handler must not reach ${loaderId} behind the arbiter`,
	);
	assert.doesNotMatch(
		handler[1],
		/property /,
		`${target} handler must carry no property: IpcHandler publishes them`,
	);
}

// The arbiter coordinates; it must not reimplement the lifecycle it delegates
// to, which is the same rule the shell itself follows below.
const overlayArbiter = read("OverlayArbiter.qml");
assert.match(overlayArbiter, /function closeOthers\(keptLoader\)[\s\S]*loader !== keptLoader[\s\S]*loader\.close\(\);?/);
assert.match(overlayArbiter, /function open\(loader\)\s*{\s*arbiter\.closeOthers\(loader\);?\s*loader\.open\(\);?\s*}/);
assert.match(overlayArbiter, /function toggle\(loader\)\s*{\s*if \(!loader\.requestedVisible\)\s*arbiter\.closeOthers\(loader\);?\s*loader\.toggle\(\);?\s*}/);
assert.equal(overlayArbiter.includes("Qt.callLater"), false);
assert.equal(overlayArbiter.includes("_lifecycleGeneration"), false);

// Without a namespace an overlay reports the default 'quickshell' to the
// compositor, so no layer rule can target it and hyprctl cannot tell the five
// apart. They deliberately do NOT set screen: an unset output is what lets the
// compositor place the overlay on the monitor the user is on, and pinning it to
// a resolved screen took that away.
for (const [overlayPath, namespace] of [
	["features/applauncher/AppLauncher.qml", "qs-applauncher"],
	["features/powermenu/PowerMenu.qml", "qs-powermenu"],
	["features/wallpaperselector/WallpaperSelector.qml", "qs-wallpaperselector"],
	["features/themeselector/ThemeSelector.qml", "qs-themeselector"],
	["features/screenshot/ScreenshotTool.qml", "qs-screenshot"],
]) {
	const overlay = read(overlayPath);
	assert.match(
		overlay,
		new RegExp(`WlrLayershell\\.namespace: "${namespace}"`),
		`${overlayPath} must declare the ${namespace} namespace`,
	);
	assert.doesNotMatch(
		overlay,
		/^\s*screen:/m,
		`${overlayPath} must leave its output to the compositor`,
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
	/Notifications\.NotificationCenter\s*{\s*services: serviceState\s*barWindow: notificationCenterLoader\.ownerWindow/,
);

assert.match(
	shell,
	/function set\(name: string\): void\s*{\s*ThemeRuntime\.StockThemes\.setTheme\(name\);?\s*}/,
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
	/Notifications\.NotificationPopupManager\s*{\s*services: serviceState\s*barWindow: barWindow/,
	"notification popup manager must remain resident to preserve stack state",
);
assert.equal(shell.includes("id: notificationPopupLoader"), false);

assert.match(barWindow, /LazyLoader\s*{\s*id: controlCenterLoader/);
assert.match(
	barWindow,
	/if \(menu && !menu\.menuOpen\)\s*{\s*controlCenterLoader\.requestedOpen = false;?\s*controlCenterLoader\.active = false/,
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
	controlCenter,
	/pendingNetwork: controlCenterController\.pendingNetwork[\s\S]*ControlCenterController\s*{[\s\S]*handleWifiNetworkConnectionFailed/,
);
assert.equal(controlCenter.includes("wifiScannerStartTimer"), false);
assert.equal(controlCenter.includes("enableNetworkDetails()"), false);
assert.match(controlCenterController, /networkService\.enableNetworkDetails\(\)/);
assert.match(controlCenterController, /networkService\.disableNetworkDetails\(\)/);
assert.match(
	controlCenterController,
	/Component\.onDestruction: root\.dispatch\(\{\s*type: "destroy"\s*\}\)/,
);
assert.match(
	networkService,
	/networkDetailsSubscriberCount = Math\.max\(0, networkDetailsSubscriberCount - 1\)/,
);

console.log(
	"IdleResourceLifecycle: floating windows are lazy and network polling is menu-gated",
);
