const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(`${__dirname}/HyprThemeTransform.js`, "utf8");
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
	assert.throws(() => command.normalizedHex(invalid), /invalid Hyprland color/i);
}

// hyprlang reads a line at a time, so a newline in a value does not corrupt the
// entry — it writes a second one that the file never asked for.
assert.equal(command.normalizedText("IosevkaTerm NF", "font"), "IosevkaTerm NF");
for (const invalid of [
	"",
	null,
	undefined,
	"Mono\nexec-once = anything",
	"Mono\rmisc:disable_hyprland_logo = false",
]) {
	assert.throws(
		() => command.normalizedText(invalid, "font"),
		/invalid Hyprland font/i,
	);
}

// A missing wallpaper is not an error. It is what a shell looks like before one
// has been picked, and refusing the whole file over it would leave hyprlock and
// the compositor with no colours at all. A newline is still an error.
assert.equal(command.normalizedText("", "wallpaper", true), "");
assert.equal(command.normalizedText(undefined, "wallpaper", true), "");
assert.throws(
	() => command.normalizedText("a\nb", "wallpaper", true),
	/invalid Hyprland wallpaper/i,
);

const theme = {
	primary: "#CBA6F7",
	secondary: "#fab387",
	error: "#f38ba8",
	outline: "#45475a",
	surface: "#1e1e2e",
	shadow: "#11111b",
	on_surface: "#cdd6f4",
};
const appearance = {
	wallpaper: "/home/someone/Wallpapers/one.png",
	font: "IosevkaTerm NF",
};

const conf = command.renderThemeConf(theme, appearance);

assert.equal(
	conf,
	`# qsrice managed theme
# Written by the shell. Edits are lost on the next theme change.
# hyprlock sources this; hyprland.lua reads it back.

$primary = rgb(cba6f7)
$primaryAlpha = cba6f7
$secondary = rgb(fab387)
$error = rgb(f38ba8)
$outline = rgb(45475a)
$surface = rgb(1e1e2e)
$surfaceVeil = rgba(1e1e2e80)
$shadow = rgb(11111b)
$on_surface = rgb(cdd6f4)
$on_surfaceAlpha = cdd6f4

$wallpaper = /home/someone/Wallpapers/one.png
$font = IosevkaTerm NF
`,
);

// The declared names are the contract. hyprlock.conf reads them by name and so
// does hyprland.lua, and neither would say anything if one disappeared: the
// border would just fall back and the label would just go unpainted.
assert.deepEqual(
	[...conf.matchAll(/^\$(\w+) =/gm)].map(([, name]) => name),
	[
		"primary",
		"primaryAlpha",
		"secondary",
		"error",
		"outline",
		"surface",
		"surfaceVeil",
		"shadow",
		"on_surface",
		"on_surfaceAlpha",
		"wallpaper",
		"font",
	],
);

// Every colour goes through the same validator, so a malformed palette cannot
// reach either program.
assert.throws(
	() => command.renderThemeConf({ primary: "#cba6f7" }, appearance),
	/invalid Hyprland color/i,
);
assert.throws(
	() => command.renderThemeConf(theme, { wallpaper: "/x.png", font: "" }),
	/invalid Hyprland font/i,
);

// The whole palette still reaches both programs when no wallpaper is set.
const unpapered = command.renderThemeConf(theme, { font: "IosevkaTerm NF" });
assert.match(unpapered, /^\$wallpaper = $/m);
assert.match(unpapered, /^\$primary = rgb\(cba6f7\)$/m);

// A longer name that starts with a shorter one is safe: hyprlang sorts its
// variables by length before substituting, so $on_surfaceAlpha is replaced
// before $on_surface can match its prefix. Declaring both is therefore fine,
// and this records why rather than leaving it to be rediscovered.
assert.match(conf, /^\$on_surface = /m);
assert.match(conf, /^\$on_surfaceAlpha = /m);

// One live path. A second command that set colours directly would make the file
// and the command each a source of truth, and only one of them would be right.
assert.deepEqual(JSON.parse(JSON.stringify(command.reloadArguments())), [
	"hyprctl",
	"reload",
]);

// A reload re-applies monitors, binds and animations, so it is worth spending
// only on something Hyprland actually reads. It reads the colours; the wallpaper
// and the font belong to the lock screen, which re-reads on its own next launch.
const other = command.renderThemeConf(theme, {
	wallpaper: "/home/someone/Wallpapers/two.png",
	font: "Some Other Face",
});
assert.equal(command.needsReload(conf, other), false);
assert.equal(command.needsReload(conf, conf), false);

const repainted = command.renderThemeConf(
	{ ...theme, primary: "#ff0000" },
	appearance,
);
assert.equal(command.needsReload(conf, repainted), true);
// Including the translucent fill, which is a colour spelled differently.
const veiled = command.renderThemeConf({ ...theme, surface: "#000000" }, appearance);
assert.equal(command.needsReload(conf, veiled), true);
// And an empty file, which is what a first run reads.
assert.equal(command.needsReload("", conf), true);
assert.equal(typeof command.configExpression, "undefined");
assert.equal(typeof command.processArguments, "undefined");

const stockThemes = fs.readFileSync(`${__dirname}/StockThemes.qml`, "utf8");
assert.equal(stockThemes.includes("apply_hyprland_theme.sh"), false);
assert.equal(
	/hyprctl["'\s,]+eval/.test(stockThemes),
	false,
	"colours reach Hyprland through theme.conf, not through a direct eval",
);
assert.match(stockThemes, /HyprTheme\.sync/);

// theme.conf holds the wallpaper too, and a wallpaper is chosen without touching
// the theme. Without this the lock screen keeps whichever wallpaper was current
// the last time the theme happened to change.
assert.match(
	stockThemes,
	/target: AppSettings\s*\n\s*function onCurrentWallpaperChanged\(\)/,
	"a wallpaper change must rewrite theme.conf",
);

const hyprTheme = fs.readFileSync(`${__dirname}/HyprTheme.qml`, "utf8");
assert.match(hyprTheme, /ThemeSyncState\.requestHyprland/);
assert.match(hyprTheme, /ThemeSyncState\.finishHyprland/);
assert.match(hyprTheme, /process\.exec\(processArgs\)/);

console.log(
	"HyprThemeTransform: one theme.conf for hyprlock and hyprland, and one reload behind it",
);
