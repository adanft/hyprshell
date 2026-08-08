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
assert.equal(first[7], "0.2");

console.log("ScreenshotCommand: dynamic values remain positional and names are exclusive");
