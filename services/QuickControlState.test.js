const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(`${__dirname}/QuickControlState.js`, "utf8");
const state = {};
vm.createContext(state);
vm.runInContext(source, state);

assert.equal(state.clampPercent(-1), 0);
assert.equal(state.clampPercent(42.6), 43);
assert.equal(state.clampPercent(101), 100);
assert.equal(state.clampPercent(Number.NaN), null);

const device = "/sys/class/backlight/intel_backlight";
assert.equal(state.validBrightnessDevicePath(device), true);
for (const candidate of [
    "", null, undefined, ` ${device}`, `${device} `,
    "/sys/class/backlight/../intel_backlight",
    "/sys/class/backlight/intel/backlight",
    "file:///sys/class/backlight/intel_backlight",
    `/sys/class/backlight/${"a".repeat(129)}`,
    `${device}\n`
])
    assert.equal(state.validBrightnessDevicePath(candidate), false, String(candidate));

assert.equal(state.parseUnsignedInteger("0\n", true), 0);
assert.equal(state.parseUnsignedInteger("15\n", false), 15);
assert.equal(state.parseUnsignedInteger(" 1 ", true), 1);
for (const value of ["", "01", "-1", "1.5", "Infinity", "9007199254740992"])
    assert.equal(state.parseUnsignedInteger(value, true), null, value);
assert.equal(state.parseUnsignedInteger("0", false), null);

assert.deepEqual(JSON.parse(JSON.stringify(state.normalizedReadback("40\n", "160\n"))), {
    rawCurrent: 40,
    rawMaximum: 160,
    percent: 25
});
assert.equal(state.normalizedReadback("161", "160"), null);
assert.equal(state.normalizedReadback("0", "0"), null);
assert.equal(state.rawForPercent(33, 10), 3);
assert.equal(state.rawForPercent(100, 10), 10);
assert.equal(state.rawForPercent(Number.NaN, 10), null);
assert.deepEqual(JSON.parse(JSON.stringify(state.normalizedVolumeRequest(42.6, true))), {
    percent: 43,
    volume: 0.43,
    unmute: true
});
assert.deepEqual(JSON.parse(JSON.stringify(state.normalizedVolumeRequest(0, true))), {
    percent: 0,
    volume: 0,
    unmute: false
});
assert.equal(state.normalizedVolumeRequest(50, false), null);
assert.equal(state.normalizedVolumeRequest(Number.NaN, true), null);

let capability = state.unavailableCapability("Unavailable");
assert.equal(capability.authoritativePercent, null, "unavailable must not fabricate 0%");
assert.equal(state.syncConfirmed(capability, 64).effect, null, "native sync never writes");
capability = state.syncConfirmed(capability, 64).state;
const interaction = state.beginInteraction(capability, 72);
assert.equal(interaction.state.availability, "interacting");
const request = state.completeInteraction(interaction.state, 1);
assert.deepEqual(JSON.parse(JSON.stringify(request.effect)), { type: "request", percent: 72, requestId: 1 });
assert.equal(request.state.availability, "pending_confirmation");

const stale = state.confirmRequest(request.state, 0, 70);
assert.equal(stale.accepted, false);
assert.equal(stale.state.activeRequestId, 1);
const confirmed = state.confirmRequest(request.state, 1, 70);
assert.equal(confirmed.accepted, true);
assert.equal(confirmed.state.authoritativePercent, 70);

for (const reason of ["write_failed", "reconciliation_timeout", "readback_mismatch", "reload_failed"]) {
    const failed = state.failRequest(request.state, 1, reason, "Adjustment failed");
    assert.equal(failed.availability, "failed");
    assert.equal(failed.authoritativePercent, 64);
    assert.equal(failed.effect, undefined);
}
const noKnownValue = state.failRequest(state.completeInteraction(state.beginInteraction(state.unavailableCapability(""), 20).state, 2).state, 2, "write_failed", "Adjustment failed");
assert.equal(noKnownValue.availability, "unavailable");
assert.equal(noKnownValue.authoritativePercent, null);

console.log("QuickControlState: validation, normalization, gesture, stale, and failure contracts passed");
