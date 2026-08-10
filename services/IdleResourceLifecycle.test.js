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
	// toggle() owns the decision and close() owns the teardown, so that opening
	// one overlay can dismiss another without going through a toggle.
	/function toggle\(\)[\s\S]*if \(!requestedVisible\)[\s\S]*open\(\);?[\s\S]*const loadedItem = item;?[\s\S]*!_openingPending && \(!loadedItem \|\| !loadedItem\.visible\)[\s\S]*open\(\);?[\s\S]*close\(\);?\s*\}/,
	/function close\(\)\s*{\s*if \(!requestedVisible\)\s*return;?[\s\S]*requestedVisible = false;?[\s\S]*_openingPending = false;?[\s\S]*_lifecycleGeneration\+\+;?[\s\S]*directVisibility[\s\S]*loadedItem\.visible = false;?[\s\S]*loadedItem\.close\(\);?/,
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
assert.match(overlayArbiter, /function open\(loader\)\s*{\s*arbiter\.closeOthers\(loader\);?\s*arbiter\.aimAtFocusedScreen\(loader\);?\s*loader\.open\(\);?\s*}/);
assert.match(overlayArbiter, /function toggle\(loader\)\s*{\s*if \(!loader\.requestedVisible\)\s*{\s*arbiter\.closeOthers\(loader\);?\s*arbiter\.aimAtFocusedScreen\(loader\);?\s*}\s*loader\.toggle\(\);?\s*}/);
assert.equal(overlayArbiter.includes("Qt.callLater"), false);
assert.equal(overlayArbiter.includes("_lifecycleGeneration"), false);

// Keeping the compositor out of the arbiter is what lets it be exercised on its
// own: qmltestrunner cannot resolve the Quickshell imports. Matched against the
// import lines, since the prose above them names Hyprland on purpose.
const arbiterImports = overlayArbiter
	.split("\n")
	.filter((line) => line.startsWith("import "));
assert.deepEqual(
	arbiterImports,
	["import QtQuick"],
	"OverlayArbiter must import nothing but QtQuick to remain testable",
);

// Hyprland.focusedMonitor is a cached view that goes stale, so the focused
// monitor has to come from the focusedmon event. Reading the cache alone is the
// bug that made overlays open on the previous monitor, and it must not come
// back: the event-sourced name has to win whenever there is one.
const overlayScreenResolver = read("OverlayScreenResolver.qml");
assert.match(
	overlayScreenResolver,
	/function onRawEvent\(event\)\s*{\s*if \(event\.name !== "focusedmon"\)\s*return;?\s*const name = OverlayScreen\.monitorNameFromFocusedMon\(event\.data\);?\s*if \(name\.length > 0\)\s*resolver\.focusedMonitorName = name;?/,
	"the resolver must track the focusedmon event",
);
assert.match(
	overlayScreenResolver,
	/const name = resolver\.focusedMonitorName \|\| \(cached \? cached\.name : ""\)/,
	"the event-sourced name must take precedence over the cached monitor",
);
// The startup read is what makes focusedMonitor answer at all, and the refresh
// gives the seed a current value; both are load-bearing, not decorative.
assert.match(overlayScreenResolver, /Hyprland\.monitors/);
assert.match(overlayScreenResolver, /Hyprland\.refreshMonitors\(\)/);
assert.match(shell, /OverlayScreenResolver\s*{\s*id: overlayScreenResolver\s*}/);
assert.match(shell, /screenResolver: overlayScreenResolver/);

// Each overlay must be aimable and identifiable: without targetScreen it always
// maps on screens[0], and without a namespace the compositor cannot target it
// with a layer rule.
for (const [overlayPath, rootId, namespace] of [
	["applauncher/AppLauncher.qml", "launcher", "qs-applauncher"],
	["powermenu/PowerMenu.qml", "powerMenu", "qs-powermenu"],
	["wallpaperselector/WallpaperSelector.qml", "selector", "qs-wallpaperselector"],
	["themeselector/ThemeSelector.qml", "selector", "qs-themeselector"],
	["screenshot/ScreenshotTool.qml", "tool", "qs-screenshot"],
]) {
	const overlay = read(overlayPath);
	assert.match(
		overlay,
		/property var targetScreen: null/,
		`${overlayPath} must declare targetScreen`,
	);
	assert.match(
		overlay,
		new RegExp(`screen: ${rootId}\\.targetScreen`),
		`${overlayPath} must bind its PanelWindow to targetScreen`,
	);
	assert.match(
		overlay,
		new RegExp(`WlrLayershell\\.namespace: "${namespace}"`),
		`${overlayPath} must declare the ${namespace} namespace`,
	);
}

// The loader hands the screen over before the item is shown, because a
// PanelWindow picks its output when it maps.
assert.match(
	overlayLifecycleLoader,
	/property var targetScreen: null/,
);
assert.match(
	overlayLifecycleLoader,
	/root\.targetScreen && loadedItem\.targetScreen !== undefined[\s\S]*loadedItem\.targetScreen = root\.targetScreen;?[\s\S]*root\._openingPending = false;?/,
);

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
