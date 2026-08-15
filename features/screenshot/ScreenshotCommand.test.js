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

// The hint is how the shell learns which file this capture wrote, and it is the
// only thing standing between a screenshot notification and two dead buttons.
// The key is spelled in one other place, so it is read from there rather than
// typed again: two copies of a string nobody checks is how they drift.
const hintKey = require("../../services/capabilities/NotificationFileActions.js").HINT_KEY;
assert.ok(
	script.includes(`-h "variant:${hintKey}:['$url']"`),
	`the capture must name its file in the ${hintKey} hint`,
);
// The signature is `as`, so the value is a list even when it holds one entry,
// and each entry is a URI rather than a path. A scalar string here is what
// ukui-notification-daemon sends and what Plasma refuses to read.
assert.match(script, /printf 'file:\/\/%s'/);
// Percent before quote: the other order would escape the replacement's own
// percent and turn every quote into %2527.
assert.ok(
	script.indexOf("s/%/%25/g") < script.indexOf("s/'/%27/g"),
	"percent must be encoded before the quote",
);
// Sent, not clicked: an action flag would make the button this script's own and
// hold the process open waiting for it, which is what the hint exists to avoid.
// Comments are stripped first — the prose above says "notify-send -A" to explain
// why it is absent, and matching that would fail the run for saying so.
const commands = script
	.split("\n")
	.filter(line => !/^\s*#/.test(line))
	.join("\n");
assert.equal(/notify-send[^\n]*(-A|--action)/.test(commands), false);
// After the file exists and after the clipboard copy: a hint pointing at a path
// nothing has written yet would open an empty viewer.
assert.ok(
	script.indexOf("wl-copy") < script.indexOf(hintKey),
	"the hint must be sent after the file is written",
);

console.log("ScreenshotCommand: dynamic values remain positional and names are exclusive");
