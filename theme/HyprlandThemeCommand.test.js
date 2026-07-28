const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(`${__dirname}/HyprlandThemeCommand.js`, "utf8");
const command = {};
vm.createContext(command);
vm.runInContext(source, command);

assert.equal(command.normalizedHex("#E6B450"), "e6b450");
assert.equal(command.normalizedHex("#0d1017"), "0d1017");

for (const invalid of [
	"e6b450",
	"#fff",
	"#11223344",
	"#gggggg",
	"#12345;reload",
	"#123456\nkeyword misc:disable_hyprland_logo true",
	"",
	null,
	undefined,
]) {
	assert.throws(
		() => command.normalizedHex(invalid),
		/invalid Hyprland color/i,
	);
}

const theme = {
	focus: "#E6B450",
	borderStrong: "#5a6673",
	background: "#0d1017",
};
const expectedExpression =
	'hl.config({ general = { col = { active_border = "rgb(e6b450)", inactive_border = "rgb(5a6673)" } }, misc = { background_color = "rgb(0d1017)" } })';

assert.equal(command.configExpression(theme), expectedExpression);
assert.deepEqual(JSON.parse(JSON.stringify(command.processArguments(theme))), [
	"hyprctl",
	"eval",
	expectedExpression,
]);
assert.throws(
	() => command.configExpression({ ...theme, focus: "red" }),
	/invalid Hyprland color/i,
);

const stockThemes = fs.readFileSync(`${__dirname}/StockThemes.qml`, "utf8");
assert.equal(stockThemes.includes("apply_hyprland_theme.sh"), false);
assert.match(stockThemes, /process\.exec\(processArgs\)/);
assert.match(stockThemes, /ThemeSyncState\.requestHyprland/);
assert.match(stockThemes, /ThemeSyncState\.finishHyprland/);

console.log(
	"HyprlandThemeCommand: validation and direct hyprctl arguments passed",
);
