var managedMarker = "# hyprshell managed theme";

// Ghostty ships its own theme catalog, so the terminal is told a name rather
// than a palette. Every id in themes.json needs an entry: nativeThemeForId
// throws otherwise, and the sync would die on a theme the shell can otherwise
// paint. Most of these are the same scheme under the same name; the two that
// are not are noted where they sit.
var nativeThemes = {
	catppuccin: "Catppuccin Mocha",
	"rose-pine": "Rose Pine",
	"ayu-dark": "Ayu",
	aura: "Aura",
	// Ghostty carries no Hack The Box scheme. Everblush is the nearest in the
	// catalog: the same near-black blue-gray ground under a green accent.
	"hack-the-box": "Everblush",
	"aurora-x": "TokyoNight Night",
	// Ghostty's Palenight is the high-contrast cut, which is the same palette
	// with a lifted background — the only Palenight it ships.
	palenight: "Pale Night Hc",
	"one-dark": "Atom One Dark",
	"kanagawa-wave": "Kanagawa Wave",
	"kanagawa-dragon": "Kanagawa Dragon",
	"catppuccin-latte": "Catppuccin Latte",
	"atom-one-light": "Atom One Light",
	"kanagawa-lotus": "Kanagawa Lotus",
};

function nativeThemeForId(themeId) {
	if (!Object.prototype.hasOwnProperty.call(nativeThemes, themeId))
		throw new Error("no native Ghostty theme mapping for " + themeId);
	var nativeTheme = nativeThemes[themeId];
	return nativeTheme;
}

function splitConfig(text) {
	var eol = text.indexOf("\r\n") >= 0 ? "\r\n" : "\n";
	var hasFinalNewline = text.endsWith(eol);
	var lines = text === "" ? [] : text.split(eol);
	if (hasFinalNewline) lines.pop();
	return { eol: eol, hasFinalNewline: hasFinalNewline, lines: lines };
}

function joinConfig(config) {
	return (
		config.lines.join(config.eol) +
		(config.hasFinalNewline ? config.eol : "")
	);
}

function appendManagedTheme(config, nativeTheme) {
	config.lines.push(managedMarker, "theme = " + nativeTheme);
	return joinConfig(config);
}

function updateManagedTheme(config, nativeTheme) {
	var markerIndexes = [];
	for (var index = 0; index < config.lines.length; index++) {
		if (config.lines[index].trim() === managedMarker)
			markerIndexes.push(index);
	}

	if (markerIndexes.length === 0) return false;
	if (markerIndexes.length !== 1)
		throw new Error("multiple hyprshell managed Ghostty theme markers");

	var themeLineIndex = markerIndexes[0] + 1;
	if (
		themeLineIndex >= config.lines.length ||
		!/^[\t ]*theme[\t ]*=[\t ]*[^#\r\n]+[\t ]*$/.test(
			config.lines[themeLineIndex],
		)
	)
		throw new Error(
			"hyprshell managed Ghostty theme marker is not followed by a theme assignment",
		);

	config.lines[themeLineIndex] = "theme = " + nativeTheme;
	return true;
}

function transform(text, themeId) {
	var nativeTheme = nativeThemeForId(themeId);
	var config = splitConfig(text);
	if (updateManagedTheme(config, nativeTheme)) return joinConfig(config);

	return appendManagedTheme(config, nativeTheme);
}
