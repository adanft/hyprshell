const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const owners = {
	audio: "sink source audioSources audioOutputs playbackStreams sinkVolume sinkMuted microphoneAvailable sourceVolume sourceMuted quickVolume toggleMute setSourceVolume selectAudioSource selectAudioSink togglePlaybackStreamMute requestPlaybackStreamVolume changeVolume requestSinkVolume".split(
		" ",
	),
	brightness:
		"brightnessAvailable brightnessLevel setBrightness changeBrightness".split(
			" ",
		),
	network:
		"wifiDevice lanDevice lanUp wifiUp wifiSignal connectedWifiNetwork wifiInterface wifiInfo wifiInfoAvailability ethernetInfo ethernetProfileBusy ethernetProfilePendingUuid ethernetProfileError activeNetworkInterface activeNetworkTxRate activeNetworkRxRate enableNetworkThroughput disableNetworkThroughput enableNetworkDetails disableNetworkDetails setEthernetProfileEnabled toggleWifiEnabled".split(
			" ",
		),
	notification:
		"notificationCount hasNotifications notifications notificationDnd visibleNotifications focusedNotificationScreenName dismissNotifications dismissNotificationHistoryEntry setNotificationCenterOpen toggleNotificationDnd setNotificationPopupAvailableHeight closeNotificationPopup invokeNotificationPopupAction notificationPopupTimeout notificationTimeText registerNotificationPopupManager unregisterNotificationPopupManager setNotificationPopupHovered".split(
			" ",
		),
	batteryPower:
		"batteryAvailable batteryCharging batteryEmpty batteryFull batteryPendingCharge batteryPendingDischarge batteryUnknown batteryLow batteryCritical batteryLevel powerProfile nextPowerProfile".split(
			" ",
		),
	bluetooth:
		"bluetoothAdapter bluetoothAvailable bluetoothPowered bluetoothConnectedCount bluetoothDiscovering bluetoothAdapterName bluetoothDiscoverable bluetoothDevices bluetoothBusy bluetoothError bluetoothPendingRevision toggleBluetoothPowered toggleBluetoothDiscoverable scanBluetooth setBluetoothScanning connectBluetoothDevice disconnectBluetoothDevice pairBluetoothDevice forgetBluetoothDevice bluetoothDevicePending bluetoothDeviceBusy".split(
			" ",
		),
	systemStats:
		"cpuUsage memoryUsage enableCpuUsage disableCpuUsage enableMemoryUsage disableMemoryUsage".split(
			" ",
		),
	workspace:
		"statusOccupiedWorkspaceIds statusUrgentWorkspaceIds statusWorkspaceIdsForMonitor focusWorkspace".split(
			" ",
		),
};

const capabilityNames = new Set(Object.keys(owners));
const rootExceptions = new Set(["time", "date", "activeUserAvatarSource"]);
const ownerByMember = new Map();
for (const [owner, members] of Object.entries(owners)) {
	for (const member of members) {
		assert.equal(
			ownerByMember.has(member),
			false,
			`ownership map duplicates ${member}`,
		);
		ownerByMember.set(member, owner);
	}
}

const accessPattern =
	/\bservices\s*(?:\?\.|\.)\s*([A-Za-z_]\w*)(?:\s*(?:\?\.|\.)\s*([A-Za-z_]\w*))?/g;

function violations(relativePath, source) {
	const failures = [];
	for (const match of source.matchAll(accessPattern)) {
		const firstMember = match[1];
		const secondMember = match[2];
		const line = source.slice(0, match.index).split("\n").length;
		const expectedOwner = ownerByMember.get(firstMember);

		if (expectedOwner) {
			failures.push(
				`${relativePath}:${line}: services.${firstMember} is flat; use services.${expectedOwner}.${firstMember}`,
			);
			continue;
		}

		if (capabilityNames.has(firstMember)) {
			if (!secondMember) continue;

			const secondOwner = ownerByMember.get(secondMember);
			if (!secondOwner) {
				failures.push(
					`${relativePath}:${line}: services.${firstMember}.${secondMember} is not declared in the ${firstMember} ownership map`,
				);
			} else if (secondOwner !== firstMember) {
				failures.push(
					`${relativePath}:${line}: services.${firstMember}.${secondMember} uses the wrong capability; use services.${secondOwner}.${secondMember}`,
				);
			}
			continue;
		}

		if (rootExceptions.has(firstMember)) continue;

		failures.push(
			`${relativePath}:${line}: services.${firstMember} is an unclassified flat access`,
		);
	}
	return failures;
}

function assertRejected(source, expectedMessage) {
	const failures = violations("fixture.qml", source);
	assert.ok(
		failures.length > 0,
		`expected fixture to be rejected: ${source}`,
	);
	assert.ok(
		failures.some((failure) => failure.includes(expectedMessage)),
		`expected diagnostic containing ${expectedMessage}; got ${failures.join("; ")}`,
	);
}

function assertAccepted(source) {
	assert.deepEqual(violations("fixture.qml", source), []);
}

assertRejected("services.wifiUp", "services.network.wifiUp");
assertRejected("root.services.toggleMute(true)", "services.audio.toggleMute");
assertRejected(
	"popup.services.dismissNotifications()",
	"services.notification.dismissNotifications",
);
assertRejected(
	"services.network.unknownMember",
	"is not declared in the network ownership map",
);
assertRejected("services.audio.wifiUp", "services.network.wifiUp");

for (const source of [
	"services.network",
	"services.network.wifiUp",
	"root.services.audio.toggleMute(true)",
	"popup.services.notification.dismissNotifications()",
	"services.time",
	"root.services.date",
	"root.services.activeUserAvatarSource",
	"services: root.services",
]) {
	assertAccepted(source);
}

const moduleDirectory = path.join(root, "features/statusbar/modules");
const consumerPaths = fs
	.readdirSync(moduleDirectory, { withFileTypes: true })
	.filter((entry) => entry.isFile() && entry.name.endsWith(".qml"))
	.map((entry) => path.posix.join("features/statusbar/modules", entry.name));

const explicitConsumerPaths = [
	// Tray left statusbar/modules for its own slice, so the directory sweep
	// above no longer reaches it. Named here rather than lost.
	"features/tray/Tray.qml",
	"features/statusbar/components/AudioControl.qml",
	"features/controlcenter/ControlCenter.qml",
	"features/notifications/NotificationPopupManager.qml",
	"features/notifications/NotificationPopup.qml",
	"features/notifications/NotificationCenter.qml",
];

for (const relativePath of explicitConsumerPaths) {
	assert.ok(
		fs.existsSync(path.join(root, relativePath)),
		`explicit consumer is missing: ${relativePath}`,
	);
}
consumerPaths.push(...explicitConsumerPaths);

const failures = consumerPaths.flatMap((relativePath) => {
	const source = fs.readFileSync(path.join(root, relativePath), "utf8");
	return violations(relativePath, source);
});

assert.deepEqual(
	failures,
	[],
	`capability-owned service accesses must be qualified:\n${failures.join("\n")}`,
);

console.log(
	"ConsumerCapabilityAccess: internal consumers use named capabilities",
);
