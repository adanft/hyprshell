const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const context = {};
vm.createContext(context);
vm.runInContext(
	fs.readFileSync(`${__dirname}/PaletteRoles.js`, "utf8"),
	context,
);

const source = JSON.parse(fs.readFileSync(`${__dirname}/runtime/themes.json`, "utf8"));
const palettes = context.readPalettes(source);

assert.equal(context.ROLE_NAMES.length, 16);
assert.deepEqual(Object.keys(palettes).sort(), Object.keys(source).sort());

// A palette is displayName plus the 16 roles, full stop. Nothing derived, so a
// layout can only paint what a theme actually authored.
for (const [name, palette] of Object.entries(palettes)) {
	assert.deepEqual(
		Object.keys(palette).sort(),
		["displayName"].concat(context.ROLE_NAMES).sort(),
		`${name} is not exactly displayName plus the 16 roles`,
	);
	for (const role of context.ROLE_NAMES)
		assert.match(palette[role], /^#[0-9a-f]{6}$/, `${name}.${role}`);
}

// A QML object holding both `primary` and `onPrimary` silently leaves the
// second one black, because onPrimary reads as a handler for primary. Snake
// case is what keeps the foreground roles alive, so it is not cosmetic.
for (const role of context.ROLE_NAMES)
	assert.doesNotMatch(
		role,
		/^on[A-Z]/,
		`${role} would collide with its base role as a QML signal handler`,
	);

const mocha = palettes.catppuccin;
assert.equal(mocha.primary, "#cba6f7");
assert.equal(mocha.on_primary, "#11111b");
assert.equal(mocha.secondary, "#f9e2af");
assert.equal(mocha.tertiary, "#89b4fa");
assert.equal(mocha.error, "#f38ba8");
assert.equal(mocha.hover, "#94e2d5");
assert.equal(mocha.shadow, "#11111b");
assert.equal(mocha.surface, "#1e1e2e");
assert.equal(mocha.on_surface, "#cdd6f4");
assert.equal(mocha.surface_variant, "#313244");
assert.equal(mocha.on_surface_variant, "#bac2de");
assert.equal(mocha.outline, "#45475a");

const valid = source.catppuccin;
const withRole = (role, value) =>
	Object.assign({}, valid, { [role]: value });

assert.throws(
	() => context.readPalettes({ broken: withRole("primary", "#f0cba6f7") }),
	/role broken\.primary must be an opaque #rrggbb color/,
);
assert.throws(
	() => context.readPalettes({ broken: Object.assign({}, valid, { extra: "#000000" }) }),
	/must author displayName plus exactly the 16 roles/,
);
assert.throws(() => {
	const missing = Object.assign({}, valid);
	delete missing.on_hover;
	return context.readPalettes({ broken: missing });
}, /must author displayName plus exactly the 16 roles/);
assert.throws(
	() => context.readPalettes({ broken: Object.assign({}, valid, { displayName: "" }) }),
	/theme broken is missing displayName/,
);

// A window body must never outshine the card sitting on it.
assert.throws(
	() => context.readPalettes({ broken: withRole("shadow", "#ffffff") }),
	/surface ladder must climb: surface is not lighter than shadow/,
);
assert.throws(
	() => context.readPalettes({ broken: withRole("surface_variant", "#000000") }),
	/surface ladder must climb: surface_variant is not lighter than surface/,
);

// Two accents sharing a value flattens every control that shows both at once —
// a selected card that is also hovered, a power menu row beside its neighbour.
assert.throws(
	() => context.readPalettes({ broken: withRole("hover", valid.tertiary) }),
	/reuses #89b4fa for both tertiary and hover/,
);

assert.throws(() => context.readPalettes({}), /palette source is empty/);
assert.throws(
	() => context.readPalettes(null),
	/palette source is not an object/,
);

// Nothing outside theme/ may name a colour that is not one of the 16 roles:
// that is the whole point of collapsing the palette.
const ALLOWED = new Set(context.ROLE_NAMES.concat(["clear", "alpha"]));
const repository = path.resolve(__dirname, "..");
const sources = fs
	.readdirSync(repository, { recursive: true, withFileTypes: true })
	.filter((entry) => entry.isFile() && /\.(qml|js)$/.test(entry.name))
	.map((entry) => path.join(entry.parentPath ?? entry.path, entry.name))
	.filter((file) => !file.includes(`${path.sep}.`))
	.filter((file) => !file.startsWith(`${__dirname}${path.sep}`) && path.dirname(file) !== __dirname);

const qml = sources.filter(
	(file) => file.endsWith(".qml") && !file.includes(`${path.sep}tests${path.sep}`),
);

const strays = [];
for (const file of sources) {
	const text = fs.readFileSync(file, "utf8");
	for (const match of text.matchAll(/\bColors\.([a-zA-Z_]+)/g))
		if (!ALLOWED.has(match[1]))
			strays.push(`${path.relative(repository, file)}: colors.${match[1]}`);
}
assert.deepEqual(strays, [], `colours outside the 16 roles: ${strays.join(", ")}`);

// Pointer feedback is one role everywhere. A binding whose condition is only
// about the pointer — no selection, no device state — must resolve to `hover`
// for a fill or `on_hover` for whatever sits on it. `surface_variant` used to
// serve that job in the status bar rows and must not drift back into it.
const POINTER = /containsMouse|\bhovered\b/;
const STATE = /\bselected\b|\bactive\b|\bisActive\b|\bcurrent\b|\bmuted\b|Dnd\b|\bseparator\b|\bdanger\b|\bconnected\b|\benabledEntry\b/;
const BINDING = /^[\t ]*(?:readonly[\t ]+property[\t ]+color[\t ]+\w+|[\w.]*(?:color|border\.color|trackColor|handleColor)):[\t ]*(.+)$/;

const offConvention = [];
for (const file of sources) {
	const lines = fs.readFileSync(file, "utf8").split("\n");
	for (let index = 0; index < lines.length; index++) {
		const opening = BINDING.exec(lines[index]);
		if (!opening) continue;
		let expression = opening[1];
		let cursor = index;
		while (
			(expression.split("(").length - expression.split(")").length !== 0 ||
				/[?:]$|\|\|$|&&$/.test(expression.trimEnd())) &&
			cursor + 1 < lines.length
		) {
			cursor += 1;
			expression += ` ${lines[cursor].trim()}`;
		}
		for (const [, condition, branch] of expression.matchAll(
			/([^?:]+)\?\s*([^:]+):/g,
		)) {
			if (!POINTER.test(condition) || STATE.test(condition)) continue;
			const role = /Colors\.([a-z_]+)/.exec(branch)?.[1];
			if (role && role !== "hover" && role !== "on_hover")
				offConvention.push(
					`${path.relative(repository, file)}:${index + 1} uses colors.${role}`,
				);
		}
		index = cursor;
	}
}
assert.deepEqual(
	offConvention,
	[],
	`pointer feedback must be hover/on_hover: ${offConvention.join(", ")}`,
);

// A colour that swaps on containsMouse is dead unless its MouseArea opts into
// hover tracking, and hoverEnabled defaults to false. The wrong role is at
// least visible; this one just never fires.
const deadHover = [];
for (const file of qml) {
	const lines = fs.readFileSync(file, "utf8").split("\n");
	const tracks = new Map();
	lines.forEach((line, index) => {
		const opening = /^(\s*)(?:\w+\.)?MouseArea\s*\{\s*$/.exec(line);
		if (!opening) return;
		const indent = opening[1].length;
		const own = [];
		for (let cursor = index + 1; cursor < lines.length; cursor++) {
			const body = lines[cursor];
			const bodyIndent = body.length - body.trimStart().length;
			if (body.trim() && bodyIndent <= indent) break;
			if (body.trim() && bodyIndent === indent + 4) own.push(body);
		}
		const declared = own.join("\n");
		const named = /^\s*id:\s*(\w+)/m.exec(declared);
		if (named) tracks.set(named[1], /^\s*hoverEnabled:\s*true/m.test(declared));
	});
	lines.forEach((line, index) => {
		if (!/[cC]olor:/.test(line)) return;
		for (const [, area] of line.matchAll(/(\w+)\.containsMouse/g))
			if (tracks.get(area) === false)
				deadHover.push(
					`${path.relative(repository, file)}:${index + 1} reads ${area}.containsMouse, which never becomes true`,
				);
	});
}
assert.deepEqual(
	deadHover,
	[],
	`a hover colour needs hoverEnabled: ${deadHover.join(", ")}`,
);

// The status bar dims an unavailable module to the same tone an empty
// workspace uses, so "there is nothing here" reads identically across the bar.
const EMPTY_WORKSPACE_ROLE = /return empty \? Colors\.outline :/;
const workspaces = fs.readFileSync(
	path.join(repository, "features/statusbar/modules/Workspaces.qml"),
	"utf8",
);
assert.match(
	workspaces,
	EMPTY_WORKSPACE_ROLE,
	"an empty workspace must stay on colors.outline; it is the reference tone",
);

const disabled = [];
for (const file of sources) {
	const text = fs.readFileSync(file, "utf8");
	if (!/moduleDisabled/.test(text)) continue;
	for (const [, branch] of text.matchAll(
		/moduleDisabled\s*\?\s*([\s\S]{0,60}?)\s*:/g,
	)) {
		const role = /Colors\.([a-z_]+)/.exec(branch)?.[1];
		if (role !== "outline")
			disabled.push(
				`${path.relative(repository, file)} dims to colors.${role}`,
			);
	}
}
assert.deepEqual(
	disabled,
	[],
	`a disabled status bar module must dim to colors.outline: ${disabled.join(", ")}`,
);

const dimmed = sources.filter((file) =>
	/moduleDisabled/.test(fs.readFileSync(file, "utf8")),
).length;

// Everything above proves the roles are used. This proves nothing *else* is:
// a colour can enter the shell as a literal, as a Qt constructor, from the
// system palette, or by leaving a Qt default in place.

// "transparent" is the absence of a colour, and an OpacityMask stencil reads
// only alpha, so its rgb is not a palette decision. Nothing else may be named.
const LITERAL_COLOUR =
	/#[0-9a-fA-F]{3,8}\b|"(?:black|white|red|green|blue|yellow|cyan|magenta|gray|grey|orange|purple|pink|brown)"/;
const CONSTRUCTED_COLOUR = /Qt\.(?:rgba|hsla|hsva|lighter|darker|tint)\s*\(|SystemPalette/;

const smuggled = [];
for (const file of qml) {
	const lines = fs.readFileSync(file, "utf8").split("\n");
	lines.forEach((line, index) => {
		const where = `${path.relative(repository, file)}:${index + 1}`;
		if (CONSTRUCTED_COLOUR.test(line)) smuggled.push(`${where} constructs a colour`);
		if (!LITERAL_COLOUR.test(line)) return;
		// A mask stencil is the one place a bare colour is honest; it is marked
		// as such in the two lines above it.
		const context = lines.slice(Math.max(0, index - 3), index).join(" ");
		if (/OpacityMask stencil/.test(context)) return;
		smuggled.push(`${where} names a colour literal`);
	});
}
assert.deepEqual(
	smuggled,
	[],
	`only the 16 roles may paint: ${smuggled.join(", ")}`,
);

// A Rectangle that draws a border without naming its colour draws it black.
const bareBorders = [];
for (const file of qml) {
	const lines = fs.readFileSync(file, "utf8").split("\n");
	lines.forEach((line, index) => {
		const opening = /^(\s*)(?:\w+\.)?Rectangle\s*\{\s*$/.exec(line);
		if (!opening) return;
		const indent = opening[1].length;
		const own = [];
		for (let cursor = index + 1; cursor < lines.length; cursor++) {
			const body = lines[cursor];
			const bodyIndent = body.length - body.trimStart().length;
			if (body.trim() && bodyIndent <= indent) break;
			if (body.trim() && bodyIndent === indent + 4) own.push(body);
		}
		const declared = own.join("\n");
		const width = /^\s*border\.width:\s*(.+)$/m.exec(declared);
		if (!width || width[1].trim() === "0") return;
		if (!/^\s*border\.color:/m.test(declared))
			bareBorders.push(
				`${path.relative(repository, file)}:${index + 1} draws a border with no colour`,
			);
	});
}
assert.deepEqual(
	bareBorders,
	[],
	`a painted border must name its role: ${bareBorders.join(", ")}`,
);

// The mirror of the check above, and the one that actually bites: border.width
// defaults to 1, so naming a border colour and nothing else silently draws a
// hairline. Every border has to state both halves.
const implicitBorders = [];
for (const file of qml) {
	const lines = fs.readFileSync(file, "utf8").split("\n");
	lines.forEach((line, index) => {
		const opening = /^(\s*)(?:\w+\.)?(?:Clipping)?Rectangle\s*\{\s*$/.exec(line);
		if (!opening) return;
		const indent = opening[1].length;
		const own = [];
		for (let cursor = index + 1; cursor < lines.length; cursor++) {
			const body = lines[cursor];
			const bodyIndent = body.length - body.trimStart().length;
			if (body.trim() && bodyIndent <= indent) break;
			if (body.trim() && bodyIndent === indent + 4) own.push(body);
		}
		const declared = own.join("\n");
		if (/^\s*border\.color:/m.test(declared) && !/^\s*border\.width:/m.test(declared))
			implicitBorders.push(
				`${path.relative(repository, file)}:${index + 1} names a border colour without a width`,
			);
	});
}
assert.deepEqual(
	implicitBorders,
	[],
	`border.width defaults to 1, so it must be stated: ${implicitBorders.join(", ")}`,
);

console.log(
	`PaletteRoles: 16-role contract, Mocha values, surface ladder, distinct accents, one hover role, ${dimmed} modules dimming to outline, and ${qml.length} QML files painting nothing but roles passed`,
);
