const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(`${__dirname}/GhosttyThemeTransform.js`, "utf8");
const transform = {};
vm.createContext(transform);
vm.runInContext(source, transform);

const themes = JSON.parse(fs.readFileSync(`${__dirname}/themes.json`, "utf8"));
assert.deepEqual(Object.keys(themes).sort(), [
	"aura",
	"aurora-x",
	"ayu-dark",
	"catppuccin",
	"hack-the-box",
	"rose-pine",
]);

assert.deepEqual(
	Object.fromEntries(
		Object.keys(themes).map((id) => [id, transform.nativeThemeForId(id)]),
	),
	{
		catppuccin: "Catppuccin Mocha",
		"rose-pine": "Rose Pine",
		"ayu-dark": "Ayu",
		aura: "Aura",
		"hack-the-box": "Everblush",
		"aurora-x": "TokyoNight Night",
	},
);
assert.throws(
	() => transform.nativeThemeForId("unknown"),
	/no native Ghostty theme mapping/,
);
assert.throws(
	() => transform.nativeThemeForId("__proto__"),
	/no native Ghostty theme mapping/,
);
assert.throws(
	() => transform.nativeThemeForId("constructor"),
	/no native Ghostty theme mapping/,
);

function apply(input, themeId = "catppuccin") {
	return transform.transform(input, themeId);
}

for (const [input, expected] of [
	["", "# qsrice managed theme\ntheme = Catppuccin Mocha"],
	[
		"font-family = Keep This\n",
		"font-family = Keep This\n# qsrice managed theme\ntheme = Catppuccin Mocha\n",
	],
	[
		"font-family = Keep This\r\n",
		"font-family = Keep This\r\n# qsrice managed theme\r\ntheme = Catppuccin Mocha\r\n",
	],
	[
		"font-family = Keep This",
		"font-family = Keep This\n# qsrice managed theme\ntheme = Catppuccin Mocha",
	],
])
	assert.equal(
		apply(input),
		expected,
		"inserts a managed native theme while preserving newline style",
	);

const managed =
	"theme = User Theme\n# qsrice managed theme\ntheme = Old Theme\nforeground = #abcdef\n";
const updated = apply(managed, "rose-pine");
assert.equal(
	updated,
	"theme = User Theme\n# qsrice managed theme\ntheme = Rose Pine\nforeground = #abcdef\n",
);
assert.equal(
	apply(updated, "rose-pine"),
	updated,
	"managed theme updates are idempotent",
);
assert.equal(
	(updated.match(/^theme = /gm) || []).length,
	2,
	"only the marker-owned theme line is changed",
);
assert.throws(
	() => apply("# qsrice managed theme\nfont-family = Mono\n"),
	/not followed by a theme assignment/,
);
assert.equal(
	apply("# qscomponents managed theme\ntheme = Old Theme\n", "rose-pine"),
	"# qscomponents managed theme\ntheme = Rose Pine\n",
);
assert.throws(
	() =>
		apply(
			"# qsrice managed theme\ntheme = One\n# qsrice managed theme\ntheme = Two\n",
		),
	/multiple qsrice/,
);
assert.equal(
	apply("theme = User Theme\n"),
	"theme = User Theme\n# qsrice managed theme\ntheme = Catppuccin Mocha\n",
);
const existingColors =
	"foreground = #abcdef\npalette = 0 = not-a-color\nselection-background = custom-value\n";
assert.equal(
	apply(existingColors),
	existingColors + "# qsrice managed theme\ntheme = Catppuccin Mocha\n",
	"existing color assignments are preserved without parsing or migration",
);

console.log(
	"GhosttyThemeTransform: native mapping and managed assignment for 6 themes passed",
);
