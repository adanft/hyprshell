var managedMarker = "# qsrice managed theme";
var legacyManagedMarker = "# qscomponents managed theme";

var nativeThemes = {
	catppuccin: "Catppuccin Mocha",
	"rose-pine": "Rose Pine",
	"ayu-dark": "Ayu",
	aura: "Aura",
	"hack-the-box": "Everblush",
	"aurora-x": "TokyoNight Night",
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
		if (
			config.lines[index].trim() === managedMarker ||
			config.lines[index].trim() === legacyManagedMarker
		)
			markerIndexes.push(index);
	}

	if (markerIndexes.length === 0) return false;
	if (markerIndexes.length !== 1)
		throw new Error("multiple qsrice managed Ghostty theme markers");

	var themeLineIndex = markerIndexes[0] + 1;
	if (
		themeLineIndex >= config.lines.length ||
		!/^[\t ]*theme[\t ]*=[\t ]*[^#\r\n]+[\t ]*$/.test(
			config.lines[themeLineIndex],
		)
	)
		throw new Error(
			"qsrice managed Ghostty theme marker is not followed by a theme assignment",
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
