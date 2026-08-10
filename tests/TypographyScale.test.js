const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const typography = fs.readFileSync(
	path.join(root, "theme/Typography.qml"),
	"utf8",
);

// One place for every font size, and one scale named against one base.
//
// Sizes used to live in two files. Sizing carried three tokens that were only
// ever a font size, and between the two files three different names spelled the
// same 24, so changing "the icon size" meant finding out which of them a given
// glyph happened to read.
const scale = {
	textSm: 12,
	textMd: 14,
	textBase: 16,
	textLg: 20,
	glyphSm: 16,
	glyphMd: 24,
	glyphLg: 28,
	glyphXl: 36,
	glyphHero: 68,
};

for (const [name, size] of Object.entries(scale))
	assert.match(
		typography,
		new RegExp(`readonly property int ${name}: ${size}\\b`),
		`Typography must declare ${name} at ${size}`,
	);

const declared = [...typography.matchAll(/readonly property int (\w+): (\d+)/g)];
assert.deepEqual(
	declared.map(([, name]) => name).sort(),
	Object.keys(scale).sort(),
	"Typography must declare the scale and nothing besides",
);

// A glyph is text, so its size belongs to the scale. Sizing describes how much
// room something takes, which is a different question and a different file.
function sourceFiles(directory) {
	return fs
		.readdirSync(path.join(root, directory), {
			withFileTypes: true,
			recursive: true,
		})
		.filter((entry) => entry.isFile() && entry.name.endsWith(".qml"))
		.map((entry) =>
			path.join(entry.parentPath ?? entry.path, entry.name),
		);
}

const offenders = [];
for (const directory of ["features", "shared", "services", "theme"]) {
	for (const file of sourceFiles(directory)) {
		for (const [line] of fs
			.readFileSync(file, "utf8")
			.matchAll(/^.*font\.pixelSize:.*$/gm)) {
			if (/\bsizing\./.test(line))
				offenders.push(`${path.relative(root, file)}: ${line.trim()}`);
		}
	}
}

assert.deepEqual(
	offenders,
	[],
	"a font size must come from Typography, not from Sizing",
);

console.log("TypographyScale: one scale, one base, and no font size outside it");
