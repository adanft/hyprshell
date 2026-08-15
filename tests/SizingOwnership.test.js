const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const featuresDir = path.join(root, "features");

// A dimension lives with the feature that draws it.
//
// Eighty-five percent of them had exactly one reader, so keeping them central
// meant every name had to carry its owner — appLauncherMaxWidth said which
// feature it belonged to because the file it sat in could not. The icons went
// the other way for the opposite reason: enough of them crossed that splitting
// would have meant copying glyphs.
//
// theme/Sizing keeps only what genuinely crosses: the raw steps, the search
// field, the action tile, and the bar metrics the tray and the surfaces hanging
// off the bar read too.
const features = fs
	.readdirSync(featuresDir, { withFileTypes: true })
	.filter((entry) => entry.isDirectory())
	.map((entry) => entry.name);

for (const feature of features) {
	const dir = path.join(featuresDir, feature);
	const singleton = fs
		.readdirSync(dir)
		.find((name) => /Sizing\.qml$/.test(name));
	if (!singleton) continue;

	// A feature that declares a singleton must declare its module, or its own
	// neighbours stop resolving — loudly, but only once something loads it.
	const qmldir = path.join(dir, "qmldir");
	assert.ok(fs.existsSync(qmldir), `${feature} declares ${singleton} without a qmldir`);

	const declared = fs
		.readFileSync(qmldir, "utf8")
		.split("\n")
		.filter(Boolean)
		.map((line) => line.trim().split(/\s+/).at(-1));
	for (const file of fs.readdirSync(dir).filter((n) => n.endsWith(".qml")))
		assert.ok(
			declared.includes(file),
			`${feature}/qmldir must declare ${file}, or it stops being a type`,
		);

	// Its dimensions are unprefixed: the file already says whose they are.
	for (const [, name] of fs
		.readFileSync(path.join(dir, singleton), "utf8")
		.matchAll(/readonly property (?:int|real) (\w+):/g))
		assert.ok(
			!/^(appLauncher|themeSelector|wallpaper|screenshotTool|notification|statusBar|powerMenu|tray)/.test(
				name,
			) || name === "notificationBadgeSize",
			`${singleton}.${name} still carries a feature prefix`,
		);
}

// Nothing in the shared file may name a feature: that is the tell that it drifted
// back to the center.
const shared = fs.readFileSync(path.join(root, "theme/Sizing.qml"), "utf8");
const drifted = [...shared.matchAll(/readonly property (?:int|real) (\w+):/g)]
	.map(([, name]) => name)
	.filter((name) =>
		/^(appLauncher|themeSelector|wallpaper|screenshotTool|powerMenu|tray)/.test(
			name,
		),
	);
assert.deepEqual(
	drifted,
	[],
	"a dimension named for one feature belongs to that feature",
);

console.log("SizingOwnership: each feature owns its dimensions, the theme owns what crosses");
