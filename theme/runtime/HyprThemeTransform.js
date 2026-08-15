// theme.conf: the one file the Hyprland family reads.
//
// Hyprlock can only source hyprlang, so hyprlang is what this writes. Hyprland
// speaks Lua, but Lua can open a file, and hyprland.lua reads these same lines
// back. One file, both programs, so there is no second copy to fall out of step
// — which is the whole reason the palette moved out of their configs.
//
// The names are roles rather than pigments. `theme.conf` used to spell
// Catppuccin's vocabulary — mauve, peach, crust — and under any other palette
// those become lies: there is no mauve in Kanagawa. `$primary` is true whatever
// is loaded.

function normalizedHex(color) {
	var value = typeof color === "string" ? color : "";
	if (!/^#[0-9a-fA-F]{6}$/.test(value))
		throw new Error("Invalid Hyprland color: " + value);

	return value.slice(1).toLowerCase();
}

// A value reaching a config file has to be one line, because hyprlang reads one
// line at a time: a newline would not corrupt the entry, it would append a new
// one of the writer's choosing.
//
// `optional` is for the wallpaper, which is genuinely allowed to be nothing: a
// shell with none chosen yet still has a palette, and refusing to write the file
// over a missing picture would cost the lock screen and the compositor all their
// colors. hyprlang takes an empty value and substitutes it as nothing, which is
// what an unset background already means to hyprlock.
function normalizedText(value, label, optional) {
	var text = typeof value === "string" ? value : "";
	if (/[\r\n]/.test(text) || (!optional && text.length === 0))
		throw new Error("Invalid Hyprland " + label + ": " + JSON.stringify(value));

	return text;
}

var managedMarker = "# qsrice managed theme";

// Exactly what the two programs paint, and nothing else. A palette holds sixteen
// roles; the other eight would be unread names in a file, and every one of them
// a thing to wonder about later.
//
// Two forms per color where a color is needed twice: `rgb(hhhhhh)` for color
// properties, and the bare hex for the pango markup inside hyprlock's
// placeholder_text, which is a string and cannot take a color value. Hyprlang
// does not concatenate, so a translucent fill arrives already composed.
var VARIABLES = [
	{ name: "primary", role: "primary", form: "rgb" },
	{ name: "primaryAlpha", role: "primary", form: "hex" },
	{ name: "secondary", role: "secondary", form: "rgb" },
	{ name: "error", role: "error", form: "rgb" },
	{ name: "outline", role: "outline", form: "rgb" },
	{ name: "surface", role: "surface", form: "rgb" },
	{ name: "surfaceVeil", role: "surface", form: "rgba", alpha: "80" },
	{ name: "shadow", role: "shadow", form: "rgb" },
	{ name: "on_surface", role: "on_surface", form: "rgb" },
	{ name: "on_surfaceAlpha", role: "on_surface", form: "hex" },
];

function renderVariable(variable, hex) {
	if (variable.form === "hex") return hex;
	if (variable.form === "rgba") return "rgba(" + hex + variable.alpha + ")";
	return "rgb(" + hex + ")";
}

// The wallpaper and the font are not palette roles — one is a setting, the other
// is the shell's own type. They live here anyway, because the point of the file
// is that these configs never have to be opened again, and a hard-coded path in
// hyprlock.conf is exactly the kind of thing that quietly stops matching.
function renderThemeConf(theme, appearance) {
	var lines = [
		managedMarker,
		"# Written by the shell. Edits are lost on the next theme change.",
		"# hyprlock sources this; hyprland.lua reads it back.",
		"",
	];

	for (var index = 0; index < VARIABLES.length; index++) {
		var variable = VARIABLES[index];
		var hex = normalizedHex(theme && theme[variable.role]);
		lines.push("$" + variable.name + " = " + renderVariable(variable, hex));
	}

	lines.push("");
	lines.push(
		"$wallpaper = " +
			normalizedText(appearance && appearance.wallpaper, "wallpaper", true),
	);
	lines.push("$font = " + normalizedText(appearance && appearance.font, "font"));

	return lines.join("\n") + "\n";
}

// Hyprland holds its config in memory, so the file it just read means nothing
// until it is told to read again. This is the whole live path: no second command
// setting colors directly, because then the file and the command would each be
// a source of truth and only one of them would be right.
function reloadArguments() {
	return ["hyprctl", "reload"];
}

// Of everything in the file, Hyprland reads only the colors. The wallpaper and
// the font are the lock screen's, and hyprlock re-reads on its own next launch —
// so picking a wallpaper should not make the compositor re-apply its monitors,
// binds and animations for a line it will never look at.
function colorLines(text) {
	return String(text || "")
		.split("\n")
		.filter(function (line) {
			return /^\$\w+ = rgba?\(/.test(line);
		})
		.join("\n");
}

function needsReload(currentText, nextText) {
	return colorLines(currentText) !== colorLines(nextText);
}
