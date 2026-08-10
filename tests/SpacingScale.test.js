const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "theme/Spacing.qml"), "utf8");

// Spacing is a scale, not a dictionary of place names.
//
// It used to carry fifty aliases on top of the steps — eight different names
// meaning space12, each read once — so a call site named a concept and still
// told you nothing about the distance, and the file grew a name per use rather
// than a step per size.
const steps = [2, 3, 4, 6, 8, 12, 16, 18, 24, 52, 80, 96, 128];

const declared = [...source.matchAll(/readonly property int (\w+): (\d+)/g)].map(
	([, name, value]) => ({ name, value: Number(value) }),
);

assert.deepEqual(
	declared.map((entry) => entry.value),
	steps,
	"Spacing must declare the scale, in order, and nothing else",
);

for (const { name, value } of declared)
	assert.equal(
		name,
		`space${value}`,
		"a step is named for the distance it measures",
	);

// Nothing may alias a step under another name, in Spacing or anywhere else.
assert.doesNotMatch(
	source,
	/readonly property int \w+: (?!\d)/,
	"a step must be a number, not a reference to another step",
);

const aliases = new Set();
for (const directory of ["features", "shared", "services"]) {
	const files = fs
		.readdirSync(path.join(root, directory), {
			withFileTypes: true,
			recursive: true,
		})
		.filter((entry) => entry.isFile() && entry.name.endsWith(".qml"));
	for (const entry of files) {
		const file = path.join(entry.parentPath ?? entry.path, entry.name);
		for (const [, name] of fs
			.readFileSync(file, "utf8")
			.matchAll(/spacing\.(\w+)/g))
			if (!/^space\d+$/.test(name)) aliases.add(name);
	}
}
assert.deepEqual(
	[...aliases],
	[],
	"a call site must name a step, not an alias for one",
);

console.log("SpacingScale: one scale, every step named for its distance");
