const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(`${__dirname}/NetworkMenuWorkflow.js`, "utf8");
const workflow = {};
vm.createContext(workflow);
vm.runInContext(source, workflow);

const clean = (value) => JSON.parse(JSON.stringify(value));
const state = (overrides) =>
	Object.assign(workflow.initialState(), overrides || {});
const run = (current, event) => workflow.transition(current, event);
const effectTypes = (result) =>
	Array.from(result.effects, (effect) => effect.type);

assert.deepEqual(clean(workflow.initialState()), {
	pendingNetwork: null,
	suppressedPasswordNetwork: null,
	scannerDevice: null,
	scannerOwnedDevice: null,
	wifiActivationPending: false,
	wifiActivationRequested: false,
	wifiActivationGeneration: 0,
	connectionError: "",
	expandedNetworkSection: "",
	detailsSubscribed: false,
});
{
	const original = state({ connectionError: "kept" });
	const event = { type: "unknown", nested: { value: 1 } };
	const result = run(original, event);
	assert.equal(result.state, original);
	assert.deepEqual(clean(result.effects), []);
	assert.equal(event.nested.value, 1);
	assert.equal(run(original, null).state, original);
	assert.equal(run(original, {}).state, original);
}
{
	const result = run(state(), { type: "beginWifiActivation" });
	assert.equal(result.state.wifiActivationGeneration, 1);
	assert.equal(result.state.wifiActivationRequested, true);
	assert.equal(result.state.wifiActivationPending, true);
	assert.deepEqual(clean(result.effects), [
		{ type: "startActivationSettle", generation: 1 },
	]);
}
for (const test of [
	[false, ["startActivationSettle", "setWifiEnabled"], true],
	[
		true,
		[
			"stopScannerDelay",
			"stopActivationSettle",
			"setScannerEnabled",
			"setWifiEnabled",
		],
		false,
	],
]) {
	const device = {};
	const result = run(
		state({ scannerOwnedDevice: device, scannerDevice: device }),
		{ type: "toggleWifi", wifiEnabled: test[0] },
	);
	assert.deepEqual(effectTypes(result), test[1]);
	assert.equal(result.state.wifiActivationPending, test[2]);
}
{
	const current = state({
		wifiActivationGeneration: 4,
		wifiActivationPending: true,
		wifiActivationRequested: true,
	});
	assert.equal(
		run(current, { type: "activationSettleElapsed", generation: 3 }).state,
		current,
	);
	const settled = run(current, {
		type: "activationSettleElapsed",
		generation: 4,
	});
	assert.equal(settled.state.wifiActivationPending, false);
	assert.equal(settled.state.wifiActivationRequested, false);
}
const eligible = {
	menuOpen: true,
	expandedNetworkSection: "wifi",
	wifiEnabled: true,
	wifiHardwareEnabled: true,
};
for (const key of Object.keys(eligible)) {
	const context = Object.assign({}, eligible, {
		type: "syncScanner",
		wifiDevice: {},
	});
	context[key] = key === "expandedNetworkSection" ? "ethernet" : false;
	assert.deepEqual(effectTypes(run(state(), context)), [
		"stopScannerDelay",
		"stopActivationSettle",
	]);
}
{
	const device = { scannerEnabled: false };
	const result = run(
		state(),
		Object.assign({ type: "syncScanner", wifiDevice: device }, eligible),
	);
	assert.equal(result.state.scannerOwnedDevice, device);
	assert.deepEqual(clean(result.effects), [
		{ type: "stopScannerDelay" },
		{ type: "setScannerEnabled", device, enabled: true, claimOwnership: true },
	]);
	const forced = run(
		result.state,
		Object.assign(
			{ type: "syncScanner", wifiDevice: device, forceRestart: true },
			eligible,
		),
	);
	assert.deepEqual(effectTypes(forced), [
		"stopScannerDelay",
		"setScannerEnabled",
		"startScannerDelay",
	]);
}
{
	const oldDevice = {},
		replacement = {};
	const result = run(
		state({ scannerDevice: oldDevice, scannerOwnedDevice: oldDevice }),
		Object.assign({ type: "syncScanner", wifiDevice: replacement }, eligible),
	);
	assert.deepEqual(effectTypes(result), [
		"stopScannerDelay",
		"setScannerEnabled",
		"setScannerEnabled",
	]);
	assert.equal(result.effects[0 + 1].device, oldDevice);
	assert.equal(result.state.scannerOwnedDevice, replacement);
}
{
	const device = {};
	const current = state({
		scannerDevice: device,
		wifiActivationGeneration: 2,
		wifiActivationPending: true,
	});
	const staleGeneration = run(
		current,
		Object.assign(
			{
				type: "scannerDelayElapsed",
				scheduledDevice: device,
				scheduledGeneration: 1,
				wifiDevice: device,
			},
			eligible,
		),
	);
	const staleIdentity = run(
		current,
		Object.assign(
			{
				type: "scannerDelayElapsed",
				scheduledDevice: {},
				scheduledGeneration: 2,
				wifiDevice: device,
			},
			eligible,
		),
	);
	assert.equal(staleGeneration.state, current);
	assert.equal(staleIdentity.state, current);
	const accepted = run(
		current,
		Object.assign(
			{
				type: "scannerDelayElapsed",
				scheduledDevice: device,
				scheduledGeneration: 2,
				wifiDevice: device,
			},
			eligible,
		),
	);
	assert.deepEqual(effectTypes(accepted), [
		"setScannerEnabled",
		"startActivationSettle",
	]);
}

{
	const current = state();
	let result = run(
		current,
		Object.assign({ type: "menuOpenChanged", wifiDevice: null }, eligible),
	);
	assert.deepEqual(effectTypes(result), [
		"stopScannerDelay",
		"stopActivationSettle",
		"enableNetworkDetails",
	]);
	assert.equal(result.state.detailsSubscribed, true);
	result = run(
		result.state,
		Object.assign(
			{ type: "menuOpenChanged", menuOpen: true, wifiDevice: null },
			eligible,
		),
	);
	assert.deepEqual(effectTypes(result), [
		"stopScannerDelay",
		"stopActivationSettle",
	]);
	result = run(result.state, { type: "menuOpenChanged", menuOpen: false });
	assert.deepEqual(effectTypes(result), [
		"stopScannerDelay",
		"stopActivationSettle",
		"disableNetworkDetails",
	]);
	const destroyed = run(result.state, { type: "destroy" });
	assert.deepEqual(effectTypes(destroyed), [
		"stopScannerDelay",
		"stopActivationSettle",
	]);
	assert.deepEqual(effectTypes(run(destroyed.state, { type: "destroy" })), []);
}

const openSecurityValue = 0;
const connected = { connected: true },
	known = { known: true },
	open = { security: 0 },
	secured = { name: "same", security: 2 };
for (const test of [
	[connected, "disconnectNetwork"],
	[known, "connectNetwork"],
	[open, "connectNetwork"],
	[secured, null],
	[null, null],
]) {
	const result = run(
		state({ connectionError: "old", suppressedPasswordNetwork: {} }),
		{ type: "connectRequested", network: test[0], openSecurityValue },
	);
	assert.deepEqual(effectTypes(result), test[1] ? [test[1]] : []);
	assert.equal(
		result.state.pendingNetwork,
		test[1] || !test[0] ? null : test[0],
	);
	assert.equal(result.state.connectionError, "");
	assert.equal(result.state.suppressedPasswordNetwork, null);
}

for (const [target, password, expected] of [
	[secured, "secret", true],
	[secured, 123, true],
	[secured, "", false],
	[secured, null, false],
	[null, "secret", false],
	[{ stateChanging: true }, "secret", false],
])
	assert.equal(workflow.canSubmitPassword(target, password), expected);
{
	const result = run(
		state({ pendingNetwork: secured, connectionError: "old" }),
		{ type: "submitPassword", password: "secret" },
	);
	assert.deepEqual(clean(result.effects), [
		{ type: "connectNetworkWithPsk", network: secured, password: "secret" },
	]);
	assert.equal(result.state.connectionError, "");
}
{
	const changing = { name: "same", stateChanging: true };
	const sameName = { name: "same" };
	let result = run(state({ pendingNetwork: changing, connectionError: "x" }), {
		type: "cancelPassword",
	});
	assert.equal(result.state.suppressedPasswordNetwork, changing);
	assert.equal(result.state.pendingNetwork, null);
	result = run(result.state, {
		type: "wifiConnectionFailed",
		network: sameName,
		reason: 1,
		noSecretsValue: 7,
		errorText: "failed",
	});
	assert.equal(result.state.suppressedPasswordNetwork, changing);
	assert.equal(result.state.connectionError, "failed");
	result = run(result.state, {
		type: "wifiConnectionFailed",
		network: changing,
		reason: 1,
		noSecretsValue: 7,
		errorText: "ignored",
	});
	assert.equal(result.state.suppressedPasswordNetwork, null);
	assert.equal(result.state.connectionError, "failed");
}
{
	let result = run(state(), {
		type: "wifiConnectionFailed",
		network: secured,
		reason: 7,
		noSecretsValue: 7,
		errorText: "need password",
	});
	assert.equal(result.state.pendingNetwork, secured);
	assert.equal(result.state.connectionError, "need password");
	const currentPending = state({ pendingNetwork: secured });
	const ignored = run(currentPending, {
		type: "wifiConnectionFailed",
		network: secured,
	});
	assert.notEqual(ignored.state, currentPending);
	assert.equal(ignored.state.pendingNetwork, secured);
	assert.deepEqual(effectTypes(ignored), []);
	const partialState = state(),
		partial = run(partialState, { type: "wifiConnectionFailed" });
	assert.equal(partial.state.pendingNetwork, null);
	assert.notEqual(partial.state, partialState);
	result = run(state({ pendingNetwork: secured }), {
		type: "pendingConnectionFailed",
		errorText: "bad",
	});
	assert.equal(result.state.connectionError, "bad");
	result = run(state({ suppressedPasswordNetwork: secured }), {
		type: "wifiConnectedChanged",
		network: secured,
	});
	assert.equal(result.state.suppressedPasswordNetwork, null);
}
{
	const forgettable = { known: true, connected: false, stateChanging: false };
	const result = run(
		state({ pendingNetwork: forgettable, connectionError: "x" }),
		{ type: "forgetRequested", network: forgettable },
	);
	assert.deepEqual(effectTypes(result), ["forgetNetwork"]);
	assert.equal(result.state.pendingNetwork, null);
	assert.deepEqual(
		effectTypes(
			run(state(), {
				type: "forgetRequested",
				network: { known: true, connected: true },
			}),
		),
		[],
	);
}
