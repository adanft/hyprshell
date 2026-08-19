const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const runtime = __dirname;
const stockThemes = fs.readFileSync(path.join(runtime, "StockThemes.qml"), "utf8");
const forbiddenPaths = [
	"HyprTheme.qml",
	"HyprThemeTransform.js",
	"GhosttyTheme.qml",
	"GhosttyThemeTransform.js",
	"ThemeSyncState.js",
	"policy",
];

for (const entry of forbiddenPaths)
	assert.equal(
		fs.existsSync(path.join(runtime, entry)),
		false,
		`${entry} must be removed`,
	);

assert.match(stockThemes, /Colors\.palette\s*=\s*themeData/);
assert.match(stockThemes, /AppSettings\.setCurrentTheme/);
assert.doesNotMatch(
	stockThemes,
	/Ghostty|HyprTheme|theme\.conf|hyprctl|startupCoordinator/,
);

console.log("External theme cleanup invariant passed");
