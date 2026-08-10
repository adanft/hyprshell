const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const catalogue = path.join(root, "theme/Icons.qml");
const source = fs.readFileSync(catalogue, "utf8");

// A Nerd Font glyph is unreadable in source: it renders as a box, or as a
// different picture, in every editor that lacks the font. Written inline it
// cannot be searched for, cannot be recognised, and gets copied rather than
// reused. Icons.qml is where they are named, and the only place they are typed.
const glyph = /[\u{E000}-\u{F8FF}\u{F0000}-\u{FFFFD}]/u;

function qmlFiles(directory) {
	return fs
		.readdirSync(path.join(root, directory), {
			withFileTypes: true,
			recursive: true,
		})
		.filter((entry) => entry.isFile() && entry.name.endsWith(".qml"))
		.map((entry) => path.join(entry.parentPath ?? entry.path, entry.name));
}

const offenders = [];
for (const directory of ["features", "shared", "services", "theme"]) {
	for (const file of qmlFiles(directory)) {
		if (file === catalogue) continue;
		for (const [index, line] of fs
			.readFileSync(file, "utf8")
			.split("\n")
			.entries()) {
			for (const [, literal] of line.matchAll(/"([^"]*)"/g))
				if (glyph.test(literal))
					offenders.push(`${path.relative(root, file)}:${index + 1}`);
		}
	}
}

assert.deepEqual(
	offenders,
	[],
	"a glyph must be named in theme/Icons.qml, not written where it is drawn",
);

// Grouped by what the glyph depicts, never by the feature that draws it.
// Sixteen icons have more than one consumer and search has four, so a group per
// feature would force either a copied glyph or a reach across features.
const groups = [
	"network",
	"bluetooth",
	"audio",
	"display",
	"battery",
	"powerProfile",
	"session",
	"notification",
	"system",
	"capture",
	"appearance",
	"fileFormat",
	"ui",
];
for (const group of groups)
	assert.match(
		source,
		new RegExp(`readonly property QtObject ${group}: QtObject \\{`),
		`Icons must group ${group}`,
	);

// Everything is a group or the one documented composite: no icon may sit loose
// at the top level, which is how the flat list grew to sixty in the first place.
const topLevel = [
	...source.matchAll(/^ {4}readonly property (\w+) (\w+):/gm),
].map(([, type, name]) => ({ type, name }));
const loose = topLevel.filter(
	(entry) => entry.type !== "QtObject" && entry.name !== "themePreviewNavigation",
);
assert.deepEqual(
	loose,
	[],
	"an icon must live in a group, not loose at the top level",
);

// Every glyph earns one name. trayCheck and wallpaperSelectedCheck were the
// same tick under two, which is how a set drifts apart.
const literals = [...source.matchAll(/: "([^"]+)"/g)]
	.map(([, value]) => value)
	.filter((value) => glyph.test(value));
const duplicates = literals.filter(
	(value, index) => literals.indexOf(value) !== index,
);
assert.deepEqual(duplicates, [], "the same glyph is named twice");

console.log("IconCatalogue: every glyph named once, grouped by what it depicts");
