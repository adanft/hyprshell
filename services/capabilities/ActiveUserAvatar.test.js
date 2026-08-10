const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(`${__dirname}/ActiveUserAvatar.js`, "utf8");
const avatar = {};
vm.createContext(avatar);
vm.runInContext(source, avatar);

const userPath = "/org/freedesktop/Accounts/User1000";

assert.equal(
	avatar.parseUserObjectPath(JSON.stringify({ type: "o", data: [userPath] })),
	userPath,
);
assert.equal(
	avatar.parseUserObjectPath(JSON.stringify({ type: "o", data: userPath })),
	userPath,
);
assert.equal(avatar.parseUserObjectPath("not json"), "");
assert.equal(
	avatar.parseUserObjectPath(JSON.stringify({ type: "s", data: [userPath] })),
	"",
);
assert.equal(
	avatar.parseUserObjectPath(
		JSON.stringify({ type: "o", data: ["/tmp/User1000"] }),
	),
	"",
);
assert.equal(
	avatar.parseUserObjectPath(
		JSON.stringify({
			type: "o",
			data: ["/org/freedesktop/Accounts/Userabc"],
		}),
	),
	"",
);

assert.equal(
	avatar.parseIconFile(
		JSON.stringify({
			type: "s",
			data: ["/var/lib/AccountsService/icons/example avatar.png"],
		}),
	),
	"file:///var/lib/AccountsService/icons/example%20avatar.png",
);
assert.equal(
	avatar.parseIconFile(
		JSON.stringify({
			type: "s",
			data: "/var/lib/AccountsService/icons/example.png",
		}),
	),
	"file:///var/lib/AccountsService/icons/example.png",
);

for (const candidate of [
	"",
	" relative.png",
	"relative.png",
	"file:///tmp/avatar.png",
	"https://example.invalid/avatar.png",
	"/tmp/../etc/passwd",
	"/tmp/avatar\n.png",
	"/tmp/avatar\0.png",
	`/${"a".repeat(4096)}`,
]) {
	assert.equal(
		avatar.safeLocalFileUrl(candidate),
		"",
		`candidate should be rejected: ${JSON.stringify(candidate)}`,
	);
}

assert.equal(avatar.parseIconFile("not json"), "");
assert.equal(
	avatar.parseIconFile(
		JSON.stringify({ type: "o", data: ["/tmp/avatar.png"] }),
	),
	"",
);
assert.equal(avatar.parseIconFile(JSON.stringify({ type: "s", data: [] })), "");

console.log(
	"ActiveUserAvatar: typed response and local-path validation passed",
);
