const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

// Features stand on the platform, never the other way round.
//
// services holds the capabilities that talk to the outside world, theme holds
// the design tokens and shared holds the widgets anyone may use. All three are
// ground for the slices under features/, so none of them may reach up into one.
// A capability that imports a feature cannot be reused by a second feature
// without dragging the first one along, and the dependency is invisible until
// something moves — which is exactly how the notification service came to import
// NotificationImagePersistence out of the notifications slice, when only the
// service ever used it.
const platformDirectories = ["services", "theme", "shared"];

function sourceFiles(directory) {
	return fs
		.readdirSync(path.join(root, directory), {
			withFileTypes: true,
			recursive: true,
		})
		.filter(
			(entry) =>
				entry.isFile() &&
				(entry.name.endsWith(".qml") || entry.name.endsWith(".js")),
		)
		.map((entry) =>
			path.relative(root, path.join(entry.parentPath ?? entry.path, entry.name)),
		);
}

const offenders = [];
for (const directory of platformDirectories) {
	for (const relativePath of sourceFiles(directory)) {
		// Test files may read a feature to assert a contract across the seam.
		// Importing one into production code is what this forbids.
		if (relativePath.endsWith(".test.js")) continue;

		const source = fs.readFileSync(path.join(root, relativePath), "utf8");
		for (const [, target] of source.matchAll(/^\s*import\s+"([^"]+)"/gm)) {
			const resolved = path.relative(
				root,
				path.resolve(path.dirname(path.join(root, relativePath)), target),
			);
			if (resolved.startsWith("features"))
				offenders.push(`${relativePath} imports ${target}`);
		}
	}
}

assert.deepEqual(
	offenders,
	[],
	"the platform must not import a feature; move the shared piece down instead",
);

console.log("LayerDependencies: the platform does not depend on any feature");
