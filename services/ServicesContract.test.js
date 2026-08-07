const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = __dirname;
const facade = fs.readFileSync(path.join(root, "Services.qml"), "utf8");
const capabilityNames = [
	"AudioService",
	"BrightnessService",
	"NetworkService",
	"NotificationService",
	"BatteryPowerService",
	"BluetoothService",
	"SystemStatsService",
	"WorkspaceService",
];
const capabilityAliases = [
	"audio",
	"brightness",
	"network",
	"notification",
	"batteryPower",
	"bluetooth",
	"systemStats",
	"workspace",
];

for (const name of capabilityNames)
	assert.match(
		facade,
		new RegExp(`Capabilities\\.${name}\\s*\\{`),
		`missing ${name} composition`,
	);
for (const name of capabilityAliases)
	assert.match(
		facade,
		new RegExp(`readonly property alias ${name}:`),
		`missing stable ${name} alias`,
	);

const legacyProperties = [
	"theme",
	"activeUserAvatarSource",
	"activeUserAvatarState",
	"networkRefreshMs",
	"systemStatsRefreshMs",
	"networkDevices",
	"lanDevice",
	"wifiDevice",
	"lanInterface",
	"wifiInterface",
	"ethernetInfo",
	"ethernetInfoRequestedInterface",
	"ethernetInfoRequestGeneration",
	"ethernetInfoProcessGeneration",
	"ethernetInfoProcessRefreshesProfile",
	"wifiInfo",
	"wifiInfoRequestedInterface",
	"wifiInfoAvailability",
	"wifiInfoRequestGeneration",
	"wifiInfoProcessGeneration",
	"ethernetProfileBusy",
	"ethernetProfileAwaitingRefresh",
	"ethernetProfileActionGeneration",
	"ethernetProfileActionProcessGeneration",
	"ethernetProfilePendingUuid",
	"ethernetProfileError",
	"powerProfiles",
	"sink",
	"source",
	"audioSources",
	"audioOutputs",
	"playbackStreams",
	"batteries",
	"readyBatteries",
	"batteryAvailable",
	"batteryCharging",
	"batteryEmpty",
	"batteryFull",
	"batteryPendingCharge",
	"batteryPendingDischarge",
	"batteryUnknown",
	"batteryLow",
	"batteryCritical",
	"batteryLevel",
	"bluetoothAdapter",
	"bluetoothAvailable",
	"bluetoothPowered",
	"bluetoothConnectedCount",
	"notificationCount",
	"hasNotifications",
	"notifications",
	"minVisibleNotifications",
	"notificationPopupEstimatedHeight",
	"maxNotificationHistory",
	"notificationHistoryFile",
	"focusedNotificationScreenName",
	"statusWorkspaceIds",
	"statusOccupiedWorkspaceIds",
	"statusUrgentWorkspaceIds",
	"maxPopupIngressPerSecond",
	"maxNotificationQueueSize",
	"notificationTimeoutLow",
	"notificationTimeoutNormal",
	"notificationTimeoutCritical",
	"notificationRules",
	"notificationQueue",
	"visibleNotifications",
	"notificationPopupCapacity",
	"notificationPopupSequence",
	"notificationIngressSecond",
	"notificationIngressCount",
	"notificationTimeUpdateTick",
	"notificationCenterOpen",
	"notificationHistory",
	"notificationDnd",
	"time",
	"date",
	"powerProfile",
	"sinkVolume",
	"sinkMuted",
	"microphoneAvailable",
	"sourceVolume",
	"sourceMuted",
	"previousNetworkRx",
	"previousNetworkTx",
	"activeNetworkRxRate",
	"activeNetworkTxRate",
	"networkThroughputSubscriberCount",
	"networkDetailsSubscriberCount",
	"cpuUsageSubscriberCount",
	"memoryUsageSubscriberCount",
	"networkThroughputEnabled",
	"networkDetailsEnabled",
	"cpuUsageEnabled",
	"memoryUsageEnabled",
	"cpuUsage",
	"memoryUsage",
	"previousCpuStats",
	"lanUp",
	"wifiUp",
	"activeNetworkInterface",
	"connectedWifiNetwork",
	"wifiSignal",
	"previousNetworkInterface",
	"previousNetworkSampleMs",
	"brightnessDevice",
	"brightnessAvailable",
	"brightnessLevel",
	"pendingBrightnessLevel",
	"brightnessWriteDebounceMs",
	"brightnessPath",
	"maxBrightnessPath",
	"brightnessDevicePath",
	"quickBrightnessPathValid",
	"quickBrightnessPath",
	"quickMaxBrightnessPath",
	"quickVolume",
	"quickBrightness",
	"quickBrightnessMaximum",
	"quickBrightnessRequestId",
];
for (const name of legacyProperties)
	assert.match(
		facade,
		new RegExp(
			`property alias ${name}:|property (?:var|string|int|real|bool) ${name}:|readonly property (?:var|string|int|real|bool) ${name}:`,
		),
		`legacy property missing: ${name}`,
	);

const legacyMethods = [
	"enableNetworkThroughput",
	"refreshActiveUserAvatar",
	"disableNetworkThroughput",
	"enableNetworkDetails",
	"disableNetworkDetails",
	"enableCpuUsage",
	"disableCpuUsage",
	"enableMemoryUsage",
	"disableMemoryUsage",
	"focusWorkspace",
	"statusWorkspaceIdsForMonitor",
	"updateClock",
	"pad",
	"toggleMute",
	"setSourceVolume",
	"selectAudioSource",
	"selectAudioSink",
	"togglePlaybackStreamMute",
	"requestPlaybackStreamVolume",
	"changeVolume",
	"refreshQuickVolume",
	"requestSinkVolume",
	"refreshQuickBrightness",
	"failQuickBrightnessRead",
	"requestBrightness",
	"failQuickBrightnessRequest",
	"computeBatteryLevel",
	"hasBatteryState",
	"normalizePercentage",
	"detectBrightness",
	"detectBrightnessDevice",
	"clearBrightnessState",
	"updateBrightnessFromFiles",
	"setBrightness",
	"scheduleBrightnessWrite",
	"flushBrightnessWrite",
	"changeBrightness",
	"safeFileViewText",
	"resetNetworkSample",
	"refreshSystemStats",
	"updateCpuUsage",
	"updateMemoryUsage",
	"refreshEthernetInfo",
	"refreshWifiInfo",
	"setEthernetProfileEnabled",
	"refreshNetwork",
	"dismissNotifications",
	"dismissNotificationHistoryEntry",
	"setNotificationCenterOpen",
	"clearNotificationPopups",
	"toggleNotificationDnd",
	"enqueueNotificationPopup",
	"shouldShowNotificationPopup",
	"createNotificationPopup",
	"addNotificationToHistory",
	"createNotificationHistoryEntry",
	"persistentNotificationImage",
	"scheduleNotificationHistorySave",
	"saveNotificationHistory",
	"loadNotificationHistory",
	"processNotificationPopupQueue",
	"setNotificationPopupAvailableHeight",
	"closeNotificationPopup",
	"invokeNotificationPopupAction",
	"notificationPopupTimeout",
	"notificationTimeText",
	"formatNotificationTime",
	"evaluateNotificationPolicy",
	"matchesNotificationRule",
	"matchesRuleValue",
	"coerceNotificationUrgency",
	"stripImages",
	"escapeHtml",
	"resolveHtmlBody",
	"nextPowerProfile",
	"profileSlug",
];
for (const name of legacyMethods)
	assert.match(
		facade,
		new RegExp(`function ${name}\\s*\\(`),
		`legacy method missing: ${name}`,
	);

for (const type of [
	"NotificationServer",
	"Process",
	"FileView",
	"PwObjectTracker",
	"StdioCollector",
])
	assert.doesNotMatch(
		facade,
		new RegExp(`\\b${type}\\s*\\{`),
		`${type} must not remain facade-owned`,
	);

const ownershipContracts = {
	AudioService: ["PwObjectTracker", "quickVolume"],
	BrightnessService: [
		"brightnessDetectProcess",
		"quickBrightnessConfirmationTimer",
	],
	NetworkService: [
		"ethernetInfoProcess",
		"wifiInfoProcess",
		"ethernetProfileActionProcess",
	],
	NotificationService: [
		"NotificationServer",
		"JsonAdapter",
		"Component.onDestruction",
	],
	BatteryPowerService: ["PowerProfiles.profile", "computeBatteryLevel"],
	BluetoothService: ["Bluetooth.defaultAdapter"],
	SystemStatsService: ["/proc/stat", "cpuUsageSubscriberCount"],
	WorkspaceService: ["Hyprland.workspaces", "focusWorkspace"],
};
for (const name of capabilityNames) {
	const source = fs.readFileSync(
		path.join(root, "capabilities", `${name}.qml`),
		"utf8",
	);
	assert.doesNotMatch(
		source,
		/Services\.qml|\bservice\./,
		`${name} must not depend on facade`,
	);
	for (const marker of ownershipContracts[name])
		assert.ok(source.includes(marker), `${name} must own ${marker}`);
}
const audioSource = fs.readFileSync(
	path.join(root, "capabilities", "AudioService.qml"),
	"utf8",
);
assert.match(
	audioSource,
	/normalizedVolumeRequest\(percent, Boolean\(node\?\.audio\)\)/,
);
assert.match(audioSource, /function isWritablePlaybackStream\(node\)/);
assert.doesNotMatch(
	audioSource,
	/recognizedPlaybackStreams|retainKnownPlaybackStreams|rebuildPlaybackStreams/,
);
assert.ok(
	(
		audioSource.match(
			/if \(!root\.isWritablePlaybackStream\(node\)\)\s*return false;?/g,
		) || []
	).length === 2,
	"each playback control must validate live writable identity immediately before mutation",
);
for (const marker of [
	"objects: root.allAudioNodes",
	"AudioNodeState.physicalOutputs(root.allAudioNodes, root.sink)",
	"readonly property var playbackStreams: AudioNodeState.playbackStreams(root.allAudioNodes)",
	"Pipewire.preferredDefaultAudioSink = node",
	"const node = root.sink",
	"isCurrentPhysicalSink(node)",
	"failMasterWrite(requestId)",
	"AudioNodeState.canControlPlaybackStream(root.allAudioNodes, node)",
	"node.audio.muted = false",
	"node.audio.volume = request.volume",
	"confirmationTimer.stop()",
	'root.quickVolume = QuickControlState.unavailableCapability("Volume unavailable")',
])
	assert.ok(
		audioSource.includes(marker),
		`audio mixer contract missing: ${marker}`,
	);
assert.doesNotMatch(facade, /Pipewire\.|PwObjectTracker\s*\{/);

const notificationSource = fs.readFileSync(
	path.join(root, "capabilities", "NotificationService.qml"),
	"utf8",
);
for (const contract of [
	"keepOnReload: false",
	"interval: 500",
	"statusbar-notifications.json",
	"persistenceSupported: true",
])
	assert.ok(
		notificationSource.includes(contract),
		`notification lifecycle contract missing: ${contract}`,
	);

for (const shellPath of [
	path.join(root, "..", "shell.qml"),
	path.join(root, "..", "smoketest.qml"),
]) {
	const shell = fs.readFileSync(shellPath, "utf8");
	assert.match(
		shell,
		/Services\.Services\s*\{/,
		`${shellPath} must retain its Services instance`,
	);
}

const helperSource = fs.readFileSync(
	path.join(root, "FileViewState.js"),
	"utf8",
);
const helper = { console: { warn() {} } };
vm.createContext(helper);
vm.runInContext(helperSource, helper);
let reloads = 0;
const fileView = {
	reload() {
		reloads++;
	},
	text() {
		return "42\n";
	},
};
assert.equal(helper.safeText(fileView, "value", true), "42\n");
assert.equal(reloads, 1);
assert.equal(helper.safeText(null, "value", false), null);
assert.equal(
	helper.safeText(
		{
			text() {
				throw new Error("read");
			},
		},
		"value",
		false,
	),
	null,
);

console.log(
	"Services contract: facade compatibility, ownership, dependency, and FileView helper contracts passed",
);
