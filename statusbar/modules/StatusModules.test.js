const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const read = (name) => fs.readFileSync(path.join(__dirname, name), "utf8");
const wifi = read("NetworkWifi.qml");
const bluetooth = read("Bluetooth.qml");
const audio = fs.readFileSync(
	path.join(__dirname, "../components/AudioControl.qml"),
	"utf8",
);
const networkService = fs.readFileSync(
	path.join(__dirname, "../../services/capabilities/NetworkService.qml"),
	"utf8",
);
const bluetoothService = fs.readFileSync(
	path.join(__dirname, "../../services/capabilities/BluetoothService.qml"),
	"utf8",
);

assert.match(
	wifi,
	/onClicked:\s*root\.services\.network\.toggleWifiEnabled\(\)/,
);
assert.match(
	bluetooth,
	/onClicked:\s*root\.services\.bluetooth\.toggleBluetoothPowered\(\)/,
);
assert.match(
	networkService,
	/Networking\.wifiEnabled\s*=\s*!Networking\.wifiEnabled/,
);
assert.match(
	bluetoothService,
	/bluetoothAdapter\.enabled\s*=\s*!bluetoothAdapter\.enabled/,
);
assert.match(
	audio,
	/visible:\s*root\.available\n\s*text: `\$\{root\.volume\}%`/,
);
assert.doesNotMatch(audio, /visible:\s*root\.available\s*&&\s*!root\.muted/);
assert.doesNotMatch(
	wifi,
	/enableNetworkThroughput|activeNetworkRxRate|activeNetworkTxRate/,
);
// Silencing a module reads the same as a module that has nothing to offer:
// muting audio, enabling Do Not Disturb, and an unavailable device all dim.
const notifications = read("Notifications.qml");
assert.match(audio, /moduleDisabled:\s*!available \|\| muted/);
assert.match(
	notifications,
	/moduleDisabled:\s*services\.notification\.notificationDnd[\s\S]{0,80}?!services\.notification\.hasNotifications/,
);

assert.match(wifi, /Row\s*\{[\s\S]*?\n {4}\}\n\n {4}MouseArea/);
assert.match(bluetooth, /Row\s*\{[\s\S]*?\n {4}\}\n\n {4}MouseArea/);
