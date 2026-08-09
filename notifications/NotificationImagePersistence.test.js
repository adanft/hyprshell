const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const persistence = require("./NotificationImagePersistence.js");

const cacheDirectory = "/cache/qsrice/notification-images";
const generatedPath = `${cacheDirectory}/notif_1700000000000_42.png`;
const retryPath = generatedPath;
const liveImage = "image://qsimage/live-1";

const entry = {
	id: "history-1",
	image: liveImage,
	timestamp: 1700000000000,
	createdAt: 1699999999999,
	notification: { id: 42 },
};
const popup = { id: 7, historyEntryId: entry.id, image: liveImage };
assert.notEqual(popup.id, popup.historyEntryId);
assert.equal(persistence.historyImageSource(liveImage), "");
assert.equal(
	persistence.historyImageSource("file:///tmp/external.png"),
	"file:///tmp/external.png",
);
assert.equal(persistence.isLiveImage(liveImage), true);
assert.equal(
	persistence.notificationImagePath(entry, cacheDirectory),
	generatedPath,
);
assert.equal(
	persistence.notificationImagePath(
		{ timestamp: 1700000000001, notification: {} },
		cacheDirectory,
	),
	`${cacheDirectory}/notif_1700000000001_0.png`,
);
const unsafePath = persistence.notificationImagePath(
	{ timestamp: "../escape", notification: { id: "1/2" } },
	cacheDirectory,
);
assert.equal(unsafePath, `${cacheDirectory}/notif_0_0.png`);
assert.equal(persistence.isOwnedPath(unsafePath, cacheDirectory), true);

const state = persistence.createState();
assert.equal(persistence.canMaterialize(state, entry, false), false);
assert.equal(persistence.canMaterialize(state, entry, true), true);
persistence.begin(state, entry.id, generatedPath);
assert.equal(
	persistence.canMaterialize(state, entry, true),
	false,
	"pending saves deduplicate",
);
assert.deepEqual(
	persistence.complete(state, entry.id, generatedPath, true, true, true),
	{ persisted: true, orphan: "", retry: false },
);
assert.equal(
	persistence.canMaterialize(state, entry, true),
	false,
	"owned saves deduplicate",
);
assert.equal(persistence.removeEntry(state, entry.id), generatedPath);

const retryState = persistence.createState();
persistence.begin(retryState, entry.id, generatedPath);
assert.deepEqual(
	persistence.complete(
		retryState,
		entry.id,
		generatedPath,
		false,
		true,
		true,
	),
	{ persisted: false, orphan: "", retry: true },
	"the first save failure receives one retry",
);
persistence.begin(retryState, entry.id, retryPath);
assert.deepEqual(
	persistence.complete(retryState, entry.id, retryPath, true, true, true),
	{ persisted: true, orphan: "", retry: false },
	"a retry can persist the live image",
);

const exhaustedRetryState = persistence.createState();
persistence.begin(exhaustedRetryState, entry.id, generatedPath);
assert.equal(
	persistence.complete(
		exhaustedRetryState,
		entry.id,
		generatedPath,
		false,
		true,
		true,
	).retry,
	true,
);
persistence.begin(exhaustedRetryState, entry.id, retryPath);
assert.deepEqual(
	persistence.complete(
		exhaustedRetryState,
		entry.id,
		retryPath,
		false,
		true,
		true,
	),
	{ persisted: false, orphan: "", retry: false },
	"the second failure falls back without an infinite retry loop",
);

const orphanState = persistence.createState();
persistence.begin(orphanState, entry.id, generatedPath);
persistence.removeEntry(orphanState, entry.id);
assert.deepEqual(
	persistence.complete(
		orphanState,
		entry.id,
		generatedPath,
		true,
		false,
		true,
	),
	{ persisted: false, orphan: generatedPath, retry: false },
	"a removed entry cleans up an in-flight owned file",
);
const destroyedState = persistence.createState();
persistence.begin(destroyedState, entry.id, generatedPath);
assert.deepEqual(
	persistence.complete(
		destroyedState,
		entry.id,
		generatedPath,
		true,
		true,
		false,
	),
	{ persisted: false, orphan: generatedPath, retry: false },
	"destruction prevents stale publication and leaves a recoverable orphan",
);

assert.equal(persistence.isOwnedPath(generatedPath, cacheDirectory), true);
assert.equal(
	persistence.isOwnedPath(
		`${cacheDirectory}/notif_../escape.png`,
		cacheDirectory,
	),
	false,
);
assert.equal(
	persistence.isOwnedPath(`${cacheDirectory}/other.png`, cacheDirectory),
	false,
);
assert.equal(
	persistence.isOwnedPath("/tmp/notif_1_2.png", cacheDirectory),
	false,
);
assert.deepEqual(
	persistence.orphanPaths(
		[
			generatedPath,
			retryPath,
			"/tmp/notif_1_2.png",
			`${cacheDirectory}/not-owned.png`,
		],
		[{ ownedImage: true, persistedImagePath: generatedPath }],
		cacheDirectory,
	),
	[],
	"the orphan sweep preserves referenced files and excludes external paths",
);

const serviceSource = fs.readFileSync(
	path.join(__dirname, "../services/capabilities/NotificationService.qml"),
	"utf8",
);
const cardSource = fs.readFileSync(
	path.join(__dirname, "NotificationCard.qml"),
	"utf8",
);
const popupSource = fs.readFileSync(
	path.join(__dirname, "NotificationPopup.qml"),
	"utf8",
);
const barWindowSource = fs.readFileSync(
	path.join(__dirname, "../statusbar/BarWindow.qml"),
	"utf8",
);
const shellSource = fs.readFileSync(path.join(__dirname, "../shell.qml"), "utf8");
assert.match(
	serviceSource,
	/onLoadFailed: error => \{\s*if \(error === 2\) \{\s*historyFileView\.writeAdapter\(\)\s*root\.sweepNotificationImageCache\(\)\s*\}\s*\}/,
	"orphan sweep is guarded by missing-history recovery",
);
assert.doesNotMatch(
	serviceSource,
	/onLoadFailed: error => \{[\s\S]*?\}\s*root\.sweepNotificationImageCache\(\)/,
	"history parse/read failures preserve cache files",
);
assert.match(serviceSource, /NotificationImagePersistence\.orphanPaths/);
assert.match(serviceSource, /"find",[\s\S]*"notif_\*\.png"/);
assert.match(serviceSource, /notificationImageLifecycleActive = false/);
assert.match(serviceSource, /if \(outcome\.retry\)[\s\S]*Qt\.callLater/);
assert.match(
	serviceSource,
	/root\.scheduleNotificationHistorySave\(\)\s*root\.materializeNotificationImage\(entry\.id\)/,
	"history reception starts image persistence without a rendered toast",
);
assert.match(serviceSource, /id: notificationImageCaptureComponent/);
assert.match(serviceSource, /required property string entryId/);
assert.match(serviceSource, /notificationImageCaptureComponent\.createObject\(captureParent/);
assert.doesNotMatch(
	serviceSource,
	/notificationImageCaptureComponent\.createObject\(root/,
	"capture images must never be created under the non-visual service Scope",
);
assert.match(serviceSource, /captureParent\.Window\.window/);
assert.match(barWindowSource, /PanelWindow \{/);
assert.match(barWindowSource, /id: notificationImageCaptureHost/);
assert.match(barWindowSource, /readonly property var captureWindow: window/);
assert.match(barWindowSource, /x: -width - 1/);
assert.match(barWindowSource, /registerNotificationImageCaptureHost\(notificationImageCaptureHost\)/);
assert.match(barWindowSource, /unregisterNotificationImageCaptureHost\(notificationImageCaptureHost\)/);
assert.doesNotMatch(shellSource, /NotificationImageCaptureWindow/);
assert.doesNotMatch(
	serviceSource,
	/(?:Window|PanelWindow|PopupWindow)\s*\{/,
	"the notification service must not create a top-level capture surface",
);
assert.match(serviceSource, /hosts\.sort\([\s\S]*captureHostKey/);
assert.match(serviceSource, /Component\.onDestruction:[\s\S]*handleNotificationImageSaveResult/);
assert.match(
	serviceSource,
	/current\.image = `file:\/\/\$\{path\}`[\s\S]*root\.scheduleNotificationHistorySave\(\)/,
	"successful completion publishes the owned path and forces a history write",
);
assert.match(
	cardSource,
	/materializeNotificationImage\([\s\S]*notificationImage/,
	"a scene-attached card remains a fallback when the persistent host is unavailable",
);
assert.match(
	serviceSource,
	/notification\.tracked = !notification\.transient && !policy\.hideFromCenter/,
	"toast-only transient notifications remain outside history",
);
assert.match(
	serviceSource,
	/historyEntry = notification\.tracked \? root\.addNotificationToHistory[\s\S]*root\.enqueueNotificationPopup/,
	"an untracked transient may still be enqueued as a toast",
);
assert.match(
	serviceSource,
	/owned !== true \|\| !NotificationImagePersistence\.isOwnedPath/,
);
assert.match(serviceSource, /cleanup\.exec\(\["rm", "-f", "--", path\]\)/);
assert.match(
	serviceSource,
	/mkdir\.exec\(\["mkdir", "-p", "--", root\.notificationImageCacheDirectory\]\)/,
);
assert.match(
	serviceSource,
	/image: NotificationImagePersistence\.historyImageSource\(item\.image\)/,
);
assert.match(cardSource, /property bool allowLiveImage: false/);
assert.match(
	cardSource,
	/status === Image\.Error && card\.allowLiveImage && failedSource\.startsWith/,
);
assert.match(popupSource, /allowLiveImage: true/);

console.log(
	"Notification image persistence: recovery, retry, and deletion safety passed",
);
