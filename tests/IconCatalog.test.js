const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const catalog = path.join(root, "theme/Icons.qml");
const source = fs.readFileSync(catalog, "utf8");

// A Nerd Font glyph is unreadable in source: it renders as a box, or as a
// different picture, in every editor that lacks the font. Written inline it
// cannot be searched for, cannot be recognized, and gets copied rather than
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
		if (file === catalog) continue;
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

// Everything is a group: no icon may sit loose at the top level, which is how
// the flat list grew to sixty in the first place.
const topLevel = [
	...source.matchAll(/^ {4}readonly property (\w+) (\w+):/gm),
].map(([, type, name]) => ({ type, name }));
const loose = topLevel.filter((entry) => entry.type !== "QtObject");
assert.deepEqual(
	loose,
	[],
	"an icon must live in a group, not loose at the top level",
);

// An icon must actually carry a glyph.
//
// This is the check that was missing when the catalog was first written by
// hand: thirty-three glyphs did not survive being typed into the file, and the
// rule above passed anyway, because "no glyph outside the catalog" is trivially
// true of an empty string. Nothing warned, nothing failed, and the icons simply
// stopped being drawn. Never retype a glyph — copy it from the source it already
// lives in.
const blank = [];
for (const [, name, value] of source.matchAll(
	/readonly property string (\w+): "([^"]*)"/g,
))
	if (value.trim().length === 0) blank.push(name);

for (const [, name, body] of source.matchAll(
	/readonly property var (\w+): \[([^\]]*)\]/g,
))
	for (const [index, entry] of body.split(",").entries()) {
		const trimmed = entry.trim();
		// An entry may name another icon rather than spell a glyph.
		if (trimmed.startsWith('"') && trimmed.replaceAll('"', "").trim() === "")
			blank.push(`${name}[${index}]`);
	}

assert.deepEqual(blank, [], "an icon must carry a glyph, not an empty string");

// Within a group, a glyph earns one name: trayCheck and wallpaperSelectedCheck
// were the same tick twice, which is how a set drifts apart.
//
// Across groups it may repeat, and that is not an accident to clean up. The moon
// is session.suspend and appearance.dark — one picture, two meanings that are
// free to diverge. Collapsing them would make changing the dark-mode icon change
// what suspend looks like.
const groupBlocks = [
	...source.matchAll(
		/readonly property QtObject (\w+): QtObject \{([\s\S]*?)\n {4}\}/g,
	),
];
assert.equal(
	groupBlocks.length,
	groups.length,
	"every group must be readable as a block",
);

const repeated = [];
for (const [, groupName, body] of groupBlocks) {
	const seen = new Map();
	for (const [, name, value] of body.matchAll(
		/readonly property string (\w+): "([^"]+)"/g,
	)) {
		if (seen.has(value))
			repeated.push(`${groupName}: ${seen.get(value)} and ${name}`);
		seen.set(value, name);
	}
}
assert.deepEqual(repeated, [], "a group names the same glyph twice");

console.log("IconCatalog: every glyph named once, grouped by what it depicts");
