const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(`${__dirname}/NetworkMenu.js`, "utf8");
const menu = {};
vm.createContext(menu);
vm.runInContext(source, menu);

assert.equal(menu.userInitial("dioby"), "D");
assert.equal(menu.userInitial(""), "U");
assert.equal(menu.userInitial(null), "U");

assert.equal(menu.hostnameOrFallback("desktop\n"), "desktop");
assert.equal(menu.hostnameOrFallback(""), "localhost");
assert.equal(menu.hostnameOrFallback("   \n"), "localhost");
assert.equal(menu.hostnameOrFallback(null), "localhost");

assert.equal(menu.formatUptime(0), "Up 0m");
assert.equal(menu.formatUptime(3599), "Up 59m");
assert.equal(menu.formatUptime(3660), "Up 1h 1m");
assert.equal(menu.formatUptime(90000), "Up 1d 1h");
assert.equal(menu.formatUptime(-1), "Up 0m");
assert.equal(menu.formatUptime(Number.NaN), "Up 0m");

assert.equal(menu.networkStatus({ connected: true, known: true }), "Connected");
assert.equal(menu.networkStatus({ connected: false, known: true }), "Saved");
assert.equal(
	menu.networkStatus({ connected: false, known: false }),
	"Available",
);
assert.equal(menu.networkStatus(null), "Unavailable");
assert.equal(
	menu.canForgetNetwork({
		known: true,
		connected: false,
		stateChanging: false,
	}),
	true,
);
assert.equal(
	menu.canForgetNetwork({ known: true, connected: true, stateChanging: false }),
	false,
);
assert.equal(
	menu.canForgetNetwork({
		known: false,
		connected: false,
		stateChanging: false,
	}),
	false,
);
assert.equal(menu.canForgetNetwork(null), false);

assert.equal(
	menu.networkSignalText({ stateChanging: true, signalStrength: 0.75 }),
	"…",
);
assert.equal(
	menu.networkSignalText({ stateChanging: false, signalStrength: 0.754 }),
	"75%",
);
assert.equal(menu.networkSignalText(null), "0%");
assert.equal(menu.wifiSignalQualityText({ signalStrength: 0.754 }), "75%");
assert.equal(
	menu.wifiSignalQualityText({ stateChanging: true, signalStrength: 0.754 }),
	"75%",
);
assert.equal(menu.wifiSignalQualityText(null), "");

assert.equal(
	menu.wifiSummary({ name: "Home", signalStrength: 0.814 }, true),
	"Home · 81%",
);
assert.equal(menu.wifiSummary(null, true), "Not connected");
assert.equal(menu.wifiSummary(null, false), "Disabled by hardware");
assert.equal(menu.wifiSecurityLabel({ security: 0 }, 0), "Open");
assert.equal(menu.wifiSecurityLabel({ security: 2 }, 0), "Secured");
assert.equal(menu.wifiSecurityLabel(null, 0), "");
assert.equal(
	menu.wifiNetworkMeta({ security: 0, signalStrength: 0.814 }, 0),
	"Open · 81%",
);
assert.equal(
	menu.wifiNetworkMeta({ security: 2, signalStrength: 0.754 }, 0),
	"Secured · 75%",
);
assert.equal(menu.wifiNetworkMeta(null, 0), "");

const sortedWifiNetworks = menu.sortedWifiNetworks([
	{ name: "Weak", connected: false, signalStrength: 0.2 },
	{ name: "Active", connected: true, signalStrength: 0.1 },
	{ name: "Strong", connected: false, signalStrength: 0.9 },
	{ name: "Medium", connected: false, signalStrength: 0.5 },
]);
assert.deepEqual(
	Array.from(sortedWifiNetworks, (network) => network.name),
	["Active", "Strong", "Medium", "Weak"],
);
assert.equal(menu.sortedWifiNetworks(null).length, 0);

assert.equal(menu.nextExpandedSection("", "ethernet"), "ethernet");
assert.equal(menu.nextExpandedSection("ethernet", "ethernet"), "");
assert.equal(menu.nextExpandedSection("ethernet", "wifi"), "wifi");
assert.equal(menu.nextExpandedSection("wifi", "microphone"), "microphone");
assert.equal(menu.nextExpandedSection("microphone", "bluetooth"), "bluetooth");

assert.equal(menu.ethernetToggleAction(null), null);
assert.equal(
	menu.ethernetToggleAction({ stateChanging: true, connected: false }),
	null,
);
assert.equal(
	menu.ethernetToggleAction({ stateChanging: false, connected: false }),
	"connect",
);
assert.equal(
	menu.ethernetToggleAction({ stateChanging: false, connected: true }),
	"disconnect",
);
assert.equal(
	menu.ethernetProfileLabel({ id: "Office LAN", uuid: "uuid" }),
	"Office LAN",
);
assert.equal(menu.ethernetProfileLabel({ id: "", uuid: "uuid" }), "uuid");
assert.equal(menu.ethernetProfileLabel(null), "Unnamed profile");
assert.equal(menu.shouldScanWifi(true, "wifi", true, true), true);
assert.equal(menu.shouldScanWifi(false, "wifi", true, true), false);
assert.equal(menu.shouldScanWifi(true, "ethernet", true, true), false);
assert.equal(menu.shouldScanWifi(true, "wifi", false, true), false);
assert.equal(menu.shouldScanWifi(true, "wifi", true, false), false);
assert.equal(menu.shouldStopBluetoothScan(true, "bluetooth", true), false);
assert.equal(menu.shouldStopBluetoothScan(false, "bluetooth", true), true);
assert.equal(menu.shouldStopBluetoothScan(true, "wifi", true), true);
assert.equal(menu.shouldStopBluetoothScan(false, "wifi", false), false);

assert.equal(menu.bluetoothSummary(false, false, 0), "Unavailable");
assert.equal(menu.bluetoothSummary(true, false, 0), "Off");
assert.equal(menu.bluetoothSummary(true, true, 0), "Enabled");
assert.equal(menu.bluetoothSummary(true, true, 2), "2 connected");
assert.equal(menu.bluetoothDeviceStatus({ pairing: true }), "Pairing…");
assert.equal(
	menu.bluetoothDeviceStatus({
		connected: true,
		batteryAvailable: true,
		battery: 0.67,
	}),
	"Connected · 67%",
);
assert.equal(
	menu.bluetoothDeviceStatus({ connected: false, paired: true }),
	"Paired",
);
assert.equal(
	menu.bluetoothDeviceStatus({ connected: false, paired: false }),
	"Available",
);
assert.equal(menu.bluetoothDeviceAction({ pairing: true }), "cancelPair");
assert.equal(
	menu.bluetoothDeviceAction({ pairing: false, paired: false }),
	"pair",
);
assert.equal(
	menu.bluetoothDeviceAction({
		pairing: false,
		paired: true,
		connected: false,
	}),
	"connect",
);
assert.equal(
	menu.bluetoothDeviceAction({ pairing: false, paired: true, connected: true }),
	"disconnect",
);
assert.equal(
	menu.bluetoothActionLabel({ pairing: false, paired: false }),
	"Pair",
);
const bluetoothCalls = [];
const pairableDevice = {
	pairing: false,
	paired: false,
	connected: false,
	pair: () => bluetoothCalls.push("pair"),
	cancelPair: () => bluetoothCalls.push("cancelPair"),
	connect: () => bluetoothCalls.push("connect"),
	disconnect: () => bluetoothCalls.push("disconnect"),
};
assert.equal(menu.runBluetoothDeviceAction(pairableDevice, "pair"), true);
assert.deepEqual(bluetoothCalls, ["pair"]);
assert.equal(menu.runBluetoothDeviceAction(pairableDevice, "connect"), false);
assert.deepEqual(bluetoothCalls, ["pair"]);
assert.equal(
	menu.audioSourceLabel({
		nickname: "Studio Mic",
		description: "Fallback",
		name: "node",
	}),
	"Studio Mic",
);
assert.equal(
	menu.audioSourceLabel({
		nickname: "",
		description: "USB microphone",
		name: "node",
	}),
	"USB microphone",
);
assert.equal(menu.audioSourceLabel(null), "Unknown input");
const activeSource = { audio: { muted: false } };
assert.equal(
	menu.audioSourceStatus(activeSource, activeSource),
	"Active input",
);
assert.equal(
	menu.audioSourceStatus({ audio: { muted: true } }, activeSource),
	"Muted",
);
assert.equal(
	menu.audioSourceStatus({ audio: { muted: false } }, activeSource),
	"Available",
);

console.log(
	"NetworkMenu: identity, uptime, network state, and control actions passed",
);
