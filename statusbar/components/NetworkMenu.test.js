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
	menu.networkSignalText({ stateChanging: true, signalStrength: 0.75 }),
	"…",
);
assert.equal(
	menu.networkSignalText({ stateChanging: false, signalStrength: 0.754 }),
	"75%",
);
assert.equal(menu.networkSignalText(null), "0%");

assert.equal(
	menu.wifiSummary({ name: "Home", signalStrength: 0.814 }, true),
	"Home · 81%",
);
assert.equal(menu.wifiSummary(null, true), "Not connected");
assert.equal(menu.wifiSummary(null, false), "Disabled by hardware");

assert.equal(menu.nextExpandedSection("", "ethernet"), "ethernet");
assert.equal(menu.nextExpandedSection("ethernet", "ethernet"), "");
assert.equal(menu.nextExpandedSection("ethernet", "wifi"), "wifi");

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

assert.equal(menu.shouldScanWifi(true, "wifi", true, true), true);
assert.equal(menu.shouldScanWifi(false, "wifi", true, true), false);
assert.equal(menu.shouldScanWifi(true, "ethernet", true, true), false);
assert.equal(menu.shouldScanWifi(true, "wifi", false, true), false);
assert.equal(menu.shouldScanWifi(true, "wifi", true, false), false);

console.log(
	"NetworkMenu: identity, uptime, network state, and control actions passed",
);
