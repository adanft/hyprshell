const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = __dirname;
const facade = fs.readFileSync(path.join(root, "Services.qml"), "utf8");
const capabilityNames = [
	"AudioService",
	"BrightnessService",
	"NetworkService",
	"NotificationService",
	"BatteryPowerService",
	"BluetoothService",
	"PairingAgentService",
	"SystemStatsService",
	"WorkspaceService",
];
const aliases = [
	"audio",
	"brightness",
	"network",
	"notification",
	"batteryPower",
	"bluetooth",
	"pairingAgent",
	"systemStats",
	"workspace",
];

for (const name of capabilityNames)
	assert.match(
		facade,
		new RegExp(`Capabilities\\.${name}\\s*\\{`),
		`missing ${name} composition`,
	);
const actualAliases = [...facade.matchAll(/readonly property alias (\w+):/g)].map(match => match[1]);
assert.deepEqual(actualAliases, aliases);

assert.match(facade, /property bool pairingAgentEnabled: false/);
assert.match(facade, /Capabilities\.ActiveUserAvatar\s*\{/);

for (const state of ["theme", "activeUserAvatarSource", "activeUserAvatarState", "time", "date"])
	assert.match(
		facade,
		new RegExp(`readonly property (?:var|string) ${state}\\b`),
		`missing root state ${state}`,
	);

assert.doesNotMatch(facade, /notificationsCapability|notificationCapability/);
assert.doesNotMatch(facade, /function\s+[A-Za-z0-9_]+\s*\(/);
for (const type of ["NotificationServer", "Process", "FileView", "PwObjectTracker", "StdioCollector"])
	assert.doesNotMatch(
		facade,
		new RegExp(`\\b${type}\\s*\\{`),
		`${type} must remain capability-owned`,
	);

for (const name of capabilityNames) {
	const source = fs.readFileSync(path.join(root, "capabilities", `${name}.qml`), "utf8");
	assert.doesNotMatch(source, /Services\.qml|\bservice\./, `${name} depends on facade`);
}

for (const shellPath of [path.join(root, "..", "shell.qml"), path.join(root, "..", "smoketest.qml")])
	assert.match(fs.readFileSync(shellPath, "utf8"), /Services\.Services\s*\{/);

console.log("Services contract: namespaced capability facade and root state passed");
