const assert = require("node:assert/strict");
const command = require("./ScreenshotCommand.js");

for (const monitor of [
	"DP-1 desk",
	`quote'\"`,
	"$(touch /tmp/nope)",
	"`touch /tmp/nope`",
	"line one\nline two",
]) {
	const args = command.processArguments("monitor", true, monitor, 3);
	assert.deepEqual(args.slice(0, 2), ["sh", "-c"]);
	assert.equal(args[6], monitor);
	assert.equal(args[2].includes(monitor), false);
	assert.equal(args[5], "1");
}

const first = command.processArguments("all", false, "", 0);
assert.match(first[2], /mktemp --/);
assert.match(first[2], /%3N/);
assert.equal(first[5], "0");

// The delay is the user's timer alone. It used to carry an extra 0.2s of
// padding for the overlay teardown, which the script now waits for directly.
assert.equal(first[7], "0");
assert.equal(command.processArguments("all", false, "", 3)[7], "3");
assert.equal(command.processArguments("all", false, "", -5)[7], "0");
assert.equal(command.processArguments("all", false, "", "nope")[7], "0");

// Waiting for the overlay's own layer surface to disappear is what keeps the
// tool out of its own screenshot, so the wait has to be there, has to watch the
// namespace the tool actually declares, and has to be bounded.
const script = first[2];
const fs = require("node:fs");
const path = require("node:path");
const screenshotTool = fs.readFileSync(
	path.join(__dirname, "ScreenshotTool.qml"),
	"utf8",
);
const declaredNamespace =
	/WlrLayershell\.namespace: "([^"]+)"/.exec(screenshotTool)[1];
assert.ok(
	script.includes(`.namespace == "${declaredNamespace}"`),
	`the wait must watch ${declaredNamespace}, the namespace the tool declares`,
);
assert.match(script, /while \[ "\$waited" -lt \d+ \]/, "the wait must be bounded");
assert.match(script, /\|\| break/, "the wait must exit once the layer is gone");
// The wait has to happen before the capture, or it protects nothing. Anchored
// on the mode dispatch rather than on "grim", which also appears in prose above
// it and would make this pass for the wrong reason.
assert.ok(
	script.indexOf("waited=0") < script.indexOf('case "$mode" in'),
	"the wait must run before the capture",
);

console.log("ScreenshotCommand: dynamic values remain positional and names are exclusive");
