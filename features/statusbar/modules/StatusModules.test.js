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
	path.join(__dirname, "../../../services/capabilities/NetworkService.qml"),
	"utf8",
);
const bluetoothService = fs.readFileSync(
	path.join(__dirname, "../../../services/capabilities/BluetoothService.qml"),
	"utf8",
);

const throughput = read("NetworkThroughput.qml");

// What a module does, not what it says about itself. A comment naming MouseArea
// is documentation; only code makes the module clickable. Strings are matched
// before comments so that a "//" inside one survives, which is what keeps
// "0 B/s" and the KiB/s template from being read as the start of a comment.
const codeOnly = (source) =>
	source.replace(
		/`(?:\\[\s\S]|[^\\`])*`|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\/\*[\s\S]*?\*\/|\/\/[^\n]*/g,
		(match) => (match.startsWith("//") || match.startsWith("/*") ? "" : match),
	);
const throughputCode = codeOnly(throughput);

// One gesture means one thing across the whole bar: left opens the panel on
// this module's section, right performs the module's own destructive action.
// Left used to toggle here, which put "open" and "turn off" on the same click
// depending on which module you aimed at.
for (const [name, source, toggle] of [
	["NetworkWifi", wifi, "root.services.network.toggleWifiEnabled()"],
	["Bluetooth", bluetooth, "root.services.bluetooth.toggleBluetoothPowered()"],
	["AudioControl", audio, "root.services.audio.toggleMute(root.source)"],
]) {
	assert.match(
		source,
		/acceptedButtons: Qt\.LeftButton \| Qt\.RightButton/,
		`${name} must answer both buttons`,
	);
	assert.match(
		source,
		new RegExp(
			`mouse\\.button === Qt\\.RightButton\\)\\s*\\n\\s*${toggle.replace(/[.()|]/g, "\\$&")}`,
		),
		`${name} must put its toggle on the right button`,
	);
	assert.match(source, /else\s*\n\s*root\.openRequested\(\)/, `${name} must open on the left`);
	assert.match(source, /signal openRequested/, `${name} must offer the open signal`);
}

// The throughput readout is the exception: it is display only. No gesture at
// all, so it must not grow a MouseArea, a signal, or a keyboard stop.
assert.doesNotMatch(throughputCode, /MouseArea/);
assert.doesNotMatch(throughputCode, /signal openRequested/);
assert.doesNotMatch(throughputCode, /onClicked|acceptedButtons|RightButton/);
assert.doesNotMatch(throughputCode, /activeFocusOnTab|cursorShape|Keys\./);
assert.match(throughputCode, /Accessible\.role: Accessible\.StaticText/);

// codeOnly has to earn the trust the assertions above place in it: it must drop
// a comment that names a gesture without touching a string that merely looks
// like one.
assert.doesNotMatch(codeOnly("// no MouseArea here\nItem {}"), /MouseArea/);
assert.match(codeOnly(`const rate = "1 KiB/s" // cursorShape`), /1 KiB\/s/);
assert.doesNotMatch(codeOnly(`const rate = "1 KiB/s" // cursorShape`), /cursorShape/);
assert.match(codeOnly("/* Keys.onSpacePressed */ Item {}"), /Item \{\}/);
assert.doesNotMatch(codeOnly("/* Keys.onSpacePressed */ Item {}"), /Keys\./);
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
