const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const persistence = require("./NotificationImagePersistence.js");

const cacheDirectory = "/cache/qsrice/notification-images";
const generatedPath = `${cacheDirectory}/notif_1700000000000_42_1.png`;
const retryPath = `${cacheDirectory}/notif_1700000000000_42_2.png`;
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
	persistence.notificationImagePath(entry, cacheDirectory, 1),
	generatedPath,
);
assert.equal(
	persistence.notificationImagePath(
		{ timestamp: 1700000000001, notification: {} },
		cacheDirectory,
		3,
	),
	`${cacheDirectory}/notif_1700000000001_0_3.png`,
);
const unsafePath = persistence.notificationImagePath(
	{ timestamp: "../escape", notification: { id: "1/2" } },
	cacheDirectory,
	4,
);
assert.equal(unsafePath, `${cacheDirectory}/notif_0_0_4.png`);
assert.equal(persistence.isOwnedPath(unsafePath, cacheDirectory), true);

const state = persistence.createState();
assert.equal(persistence.canMaterialize(state, entry, false), false);
assert.equal(persistence.canMaterialize(state, entry, true), true);
persistence.begin(state, entry.id, 1, generatedPath, `${generatedPath}.part-1`);
assert.equal(
	persistence.canMaterialize(state, entry, true),
	false,
	"pending saves deduplicate",
);
assert.deepEqual(
	persistence.complete(state, entry.id, 1, true, true, true),
	{ persisted: true, retry: false },
);
assert.equal(
	persistence.canMaterialize(state, entry, true),
	false,
	"owned saves deduplicate",
);
assert.equal(persistence.removeEntry(state, entry.id), generatedPath);

const retryState = persistence.createState();
persistence.begin(retryState, entry.id, 1, generatedPath, `${generatedPath}.part-1`);
assert.deepEqual(
	persistence.complete(
		retryState,
		entry.id,
		1,
		false,
		true,
		true,
	),
	{ persisted: false, retry: true },
	"the first save failure receives one retry",
);
persistence.begin(retryState, entry.id, 2, retryPath, `${retryPath}.part-2`);
assert.deepEqual(
	persistence.complete(retryState, entry.id, 2, true, true, true),
	{ persisted: true, retry: false },
	"a retry can persist the live image",
);

const exhaustedRetryState = persistence.createState();
persistence.begin(exhaustedRetryState, entry.id, 1, generatedPath, `${generatedPath}.part-1`);
assert.equal(
	persistence.complete(
		exhaustedRetryState,
		entry.id,
		1,
		false,
		true,
		true,
	).retry,
	true,
);
persistence.begin(exhaustedRetryState, entry.id, 2, retryPath, `${retryPath}.part-2`);
assert.deepEqual(
	persistence.complete(
		exhaustedRetryState,
		entry.id,
		2,
		false,
		true,
		true,
	),
	{ persisted: false, retry: false },
	"the second failure falls back without an infinite retry loop",
);

const orphanState = persistence.createState();
persistence.begin(orphanState, entry.id, 1, generatedPath, `${generatedPath}.part-1`);
persistence.removeEntry(orphanState, entry.id);
assert.deepEqual(
	persistence.complete(orphanState, entry.id, 1, true, false, true),
	{ persisted: false, retry: false },
	"a removed entry cannot publish an in-flight file",
);
const destroyedState = persistence.createState();
persistence.begin(destroyedState, entry.id, 1, generatedPath, `${generatedPath}.part-1`);
assert.deepEqual(
	persistence.complete(
		destroyedState,
		entry.id,
		1,
		true,
		true,
		false,
	),
	{ persisted: false, retry: false },
	"destruction prevents stale publication and leaves a recoverable orphan",
);

const generationState = persistence.createState();
persistence.begin(generationState, entry.id, 1, generatedPath, `${generatedPath}.part-1`);
persistence.begin(generationState, entry.id, 2, retryPath, `${retryPath}.part-2`);
assert.deepEqual(
	persistence.complete(generationState, entry.id, 1, true, true, true),
	{ persisted: false, retry: false },
	"a stale generation cannot publish or consume the current reservation",
);
assert.equal(
	persistence.canDeleteOrphan(generationState, [], retryPath, cacheDirectory),
	false,
	"the sweep revalidation preserves pending final paths",
);
assert.equal(
	persistence.canDeleteOrphan(generationState, [], generatedPath, cacheDirectory),
	true,
	"an unreferenced stale generation remains sweepable",
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
	[retryPath],
	"the orphan sweep preserves referenced files and returns only owned unreferenced paths",
);

const serviceSource = fs.readFileSync(
	path.join(__dirname, "../../services/capabilities/NotificationService.qml"),
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
const shellSource = fs.readFileSync(path.join(__dirname, "../../shell.qml"), "utf8");
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
assert.match(serviceSource, /NotificationImagePersistence\.canDeleteOrphan/);
assert.match(serviceSource, /"find",[\s\S]*"notif_\*\.png"/);
assert.match(serviceSource, /notificationImageLifecycleActive = false/);
assert.match(serviceSource, /if \(outcome\.retry && allowRetry\)[\s\S]*Qt\.callLater/);
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
assert.match(serviceSource, /notificationImageHostReady\(captureParent\)/);
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
assert.match(serviceSource, /Component\.onDestruction:[\s\S]*notificationImageItemDestroyed/);
assert.match(
	serviceSource,
	/current\.image = imageSource[\s\S]*root\.scheduleNotificationHistorySave\(\)/,
	"successful completion publishes the owned path and forces a history write",
);
assert.doesNotMatch(cardSource, /materializeNotificationImage\(/,
 "cards never lend their scene-owned image to the capture service");
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
	/status === Image\.Error && failedSource\.length > 0/,
);
assert.match(popupSource, /allowLiveImage: true/);
assert.match(serviceSource, /saveToFile\(completedJob\.tempPath\)/);
assert.match(serviceSource, /\["test", "-s", job\.tempPath\]/);
assert.match(serviceSource, /\["mv", "-f", "--", currentJob\.tempPath, currentJob\.path\]/);
assert.match(serviceSource, /\["test", "-r", movedJob\.path\]/);
assert.match(serviceSource, /function invalidateOwnedNotificationImage/);
assert.match(serviceSource, /property var notificationImageCaptureJobs/);
assert.match(serviceSource, /property int notificationImageCaptureGeneration/);
assert.match(serviceSource, /activeNotificationImageJob\(entryId, generation\)/);
assert.match(serviceSource, /typeof imageItem\.grabToImage === "function"/);
assert.match(serviceSource, /cancelNotificationImageJob\(entryId, job\.generation, true\)/);

console.log(
	"Notification image persistence: recovery, retry, and deletion safety passed",
);
