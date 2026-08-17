const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(`${__dirname}/GhosttyThemeTransform.js`, "utf8");
const transform = {};
vm.createContext(transform);
vm.runInContext(source, transform);

const themes = JSON.parse(fs.readFileSync(`${__dirname}/themes.json`, "utf8"));
// Every theme the shell can paint must also have a name Ghostty knows, or
// selecting it kills the terminal sync on a throw. Listing them here is what
// makes adding a palette without its native counterpart fail loudly.
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
		palenight: "Pale Night Hc",
		"one-dark": "Atom One Dark",
		"kanagawa-wave": "Kanagawa Wave",
		"kanagawa-dragon": "Kanagawa Dragon",
		"catppuccin-latte": "Catppuccin Latte",
		"atom-one-light": "Atom One Light",
		"kanagawa-lotus": "Kanagawa Lotus",
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
	["", "# hyprshell managed theme\ntheme = Catppuccin Mocha"],
	[
		"font-family = Keep This\n",
		"font-family = Keep This\n# hyprshell managed theme\ntheme = Catppuccin Mocha\n",
	],
	[
		"font-family = Keep This\r\n",
		"font-family = Keep This\r\n# hyprshell managed theme\r\ntheme = Catppuccin Mocha\r\n",
	],
	[
		"font-family = Keep This",
		"font-family = Keep This\n# hyprshell managed theme\ntheme = Catppuccin Mocha",
	],
])
	assert.equal(
		apply(input),
		expected,
		"inserts a managed native theme while preserving newline style",
	);

const managed =
	"theme = User Theme\n# hyprshell managed theme\ntheme = Old Theme\nforeground = #abcdef\n";
const updated = apply(managed, "rose-pine");
assert.equal(
	updated,
	"theme = User Theme\n# hyprshell managed theme\ntheme = Rose Pine\nforeground = #abcdef\n",
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
	() => apply("# hyprshell managed theme\nfont-family = Mono\n"),
	/not followed by a theme assignment/,
);
// The shell's own block is found by its one marker and updated in place.
//
// There used to be a list of every marker the shell had ever written, so a
// config carrying an older name was still recognised. That went with the rest
// of the legacy handling: one name now, and a config carrying an older marker
// is simply not ours — the next theme change appends a fresh block and leaves
// the old lines where they are, for their owner to delete.
assert.equal(
	apply("# hyprshell managed theme\ntheme = Old Theme\n", "rose-pine"),
	"# hyprshell managed theme\ntheme = Rose Pine\n",
);

// And no earlier name is recognised, which is the half that says the decision
// held rather than merely that the current name works.
for (const gone of ["# qsrice managed theme", "# qscomponents managed theme"])
	assert.equal(
		apply(`${gone}\ntheme = Old Theme\n`, "rose-pine"),
		`${gone}\ntheme = Old Theme\n# hyprshell managed theme\ntheme = Rose Pine\n`,
		`${gone} is left alone rather than adopted`,
	);

assert.throws(
	() =>
		apply(
			"# hyprshell managed theme\ntheme = One\n# hyprshell managed theme\ntheme = Two\n",
		),
	/multiple hyprshell/,
);
assert.equal(
	apply("theme = User Theme\n"),
	"theme = User Theme\n# hyprshell managed theme\ntheme = Catppuccin Mocha\n",
);
const existingColors =
	"foreground = #abcdef\npalette = 0 = not-a-color\nselection-background = custom-value\n";
assert.equal(
	apply(existingColors),
	existingColors + "# hyprshell managed theme\ntheme = Catppuccin Mocha\n",
	"existing color assignments are preserved without parsing or migration",
);

console.log(
	`GhosttyThemeTransform: native mapping and managed assignment for ${Object.keys(themes).length} themes passed`,
);
