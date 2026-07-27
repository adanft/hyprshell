const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(`${__dirname}/NetworkMenu.js`, "utf8");
const qml = fs.readFileSync(`${__dirname}/NetworkMenu.qml`, "utf8");
const playbackRowQml = fs.readFileSync(
	`${__dirname}/AudioPlaybackStreamRow.qml`,
	"utf8",
);
const mixerQml = fs.readFileSync(`${__dirname}/AudioMixerSection.qml`, "utf8");
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
for (const id of [
	"userCard",
	"quickControlsRow",
	"networkControlsRow",
	"audioControlsRow",
	"bluetoothCard",
])
	assert.ok(fixedShellBlock.includes(`id: ${id}`), `${id} must be fixed`);
for (const id of ["outputCard", "microphoneCard", "lanCard", "wifiCard"])
	assert.ok(!fixedShellBlock.includes(`id: ${id}`), `${id} must not be fixed`);
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
	/onExpandedNetworkSectionChanged: detailFlickable\.contentY = 0/,
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

assert.equal(menu.bluetoothSummary(false, false, 0), "Unavailable");
assert.equal(menu.bluetoothSummary(true, false, 0), "Off");
assert.equal(menu.bluetoothSummary(true, true, 0), "Enabled");
assert.equal(menu.bluetoothSummary(true, true, 2), "2 connected");
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
	menu.audioOutputLabel({ nickname: "  Headphones ", description: "Fallback" }),
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
	/id: outputDevicesList[\s\S]*spacing: root\.theme\.spacing\.space8/,
);
assert.match(
	mixerQml,
	/id: playbackStreamsList[\s\S]*spacing: root\.theme\.spacing\.space8/,
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
assert.match(playbackRowQml, /color: root\.muted[\s\S]*root\.colors\.primary/);
assert.match(
	playbackRowQml,
	/Accessible\.name: `\$\{root\.muted \? "Unmute" : "Mute"\}/,
);
assert.doesNotMatch(
	playbackRowQml,
	/playbackStreamMuteLabel|text: root\.muted \? "Unmute" : "Mute"/,
);
for (const binding of [
	"volumeUnavailableIcon: root.icons.volumeUnavailable",
	"volumeMutedIcon: root.icons.volumeMuted",
	"volumeLowIcon: root.icons.volumeLow",
	"volumeMediumIcon: root.icons.volumeMedium",
	"volumeHighIcon: root.icons.volumeHigh",
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
	"NetworkMenu: identity, uptime, network state, and control actions passed",
);
