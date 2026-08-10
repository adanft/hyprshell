const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const context = {};
const helperSource = fs.readFileSync(`${__dirname}/ThemeSyncState.js`, "utf8");
assert.doesNotMatch(helperSource, /\.\.\.|\.\.\./);
vm.createContext(context);
vm.runInContext(helperSource, context);

assert.equal(context.shouldSyncExternal(false, true), false);
assert.equal(context.shouldSyncExternal(true, true), true);
const theme = { focus: "#111111" };
const otherTheme = { focus: "#222222" };
const latestTheme = { focus: "#333333" };
const state = context.createHyprlandState();
assert.equal(context.requestHyprland(state, theme, false).action, "start");
assert.equal(context.requestHyprland(state, theme, true).action, "queued");
let result = context.finishHyprland(
	state,
	context.effectiveSignature(theme),
	true,
);
assert.equal(result.action, "start");
assert.equal(result.request.force, true);
result = context.finishHyprland(state, context.effectiveSignature(theme), true);
assert.equal(result.action, "idle");

const forcedFailure = context.createHyprlandState();
assert.equal(
	context.requestHyprland(forcedFailure, theme, false).action,
	"start",
);
assert.equal(
	context.requestHyprland(forcedFailure, theme, true).action,
	"queued",
);
result = context.finishHyprland(
	forcedFailure,
	context.effectiveSignature(theme),
	false,
);
assert.equal(result.action, "start");
assert.equal(
	context.finishHyprland(
		forcedFailure,
		context.effectiveSignature(theme),
		true,
	).action,
	"start",
);
result = context.finishHyprland(
	forcedFailure,
	context.effectiveSignature(theme),
	true,
);
assert.equal(result.action, "idle");
assert.equal(context.requestHyprland(state, theme, false).action, "skip");

const latest = context.createHyprlandState();
assert.equal(context.requestHyprland(latest, theme, false).action, "start");
assert.equal(
	context.requestHyprland(latest, otherTheme, false).action,
	"queued",
);
assert.equal(
	context.requestHyprland(latest, latestTheme, false).action,
	"queued",
);
result = context.finishHyprland(
	latest,
	context.effectiveSignature(theme),
	true,
);
assert.equal(result.action, "start");
assert.equal(result.request.signature, context.effectiveSignature(latestTheme));

for (const failure of [false, false]) {
	const retry = failure === false && context.createHyprlandState();
	if (!retry) continue;
	assert.equal(context.requestHyprland(retry, theme, false).action, "start");
	result = context.finishHyprland(
		retry,
		context.effectiveSignature(theme),
		false,
	);
	assert.equal(result.action, "start");
	result = context.finishHyprland(
		retry,
		context.effectiveSignature(theme),
		false,
	);
	assert.equal(result.action, "idle");
	assert.equal(context.requestHyprland(retry, theme, false).action, "start");
	break;
}

const createFailure = context.createHyprlandState();
assert.equal(
	context.requestHyprland(createFailure, theme, false).action,
	"start",
);
result = context.finishHyprland(
	createFailure,
	context.effectiveSignature(theme),
	false,
);
assert.equal(result.action, "start");
assert.equal(
	context.finishHyprland(
		createFailure,
		context.effectiveSignature(theme),
		true,
	).action,
	"idle",
);
assert.equal(context.ghosttyNeedsReload(false, false), false);
assert.equal(context.ghosttyNeedsReload(false, true), true);
assert.equal(context.ghosttyNeedsReload(true, false), true);
const ghostty = context.createGhosttyState();
assert.equal(context.requestGhostty(ghostty, false).action, "start");
assert.equal(context.requestGhostty(ghostty, true).action, "queued");
assert.equal(context.finishGhostty(ghostty, true).action, "start");
assert.equal(context.finishGhostty(ghostty, true).action, "idle");
assert.equal(context.requestGhostty(ghostty, false).action, "start");
assert.equal(context.finishGhostty(ghostty, false).action, "start");
assert.equal(context.finishGhostty(ghostty, false).action, "idle");
assert.equal(context.requestGhostty(ghostty, true).action, "start");
assert.equal(context.finishGhostty(ghostty, false).action, "start");
assert.equal(context.finishGhostty(ghostty, false).action, "idle");
// The hyprland state machine now drives one reload rather than a colour command,
// and it moved with it: StockThemes no longer talks to the compositor at all,
// it writes theme.conf and HyprTheme tells Hyprland to read it.
const hyprSource = fs.readFileSync(`${__dirname}/HyprTheme.qml`, "utf8");
assert.match(hyprSource, /try \{\s*process = reloadProcessComponent\.createObject/);
assert.match(hyprSource, /function startReload\(request\)/);
const ghosttySource = fs.readFileSync(`${__dirname}/GhosttyTheme.qml`, "utf8");
assert.match(ghosttySource, /function startReload\(force\)/);
console.log(
	"ThemeSyncState: readiness, coalescing, retries, latest request, and force contracts passed",
);
