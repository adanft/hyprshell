function normalizedHex(color) {
	var value = typeof color === "string" ? color : "";
	if (!/^#[0-9a-fA-F]{6}$/.test(value))
		throw new Error("Invalid Hyprland color: " + value);

	return value.slice(1).toLowerCase();
}

function configExpression(theme) {
	var activeBorder = normalizedHex(theme && theme.primary);
	var inactiveBorder = normalizedHex(theme && theme.outline);
	var background = normalizedHex(theme && theme.shadow);

	return (
		'hl.config({ general = { col = { active_border = "rgb(' +
		activeBorder +
		')", inactive_border = "rgb(' +
		inactiveBorder +
		')" } }, misc = { background_color = "rgb(' +
		background +
		')" } })'
	);
}

function processArguments(theme) {
	return ["hyprctl", "eval", configExpression(theme)];
}
