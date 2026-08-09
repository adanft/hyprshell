// The shell's whole palette contract: sixteen roles per theme, and nothing
// else. Roles mirror Noctalia's ColorRole enum — four accent pairs (primary,
// secondary, tertiary, error), a hover pair, the surface pair with its variant,
// plus outline and shadow.
//
// There is no derived-token layer. Whatever a layout paints, it names one of
// these sixteen, so a theme is exactly sixteen decisions.

var ROLE_NAMES = [
	"primary",
	"on_primary",
	"secondary",
	"on_secondary",
	"tertiary",
	"on_tertiary",
	"error",
	"on_error",
	"surface",
	"on_surface",
	"surface_variant",
	"on_surface_variant",
	"outline",
	"shadow",
	"hover",
	"on_hover",
];

// Surfaces are painted deepest first: window bodies sit on `shadow`, cards and
// rows on `surface`, hovered and active chrome on `surface_variant`. A theme
// that breaks that order makes raised chrome read as a hole in the desktop.
var SURFACE_LADDER = ["shadow", "surface", "surface_variant"];

// Accents that routinely appear side by side in one control. Two of them
// sharing a value collapses the control into a single flat colour.
var DISTINCT_ACCENTS = ["primary", "secondary", "tertiary", "error", "hover"];

function parseColor(value, label) {
	if (typeof value !== "string" || !/^#[0-9a-fA-F]{6}$/.test(value))
		throw new Error(
			"role " + label + " must be an opaque #rrggbb color, got " + value,
		);
	return {
		r: parseInt(value.slice(1, 3), 16),
		g: parseInt(value.slice(3, 5), 16),
		b: parseInt(value.slice(5, 7), 16),
	};
}

function relativeLuminance(color) {
	var channels = [color.r, color.g, color.b].map(function (channel) {
		var ratio = channel / 255;
		return ratio <= 0.03928
			? ratio / 12.92
			: Math.pow((ratio + 0.055) / 1.055, 2.4);
	});
	return (
		0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
	);
}

function readPalette(name, definition) {
	if (!definition || typeof definition !== "object")
		throw new Error("theme " + name + " is not an object");
	if (
		typeof definition.displayName !== "string" ||
		definition.displayName.length === 0
	)
		throw new Error("theme " + name + " is missing displayName");

	var authored = Object.keys(definition).sort();
	var expected = ["displayName"].concat(ROLE_NAMES).sort();
	if (authored.join(",") !== expected.join(","))
		throw new Error(
			"theme " +
				name +
				" must author displayName plus exactly the 16 roles, got " +
				authored.join(","),
		);

	var palette = { displayName: definition.displayName };
	var parsed = {};
	for (var index = 0; index < ROLE_NAMES.length; index++) {
		var role = ROLE_NAMES[index];
		parsed[role] = parseColor(definition[role], name + "." + role);
		palette[role] = definition[role].toLowerCase();
	}

	for (var step = 1; step < SURFACE_LADDER.length; step++) {
		var lower = SURFACE_LADDER[step - 1];
		var upper = SURFACE_LADDER[step];
		if (relativeLuminance(parsed[upper]) <= relativeLuminance(parsed[lower]))
			throw new Error(
				"theme " +
					name +
					" surface ladder must climb: " +
					upper +
					" is not lighter than " +
					lower,
			);
	}

	var seen = {};
	for (var accent = 0; accent < DISTINCT_ACCENTS.length; accent++) {
		var value = palette[DISTINCT_ACCENTS[accent]];
		if (seen[value])
			throw new Error(
				"theme " +
					name +
					" reuses " +
					value +
					" for both " +
					seen[value] +
					" and " +
					DISTINCT_ACCENTS[accent],
			);
		seen[value] = DISTINCT_ACCENTS[accent];
	}

	return palette;
}

function readPalettes(definitions) {
	if (!definitions || typeof definitions !== "object")
		throw new Error("palette source is not an object");
	var names = Object.keys(definitions);
	if (names.length === 0) throw new Error("palette source is empty");

	var palettes = {};
	for (var index = 0; index < names.length; index++)
		palettes[names[index]] = readPalette(
			names[index],
			definitions[names[index]],
		);
	return palettes;
}

// The palette the shell paints before StockThemes has read themes.json, and the
// one it falls back to if that file is missing or invalid.
var FALLBACK_PALETTE = {
	displayName: "Catppuccin",
	primary: "#cba6f7",
	on_primary: "#11111b",
	secondary: "#f9e2af",
	on_secondary: "#11111b",
	tertiary: "#89b4fa",
	on_tertiary: "#11111b",
	error: "#f38ba8",
	on_error: "#11111b",
	surface: "#1e1e2e",
	on_surface: "#cdd6f4",
	surface_variant: "#313244",
	on_surface_variant: "#bac2de",
	outline: "#45475a",
	shadow: "#11111b",
	hover: "#94e2d5",
	on_hover: "#11111b",
};
