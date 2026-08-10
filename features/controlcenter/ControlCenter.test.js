const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const componentDir = path.join(__dirname, "components");

// A file of this slice, wherever it sits: the panel, its controller and the
// password dialog live at the root, the pieces they compose live in components/.
const readSliceFile = (name) => {
	const atRoot = path.join(__dirname, `${name}.qml`);
	return fs.readFileSync(
		fs.existsSync(atRoot) ? atRoot : path.join(componentDir, `${name}.qml`),
		"utf8",
	);
};

const source = fs.readFileSync(`${__dirname}/ControlCenter.js`, "utf8");
const qml = fs.readFileSync(`${__dirname}/ControlCenter.qml`, "utf8");
const playbackRowQml = fs.readFileSync(
	`${componentDir}/AudioPlaybackStreamRow.qml`,
	"utf8",
);
const mixerQml = fs.readFileSync(`${componentDir}/AudioMixerSection.qml`, "utf8");
const bluetoothRowQml = fs.readFileSync(
	`${componentDir}/BluetoothDeviceRow.qml`,
	"utf8",
);
const bluetoothServiceQml = fs.readFileSync(
	`${__dirname}/../../services/capabilities/BluetoothService.qml`,
	"utf8",
);
const menu = {};
vm.createContext(menu);
vm.runInContext(source, menu);

function objectBlockById(text, id) {
	const idIndex = text.indexOf(`id: ${id}`);
	assert.notEqual(idIndex, -1, `missing object id: ${id}`);
	const openIndex = text.lastIndexOf("{", idIndex);
	let depth = 0;
	for (let index = openIndex; index < text.length; index += 1) {
		if (text[index] === "{") depth += 1;
		if (text[index] === "}") depth -= 1;
		if (depth === 0) return text.slice(openIndex + 1, index);
	}
	assert.fail(`unterminated object id: ${id}`);
}

const detailBootstrapHeight = 64;
assert.equal(
	menu.detailViewportHeight(false, 200, 100, detailBootstrapHeight),
	0,
);
assert.equal(
	menu.detailViewportHeight(true, 0, 100, detailBootstrapHeight),
	detailBootstrapHeight,
);
assert.equal(menu.detailViewportHeight(true, 0, 20, detailBootstrapHeight), 20);
assert.equal(menu.detailViewportHeight(true, 80, 0, detailBootstrapHeight), 0);
assert.equal(
	menu.detailViewportHeight(true, 80, -20, detailBootstrapHeight),
	0,
);
assert.equal(menu.detailViewportHeight(true, 1, 100, detailBootstrapHeight), 1);
assert.equal(
	menu.detailViewportHeight(true, 80, 100, detailBootstrapHeight),
	80,
);
assert.equal(
	menu.detailViewportHeight(true, 180, 100, detailBootstrapHeight),
	100,
);
assert.equal(
	menu.menuCenterHeight(1000, 16, 360, 24, 400, 8, false, 0, 64),
	424,
);
assert.equal(
	menu.menuCenterHeight(1000, 16, 360, 24, 200, 8, false, 0, 64),
	360,
);
assert.equal(
	menu.menuCenterHeight(1000, 16, 360, 24, 400, 8, true, 0, 64),
	496,
);
assert.equal(
	menu.menuCenterHeight(1000, 16, 360, 24, 400, 8, true, 80, 64),
	512,
);
assert.equal(
	menu.menuCenterHeight(1000, 16, 360, 24, 400, 8, true, 600, 64),
	700,
);
assert.equal(menu.menuCenterHeight(40, 16, 360, 24, 400, 8, true, 600, 64), 24);
assert.equal(menu.menuCenterHeight(0, 16, 360, 24, 400, 8, true, 80, 64), 0);
assert.equal(menu.menuCenterHeight(-10, 16, 360, 24, 400, 8, true, 80, 64), 0);
assert.equal(menu.menuOuterHeight(500, 360, 200), 360);
assert.equal(menu.menuOuterHeight(500, 360, 420), 420);
assert.equal(menu.menuOuterHeight(400, 360, 520), 400);
assert.equal(menu.menuOuterHeight(-10, 360, 200), 0);
assert.equal(menu.clampDetailContentY(false, 40, 200, 100), 0);
assert.equal(menu.clampDetailContentY(true, -10, 200, 100), 0);
assert.equal(menu.clampDetailContentY(true, 40, 200, 100), 40);
assert.equal(menu.clampDetailContentY(true, 180, 200, 100), 100);
assert.equal(menu.clampDetailContentY(true, 180, 120, 100), 20);
assert.equal(menu.clampDetailContentY(true, 40, 100, 0), 0);

const flickables = qml.match(/\bFlickable\s*\{/g) || [];
assert.equal(flickables.length, 1);
assert.doesNotMatch(qml, /id: menuFlickable/);
const menuLayoutBlock = objectBlockById(qml, "menuLayout");
const fixedShellBlock = objectBlockById(qml, "fixedShell");
const detailFlickableBlock = objectBlockById(qml, "detailFlickable");
const detailContentBlock = objectBlockById(qml, "detailContent");
assert.match(detailContentBlock, /id: bluetoothDetails/);
assert.match(
	detailContentBlock,
	/visible: root\.expandedNetworkSection === "bluetooth"/,
);
assert.match(
	detailContentBlock,
	/height: bluetoothDetailsColumn\.implicitHeight \+ root\.theme\.spacing\.space24/,
);
assert.equal((qml.match(/BluetoothDeviceRow\s*\{/g) || []).length, 3);
assert.doesNotMatch(
	qml,
	/bluetoothDetailsLegacy|bluetoothDeviceDelegateLegacy|width: parent\.width - 180|width: 90/,
);
assert.match(detailContentBlock, /BluetoothDeviceRow/);
// The Bluetooth panel has no header of its own: scanning shares the line that
// labels the info card, and the card itself carries no controls.
assert.doesNotMatch(detailContentBlock, /id: bluetoothDetailHeader|id: bluetoothDetailTitle/);
assert.match(detailContentBlock, /BluetoothInfoCard\s*\{/);
assert.match(detailContentBlock, /id: bluetoothInfoHeader/);
assert.match(
	detailContentBlock,
	/id: bluetoothInfoTitle[\s\S]*?text: "Bluetooth info"/,
);
assert.match(detailContentBlock, /id: scanButton[\s\S]*?anchors\.right: parent\.right/);
assert.match(detailContentBlock, /radius: height \/ 2/);
assert.match(detailContentBlock, /onClicked: root\.toggleBluetoothScan\(\)/);

const infoCard = fs.readFileSync(`${componentDir}/BluetoothInfoCard.qml`, "utf8");
assert.doesNotMatch(infoCard, /scan|Scan/);
assert.match(infoCard, /onClicked: card\.visibilityToggleRequested\(\)/);
assert.match(infoCard, /enabled: card\.powered/);
assert.match(
	detailContentBlock,
	/onVisibilityToggleRequested: root\.services\.bluetooth\.toggleBluetoothDiscoverable\(\)/,
);

// menuLayout is the only inset in the panel, so a card lands 12 from the box
// whether it sits in the fixed shell or inside a detail section.
for (const id of [
	"outputColumn",
	"microphoneColumn",
	"lanColumn",
	"wifiColumn",
	"bluetoothDetailsColumn",
]) {
	const columnBlock = objectBlockById(qml, id);
	assert.match(
		columnBlock,
		/anchors\.left: parent\.left\s*anchors\.right: parent\.right/,
		`${id} must span the full detail width`,
	);
	assert.doesNotMatch(
		columnBlock,
		/anchors\.margins:/,
		`${id} must not inset again: menuLayout already sits 12 from the box`,
	);
	assert.match(
		columnBlock,
		/spacing: root\.theme\.spacing\.space6/,
		`${id} must use the 6px sibling gap`,
	);
}
assert.doesNotMatch(
	qml,
	/x: root\.theme\.spacing\.space12|parent\.width - root\.theme\.spacing\.space24/,
	"no section may inset its children by hand",
);

// Both audio panels are components, so neither grows back into this file, and
// every empty list uses ControlEmptyState rather than rebuilding it.
assert.match(detailContentBlock, /AudioMixerSection\s*\{/);
assert.match(detailContentBlock, /AudioInputSection\s*\{/);
assert.doesNotMatch(
	qml,
	/statusBarControlEmptyStateHeight/,
	"an empty list must use ControlEmptyState, not rebuild it",
);

// Action buttons are pills of one height, and no component borrows the tray
// menu's row height to get there.
//
// The sweep used to skip TrayMenu and AudioControl by name, because it ran over
// a directory that also held the tray menu and a bar-module helper. Both live
// outside this slice now, so the sweep covers everything it finds — every file
// here belongs to the control centre, which is the point of the slice.
const sliceFiles = [
	...fs.readdirSync(__dirname).filter((name) => name.endsWith(".qml")),
	...fs
		.readdirSync(componentDir)
		.map((name) => path.join("components", name))
		.filter((name) => name.endsWith(".qml")),
];
for (const file of sliceFiles) {
	const source = fs.readFileSync(path.join(__dirname, file), "utf8");
	assert.doesNotMatch(
		source,
		/statusBarTrayMenuItemHeight/,
		`${file} must not borrow the tray menu row height`,
	);
	assert.doesNotMatch(
		source,
		/radius: (?:root\.)?theme\.shape\.radius8/,
		`${file} must use a pill for actions, not radius8`,
	);
	for (const [, block] of source.matchAll(/text: [\w.]*icons\.\w+[\s\S]{0,220}?\n\s{16,}\}/g))
		if (/font\.family:/.test(block))
			assert.match(
				block,
				/font\.family: [\w.]*typography\.iconFontFamily/,
				`${file} draws a glyph with the text font`,
			);
}

// Every row titles itself the same way: Semibold at textMd.
for (const file of [
	"EthernetProfileRow",
	"WifiNetworkRow",
	"BluetoothDeviceRow",
	"AudioOutputDeviceRow",
	"MicrophoneSourceRow",
	"AudioPlaybackStreamRow",
]) {
	const source = readSliceFile(file);
	assert.match(
		source,
		/font\.pixelSize: root\.theme\.typography\.textMd\s*\n\s*font\.styleName: root\.theme\.typography\.styleSemibold/,
		`${file} must title itself Semibold at textMd`,
	);
}

// Every slider in the panel is the same control: one height, one track tone.
for (const file of [
	"ControlCenter",
	"AudioMixerSection",
	"AudioInputSection",
	"AudioPlaybackStreamRow",
]) {
	const source = readSliceFile(file);
	for (const [, block] of source.matchAll(/QuickControlSlider \{([\s\S]*?)\n(\s*)\}/g)) {
		assert.match(
			block,
			/height: root\.theme\.sizing\.statusBarNetworkQuickControlSliderHeight/,
			`${file} sizes a slider differently`,
		);
		assert.match(block, /trackColor: Colors\.surface_variant/, `${file} tints a slider track differently`);
	}
}

// The Wi-Fi password dialog is one of the shell's overlays, so it takes their
// body: opaque shadow, no border, and the shared padding and field tokens.
const modal = fs.readFileSync(`${__dirname}/WifiPasswordModal.qml`, "utf8");
assert.match(modal, /radius: root\.theme\.shape\.appLauncherRadius/);
assert.match(modal, /color: Colors\.shadow/);
assert.doesNotMatch(modal, /Qt\.alpha\(Colors\.surface/);
assert.doesNotMatch(modal, /border\.width: root\.theme\.shape\.appLauncherBorderWidth/);
assert.match(modal, /anchors\.margins: root\.theme\.spacing\.space18/);
assert.match(modal, /spacing: root\.theme\.spacing\.space18/);
assert.match(modal, /height: root\.theme\.sizing\.searchFieldHeight/);
assert.match(modal, /radius: root\.theme\.shape\.appLauncherSearchRadius/);
// Its actions are pills, like every action in the control center. Close, Cancel
// and Connect: three, and no fourth shape among them.
assert.equal((modal.match(/radius: height \/ 2/g) || []).length, 3);
// The field carries no border at all, like the search field it copies. A ring
// that paints on focus is painted from the first frame here, because the dialog
// puts the caret in the field as it opens.
assert.doesNotMatch(modal, /border\.(color|width)/);
assert.doesNotMatch(modal, /radius: root\.theme\.shape\.radius12/);

// The five detail sections are layout boxes, not painted surfaces.
assert.doesNotMatch(detailContentBlock, /color: "transparent"/);
for (const id of ["outputCard", "microphoneCard", "lanCard", "bluetoothDetails", "wifiCard"])
	assert.match(
		detailContentBlock,
		new RegExp(`Item \\{\\s*id: ${id}\\b`),
		`${id} must be an Item: it paints nothing`,
	);
assert.match(bluetoothRowQml, /signal primaryActionRequested/);
assert.match(bluetoothRowQml, /property bool primaryActionVisible: true/);
assert.match(bluetoothRowQml, /visible: root\.primaryActionVisible/);
assert.match(
	qml,
	/primaryActionVisible: root\.services\.bluetooth\.bluetoothPowered/,
);
assert.doesNotMatch(qml, /primaryActionVisible: true/);
assert.match(
	bluetoothServiceQml,
	/function connectBluetoothDevice[\s\S]*!bluetoothPowered/,
);
assert.match(
	bluetoothServiceQml,
	/function pairBluetoothDevice[\s\S]*!bluetoothPowered/,
);
assert.match(bluetoothServiceQml, /import Quickshell\.Io/);
assert.match(
	bluetoothServiceQml,
	/id: bluetoothErrorTimer[\s\S]*interval: 4000[\s\S]*onTriggered: root\.bluetoothError = ""/,
);
assert.match(
	bluetoothServiceQml,
	/onBluetoothErrorChanged:[\s\S]*bluetoothErrorTimer\.restart\(\)[\s\S]*bluetoothErrorTimer\.stop\(\)/,
);
assert.equal(
	(bluetoothServiceQml.match(/device\.connect\(\)/g) || []).length,
	1,
	"only known-device connect uses Quickshell directly",
);
assert.match(
	bluetoothServiceQml,
	/Process \{[\s\S]*id: bluetoothPairProcess[\s\S]*stdout: StdioCollector \{\}[\s\S]*stderr: StdioCollector \{\}[\s\S]*onExited: \(exitCode, exitStatus\) => \{[\s\S]*if \(exitCode !== 0\)[\s\S]*root\.bluetoothError = "Could not pair device"/,
);
assert.match(
	bluetoothServiceQml,
	/function pairBluetoothDevice\(device\)[\s\S]*const address = device\?\.address \|\| ""[\s\S]*bluetoothPendingAddress = address[\s\S]*bluetoothPairProcess\.exec\(\[[\s\S]*"sh",[\s\S]*"-c",[\s\S]*"timeout 30 bluetoothctl pair \\"\$1\\" && bluetoothctl trust \\"\$1\\" && timeout 30 bluetoothctl connect \\"\$1\\"",[\s\S]*"bluetooth-pair",[\s\S]*address/,
);
assert.match(
	bluetoothServiceQml,
	/function bluetoothDevicePending\(device\)[\s\S]*device\.address === bluetoothPendingAddress/,
);
assert.match(
	bluetoothServiceQml,
	/function connectBluetoothDevice\(device\)[\s\S]*try \{[\s\S]*device\.connect\(\)[\s\S]*catch \(error\)[\s\S]*Could not connect Bluetooth device/,
);
assert.match(
	bluetoothServiceQml,
	/function disconnectBluetoothDevice\(device\)[\s\S]*try \{[\s\S]*device\.disconnect\(\)[\s\S]*catch \(error\)[\s\S]*Could not disconnect Bluetooth device/,
);
assert.match(
	bluetoothServiceQml,
	/property var bluetoothPendingForgetDevice: null[\s\S]*property int bluetoothPendingForgetElapsed: 0/,
);
assert.match(
	bluetoothServiceQml,
	/id: bluetoothForgetTimer[\s\S]*interval: 100[\s\S]*if \(!device\.connected\)[\s\S]*device\.forget\(\)[\s\S]*Could not forget Bluetooth device[\s\S]*bluetoothPendingForgetElapsed >= 4000[\s\S]*Could not disconnect Bluetooth device before forgetting/,
);
assert.match(
	bluetoothServiceQml,
	/function forgetBluetoothDevice\(device\)[\s\S]*device\.disconnect\(\)[\s\S]*bluetoothForgetTimer\.start\(\)[\s\S]*return true/,
);
assert.match(
	bluetoothServiceQml,
	/function forgetBluetoothDevice\(device\)[\s\S]*try \{[\s\S]*device\.forget\(\)[\s\S]*catch \(error\)[\s\S]*Could not forget Bluetooth device/,
);
assert.doesNotMatch(
	bluetoothServiceQml,
	/stdinEnabled|\.write\(|--agent|default-agent|validBluetoothMac|PairPostconditions|pair-cli|PendingOperations|operationTimer|TimeoutTimer|SettleTimer|Instantiator|traceBluetoothState|bluetoothDebugLogging/,
);
assert.doesNotMatch(
	bluetoothServiceQml,
	/device\.pair\(\)|\$\{address\}|this\.text/,
);
assert.match(
	bluetoothServiceQml,
	/function setBluetoothScanning\(enabled\)[\s\S]*const desired = Boolean\(enabled\)[\s\S]*bluetoothAdapter\.discovering = desired/,
);
assert.match(
	bluetoothServiceQml,
	/property bool bluetoothDiscoveryChangePending: false/,
);
assert.match(
	bluetoothServiceQml,
	/id: bluetoothDiscoveryTransitionTimer[\s\S]*interval: 1500[\s\S]*bluetoothDiscoveryChangePending = false/,
);
assert.match(
	bluetoothServiceQml,
	/onBluetoothDiscoveringChanged:[\s\S]*bluetoothDiscoveryChangePending = false[\s\S]*bluetoothDiscoveryTransitionTimer\.stop\(\)/,
);
assert.match(
	bluetoothServiceQml,
	/bluetoothDiscovering\s*===\s*desired\s*\|\|\s*bluetoothDiscoveryChangePending[\s\S]*return false[\s\S]*bluetoothDiscoveryChangePending\s*=\s*true/,
);
assert.match(
	qml,
	/id: bluetoothScanTimer[\s\S]*interval: 25000[\s\S]*onTriggered: root\.stopBluetoothScan\(\)/,
);
assert.match(
	qml,
	/function startBluetoothScan\(\)[\s\S]*setBluetoothScanning\(true\)[\s\S]*bluetoothScanTimer\.restart\(\)/,
);
assert.match(
	qml,
	/function stopBluetoothScan\(\)[\s\S]*bluetoothScanTimer\.stop\(\)[\s\S]*setBluetoothScanning\(false\)/,
);
assert.match(
	qml,
	/onExpandedNetworkSectionChanged:[\s\S]*expandedNetworkSection === "bluetooth"[\s\S]*startBluetoothScan\(\)[\s\S]*stopBluetoothScan\(\)/,
);
assert.match(
	qml,
	/function close\(\) \{[\s\S]*stopBluetoothScan\(\)[\s\S]*controlCenterController\.requestClose\(\)/,
);
assert.doesNotMatch(
	bluetoothServiceQml,
	/function onConnectedChanged\(\)\s*\{[^}]*connectBluetoothDevice/,
	"connection drops must not trigger auto-reconnect",
);
assert.doesNotMatch(bluetoothServiceQml, /Python|daemon|auto-reconnect/);
assert.match(bluetoothRowQml, /signal forgetRequested/);
assert.match(bluetoothRowQml, /Accessible\.role: Accessible\.Button/);
assert.match(bluetoothRowQml, /bluetoothBatteryText/);
assert.match(
	bluetoothRowQml,
	/forgetAvailable:\s*Boolean\(powered\s*&&\s*device\s*&&\s*\(device\.connected\s*\|\|\s*device\.paired\s*\|\|\s*device\.trusted\)\)/,
);
assert.match(
	qml,
	/BluetoothDeviceRow \{[\s\S]*powered: root\.services\.bluetooth\.bluetoothPowered[\s\S]*primaryActionVisible: root\.services\.bluetooth\.bluetoothPowered/,
);
assert.match(
	bluetoothServiceQml,
	/function disconnectBluetoothDevice\(device\)[\s\S]*!bluetoothPowered/,
);
assert.match(
	bluetoothServiceQml,
	/function forgetBluetoothDevice\(device\)[\s\S]*!bluetoothPowered/,
);
assert.match(
	bluetoothRowQml,
	/root\.action\s*===\s*"connect"\s*\?\s*"Connect"\s*:\s*"Disconnect"/,
);
assert.match(bluetoothRowQml, /Keys\.onSpacePressed/);
assert.match(qml, /expandedNetworkSection === "bluetooth"/);
assert.match(
	qml,
	/onBodyClicked: controlCenterController\.toggleNetworkSection\("bluetooth"\)/,
);
assert.match(qml, /text: "Known devices"/);
assert.match(qml, /model: bluetoothDetailsColumn\.connectedDevices/);
assert.match(qml, /model: bluetoothDetailsColumn\.knownDevices/);
assert.match(qml, /model: bluetoothDetailsColumn\.availableDevices/);
assert.equal(
	(
		detailContentBlock.match(
			/delegate: BluetoothDeviceRow \{\s+required property var modelData/g,
		) || []
	).length,
	3,
	"each Bluetooth repeater must bind its own modelData instead of the outer screen model",
);
assert.match(qml, /bluetoothDetailsColumn\.availableDevices\.length === 0/);
assert.doesNotMatch(
	qml,
	/(?:visible:|model:) (?:connectedDevices|knownDevices|availableDevices)\b/,
);
assert.match(
	detailContentBlock,
	/id: scanInput[\s\S]*enabled: root\.services\.bluetooth\.bluetoothPowered[\s\S]*cursorShape: enabled \? Qt\.PointingHandCursor : Qt\.ArrowCursor/,
);
assert.equal(
	(
		detailContentBlock.match(
			/root\.services\.bluetooth\.bluetoothPendingRevision/g,
		) || []
	).length,
	3,
	"every Bluetooth device section must react to pending-map revisions",
);
assert.match(qml, /device\.blocked/);
assert.match(
	qml,
	/text: root\.services\.bluetooth\.bluetoothError[\s\S]*font\.pixelSize: root\.theme\.typography\.textSm/,
);
for (const id of [
	"userCard",
	"quickControlsRow",
	"networkControlsRow",
	"audioControlsRow",
	"bluetoothCard",
])
	assert.ok(fixedShellBlock.includes(`id: ${id}`), `${id} must be fixed`);
for (const id of ["outputCard", "microphoneCard", "lanCard", "wifiCard"])
	assert.ok(
		!fixedShellBlock.includes(`id: ${id}`),
		`${id} must not be fixed`,
	);
assert.ok(menuLayoutBlock.includes("id: fixedShell"));
assert.ok(menuLayoutBlock.includes("id: detailFlickable"));
let previousDetailIndex = -1;
for (const section of ["output", "microphone", "ethernet", "wifi"]) {
	const cardId = section === "ethernet" ? "lanCard" : `${section}Card`;
	const cardIndex = detailContentBlock.indexOf(`id: ${cardId}`);
	assert.ok(cardIndex > previousDetailIndex, `${cardId} detail order`);
	previousDetailIndex = cardIndex;
	assert.ok(
		detailContentBlock.includes(
			`visible: root.expandedNetworkSection === "${section}"`,
		),
		`${section} visibility predicate`,
	);
}
for (const binding of [
	"clip: true",
	"boundsBehavior: Flickable.StopAtBounds",
	"flickableDirection: Flickable.VerticalFlick",
	"contentHeight: detailContent.implicitHeight",
	"onContentHeightChanged: root.clampDetailContentY()",
	"onHeightChanged: root.clampDetailContentY()",
])
	assert.ok(detailFlickableBlock.includes(binding), `missing ${binding}`);
assert.match(
	detailFlickableBlock,
	/interactive: root\.activeDetail[\s\S]*contentHeight > height/,
);
assert.match(
	qml,
	/menuCenterHeight\([\s\S]*statusBarNetworkQuickControlHeight/,
);
assert.doesNotMatch(qml, /\b0\.7\b/);
assert.match(
	detailFlickableBlock,
	/detailViewportHeight\([\s\S]*statusBarNetworkQuickControlHeight/,
);
assert.match(
	detailFlickableBlock,
	/Controls\.ScrollBar\.vertical:[\s\S]*AlwaysOn[\s\S]*AlwaysOff/,
);
assert.match(
	qml,
	/onExpandedNetworkSectionChanged:[\s\S]*detailFlickable\.contentY = 0/,
);
assert.match(qml, /onMenuOpenChanged:[\s\S]*detailFlickable\.contentY = 0/);

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
	menu.canForgetNetwork({
		known: true,
		connected: true,
		stateChanging: false,
	}),
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

assert.equal(menu.bluetoothSummary(false, false, 0), "Unavailable");
assert.equal(menu.bluetoothSummary(true, false, 0), "Off");
assert.equal(menu.bluetoothSummary(true, true, 0), "Enabled");
assert.equal(menu.bluetoothSummary(true, true, 2), "2 connected");
assert.equal(menu.bluetoothDeviceCategory({ connected: true }), "connected");
assert.equal(
	menu.bluetoothDeviceCategory({ paired: true }),
	"known-disconnected",
);
assert.equal(
	menu.bluetoothDeviceCategory({ trusted: true }),
	"known-disconnected",
);
assert.equal(menu.bluetoothDeviceCategory({}), "available");
assert.equal(menu.bluetoothDeviceState({ connected: true }), "Connected");
assert.equal(
	menu.bluetoothDeviceState({ paired: true, connected: false }),
	"Paired · Disconnected",
);
assert.equal(menu.bluetoothDeviceState({ pairing: true }), "Pairing…");
// device.state is an int from BluetoothDeviceState, so a string can never
// equal it. This file used to assert against "Connecting" and passed while
// production never once took that branch.
assert.equal(menu.bluetoothDeviceState({ state: "Connecting" }), "Available");
assert.equal(menu.bluetoothDeviceAction({ state: "Connecting" }), "pair");
assert.doesNotMatch(
	fs.readFileSync(`${__dirname}/ControlCenter.js`, "utf8").replace(/\/\/.*$/gm, ""),
	/state === "(Connecting|Disconnecting)"/,
	"comparing the state enum to a string is how that check went missing",
);
assert.equal(menu.bluetoothDeviceState({ blocked: true }), "Blocked");
assert.equal(menu.bluetoothDeviceAction({ connected: true }), "disconnect");
assert.equal(menu.bluetoothDeviceAction({ paired: true }), "connect");
assert.equal(menu.bluetoothDeviceAction({}), "pair");
assert.equal(menu.bluetoothDeviceAction({ pairing: true }), "busy");
assert.equal(menu.bluetoothDeviceAction({ blocked: true }), "busy");
assert.equal(
	menu.bluetoothBatteryText({ batteryAvailable: true, battery: 0.4 }),
	"40% battery",
);
assert.equal(
	menu.bluetoothBatteryText({ batteryAvailable: true, battery: 1 }),
	"100% battery",
);
assert.equal(
	menu.bluetoothBatteryText({ batteryAvailable: true, battery: 40 }),
	"40% battery",
);
assert.equal(
	menu.bluetoothBatteryText({ batteryAvailable: true, battery: 0 }),
	"0% battery",
);
for (const battery of [Number.NaN, Number.POSITIVE_INFINITY, -1, 101])
	assert.equal(
		menu.bluetoothBatteryText({ batteryAvailable: true, battery }),
		"",
	);
assert.equal(
	menu.bluetoothBatteryText({ batteryAvailable: false, battery: 0.4 }),
	"",
);
assert.equal(menu.bluetoothDevicesVisible(false, []), false);
assert.equal(menu.bluetoothDevicesVisible(true, []), false);
assert.equal(menu.bluetoothDevicesVisible(false, [{ name: "Mouse" }]), false);
assert.equal(menu.bluetoothDevicesVisible(true, [{ name: "Mouse" }]), true);
assert.equal(
	menu.bluetoothDevicesVisible(false, [{ name: "Headset", connected: true }]),
	false,
);
assert.equal(
	menu.bluetoothDevicesVisible(true, [{ name: "Headset", connected: true }]),
	false,
);
assert.equal(
	menu.bluetoothUniqueDevices([
		{ address: "a" },
		{ address: "a" },
		{ address: "b" },
	]).length,
	2,
);
assert.equal(
	menu.bluetoothDeviceAction({ connected: true, paired: true }),
	"disconnect",
);
assert.equal(menu.bluetoothDeviceAction({ trusted: true }), "connect");
assert.equal(
	menu.bluetoothDeviceAction({ paired: false, trusted: false }),
	"pair",
);
assert.equal(
	menu.bluetoothDeviceIcon({ icon: "computer", name: "Mouse" }),
	"󰊠",
);
assert.equal(menu.bluetoothDeviceIcon({ name: "Samsung phone" }), "󰏲");
assert.equal(menu.bluetoothDeviceIcon({ name: "TV display" }), "󰍹");
assert.equal(menu.microphoneSummary(false, false, -1), "Unavailable");
assert.equal(menu.microphoneSummary(true, true, 58), "Muted");
assert.equal(menu.microphoneSummary(true, false, 58.4), "58%");
assert.equal(menu.microphoneSummary(true, false, 140), "100%");

assert.equal(
	menu.outputAvailable(null, {
		authoritativePercent: 50,
		availability: "available",
	}),
	false,
);
assert.equal(
	menu.outputAvailable(
		{ audio: {} },
		{ authoritativePercent: null, availability: "available" },
	),
	false,
);
assert.equal(
	menu.outputAvailable(
		{ audio: {} },
		{ authoritativePercent: 50, availability: "unavailable" },
	),
	false,
);
assert.equal(
	menu.outputAvailable(
		{ audio: {} },
		{ authoritativePercent: 50, availability: "failed" },
	),
	true,
);
assert.equal(menu.outputSummary(false, false, 0), "Unavailable");
assert.equal(menu.outputSummary(true, true, 75), "Muted");
assert.equal(menu.outputSummary(true, false, 0), "0%");
assert.equal(menu.outputSummary(true, false, 58.6), "59%");
assert.equal(menu.outputSummary(true, false, 140), "100%");
assert.equal(menu.outputSummary(true, false, -20), "0%");
assert.equal(menu.audioOutputLabel(null, "Audio output"), "Audio output");
assert.equal(
	menu.audioOutputLabel({
		nickname: "  Speakers  ",
		description: "Fallback",
		name: "node",
	}),
	"Speakers",
);
assert.equal(
	menu.audioOutputLabel({
		nickname: " ",
		description: "  Desk audio ",
		name: "node",
	}),
	"Desk audio",
);
assert.equal(
	menu.audioOutputLabel({ nickname: "", description: "", name: " sink-1 " }),
	"sink-1",
);
assert.equal(
	menu.audioOutputLabel({ nickname: "", description: "", name: "" }),
	"Default output",
);
assert.equal(menu.volumeIconKind(false, false, 90), "unavailable");
assert.equal(menu.volumeIconKind(true, true, 90), "muted");
assert.equal(menu.volumeIconKind(true, false, 0), "muted");
assert.equal(menu.volumeIconKind(true, false, 1), "low");
assert.equal(menu.volumeIconKind(true, false, 33), "low");
assert.equal(menu.volumeIconKind(true, false, 34), "medium");
assert.equal(menu.volumeIconKind(true, false, 66), "medium");
assert.equal(menu.volumeIconKind(true, false, 67), "high");
assert.equal(menu.audioOutputLabel(null), "Default output");
assert.equal(
	menu.audioOutputLabel({
		nickname: "  Headphones ",
		description: "Fallback",
	}),
	"Headphones",
);
assert.equal(
	menu.audioOutputLabel({ nickname: "", description: " HDMI " }),
	"HDMI",
);
assert.equal(
	menu.audioOutputStatus({ audio: { muted: false } }, true),
	"Active output",
);
assert.equal(
	menu.audioOutputStatus({ audio: { muted: true } }, true),
	"Active · Muted",
);
assert.equal(
	menu.audioOutputStatus({ audio: { muted: false } }, false),
	"Available",
);
assert.equal(menu.audioNodePercent({ audio: { volume: 0.586 } }), 59);
assert.equal(menu.audioNodePercent({ audio: { volume: 4 } }), 100);
assert.equal(menu.audioNodePercent({ audio: { volume: -1 } }), 0);
assert.equal(menu.audioNodePercent({}), null);

const metadataStream = {
	properties: { "application.name": "  Firefox ", "media.name": " Video " },
	nickname: "Fallback",
	audio: { volume: 0.5, muted: false },
};
assert.equal(menu.playbackStreamLabel(metadataStream), "Firefox");
assert.equal(menu.playbackStreamDescription(metadataStream), "Video");
assert.equal(
	menu.playbackStreamDescription({
		properties: { "application.name": "Player", "media.name": " Player " },
	}),
	"Playback stream",
);
assert.equal(menu.playbackStreamLabel({ nickname: " Music " }), "Music");
assert.equal(
	menu.playbackStreamLabel({ description: " Browser audio " }),
	"Browser audio",
);
assert.equal(menu.playbackStreamLabel(null), "Audio stream");
assert.equal(
	menu.audioNodeIconKind({ audio: { volume: 0.2, muted: false } }),
	"low",
);
assert.equal(
	menu.audioNodeIconKind({ audio: { volume: 0.5, muted: false } }),
	"medium",
);
assert.equal(
	menu.audioNodeIconKind({ audio: { volume: 0.9, muted: false } }),
	"high",
);
assert.equal(
	menu.audioNodeIconKind({ audio: { volume: 0.9, muted: true } }),
	"muted",
);
assert.equal(menu.audioNodeIconKind({}), "unavailable");
// A node carrying an explicit null audio is unavailable too. It used to report
// "muted", because `node && node.audio && node.audio.volume` yields null there
// and Number(null) is 0, which reads as a finite zero-volume stream.
assert.equal(menu.audioNodeIconKind({ audio: null }), "unavailable");
assert.equal(menu.audioNodePercent({ audio: null }), null);
assert.equal(menu.audioNodePercent(null), null);
assert.equal(menu.audioNodePercent({ audio: { volume: 0 } }), 0);
assert.match(source, /audioNodeIconKind[\s\S]*return volumeIconKind/);
assert.doesNotMatch(source, /function outputIconKind|function outputSinkLabel/);

assert.match(qml, /toggleNetworkSection\("output"\)/);
assert.match(qml, /toggleMute\(false\)/);
assert.match(
	qml,
	/requestSinkVolume\(value, root\.quickControlRequestSequence\)/,
);
assert.match(qml, /actionAccessibleName:.*(?:Mute output|Unmute output)/);
assert.match(
	qml,
	/detailAccessibleName:.*(?:Show output volume|Hide output volume)/,
);
const mixerSources = `${qml}\n${mixerQml}`;
assert.doesNotMatch(mixerSources, /sink(?:\?\.)?\.audio\.volume\s*=/);
assert.doesNotMatch(
	mixerSources,
	/modelData(?:\?\.)?\.audio\.(?:volume|muted)\s*=/,
);
assert.match(qml, /AudioMixerSection \{/);
assert.doesNotMatch(
	qml,
	/text: "(?:Output volume|Output devices|Playback streams)"/,
);
assert.match(
	mixerQml,
	/id: outputDevicesList[\s\S]*spacing: root\.theme\.spacing\.space6/,
);
assert.match(
	mixerQml,
	/id: playbackStreamsList[\s\S]*spacing: root\.theme\.spacing\.space6/,
);
assert.match(
	mixerQml,
	/id: playbackSectionSpacer[\s\S]*height: root\.theme\.spacing\.space8/,
);
assert.match(
	mixerQml,
	/ScriptModel \{[\s\S]*id: audioOutputsModel[\s\S]*values: root\.audio\.audioOutputs \?\? \[\]/,
);
assert.match(
	mixerQml,
	/ScriptModel \{[\s\S]*id: playbackStreamsModel[\s\S]*values: root\.audio\.playbackStreams \?\? \[\]/,
);
assert.match(mixerQml, /model: audioOutputsModel/);
assert.match(mixerQml, /model: playbackStreamsModel/);
assert.doesNotMatch(
	mixerQml,
	/model: root\.audio\.(?:audioOutputs|playbackStreams)/,
);
assert.match(mixerQml, /selectAudioSink\(device\)/);
assert.match(mixerQml, /togglePlaybackStreamMute\(stream\)/);
assert.match(mixerQml, /requestPlaybackStreamVolume\(stream, value\)/);
assert.match(mixerQml, /No audio outputs/);
assert.match(mixerQml, /No active playback streams/);
assert.match(playbackRowQml, /objectName: "playbackStreamPercentLabel"/);
assert.match(playbackRowQml, /objectName: "playbackStreamVolumeIcon"/);
assert.match(playbackRowQml, /objectName: "audioPlaybackMuteAction"/);
assert.match(
	playbackRowQml,
	/id: playbackStreamSliderZone[\s\S]*Row \{[\s\S]*QuickControlSlider \{/,
);
assert.match(playbackRowQml, /color: root\.muted[\s\S]*Colors\.primary/);
assert.match(
	playbackRowQml,
	/Accessible\.name:\s*\[\s*root\.muted\s*\?\s*"Unmute"\s*:\s*"Mute"\s*,\s*" "\s*,\s*ControlCenterLogic\.playbackStreamLabel\s*\(\s*root\.stream\s*\)\s*\]\.join\(\s*""\s*\)/,
);
assert.doesNotMatch(
	playbackRowQml,
	/playbackStreamMuteLabel|text: root\.muted \? "Unmute" : "Mute"/,
);
for (const binding of [
	"volumeUnavailableIcon: root.icons.audio.volumeUnavailable",
	"volumeMutedIcon: root.icons.audio.volumeMuted",
	"volumeLowIcon: root.icons.audio.volumeLow",
	"volumeMediumIcon: root.icons.audio.volumeMedium",
	"volumeHighIcon: root.icons.audio.volumeHigh",
])
	assert.ok(
		mixerQml.includes(binding),
		`missing playback volume icon binding: ${binding}`,
	);

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
assert.equal(menu.audioSourceLabel(null), "Microphone");
assert.equal(menu.audioSourceLabel(null, "  Input device  "), "Input device");
assert.equal(
	menu.audioSourceLabel({
		nickname: " ",
		description: " ",
		name: " source-1 ",
	}),
	"source-1",
);
assert.equal(
	menu.audioSourceLabel({ nickname: " ", description: " ", name: " " }),
	"Microphone",
);
const activeSource = { audio: { muted: false } };
assert.equal(
	menu.audioSourceStatus(activeSource, activeSource),
	"Active input",
);
const mutedActiveSource = { audio: { muted: true } };
assert.equal(
	menu.audioSourceStatus(mutedActiveSource, mutedActiveSource),
	"Active · Muted",
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
	"ControlCenter: identity, uptime, network state, and control actions passed",
);
