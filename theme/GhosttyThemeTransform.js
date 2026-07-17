var dynamicKeys = [
    "background", "foreground", "cursor-color", "cursor-text",
    "selection-background", "selection-foreground"
]

var semanticMapping = [
    "surfaceInverse", "danger", "success", "warning", "info", "primary",
    "secondary", "textMuted", "borderStrong", "critical", "success", "warning",
    "link", "focus", "secondary", "text"
]

function parseColor(value) {
    var text = String(value || "").toLowerCase()
    if (text === "transparent")
        return { a: 0, r: 0, g: 0, b: 0 }
    if (text === "black")
        return { a: 255, r: 0, g: 0, b: 0 }

    var hex = text.charAt(0) === "#" ? text.slice(1) : ""
    if ((hex.length === 6 || hex.length === 8) && !/[^0-9a-f]/.test(hex)) {
        var offset = hex.length === 8 ? 2 : 0
        return {
            a: offset ? parseInt(hex.slice(0, 2), 16) : 255,
            r: parseInt(hex.slice(offset, offset + 2), 16),
            g: parseInt(hex.slice(offset + 2, offset + 4), 16),
            b: parseInt(hex.slice(offset + 4, offset + 6), 16)
        }
    }
    throw new Error("invalid color: " + value)
}

function hexByte(value) {
    return Math.max(0, Math.min(255, value)).toString(16).padStart(2, "0")
}

function opaqueHex(color) {
    if (!color || color.a !== 255)
        throw new Error("color is not opaque")
    return "#" + hexByte(color.r) + hexByte(color.g) + hexByte(color.b)
}

function composite(foreground, background) {
    if (background.a !== 255)
        throw new Error("selection background requires an opaque theme background")
    var alpha = foreground.a / 255
    return {
        a: 255,
        r: Math.round(foreground.r * alpha + background.r * (1 - alpha)),
        g: Math.round(foreground.g * alpha + background.g * (1 - alpha)),
        b: Math.round(foreground.b * alpha + background.b * (1 - alpha))
    }
}

function colorsForTheme(theme) {
    if (!theme)
        throw new Error("theme data is unavailable")

    var colors = {}
    for (var index = 0; index < semanticMapping.length; index++)
        colors["palette:" + index] = opaqueHex(parseColor(theme[semanticMapping[index]]))

    colors.background = opaqueHex(parseColor(theme.background))
    colors.foreground = opaqueHex(parseColor(theme.text))
    colors["cursor-color"] = opaqueHex(parseColor(theme.focus))
    colors["cursor-text"] = opaqueHex(parseColor(theme.primaryText))
    var selection = parseColor(theme.selection)
    colors["selection-background"] = opaqueHex(selection.a === 255 ? selection : composite(selection, parseColor(theme.background)))
    colors["selection-foreground"] = opaqueHex(parseColor(theme.selectionText))
    return colors
}

function transform(text, colors) {
    var counts = {}
    var assignment = /^([\t ]*)(palette|background|foreground|cursor-color|cursor-text|selection-background|selection-foreground)([\t ]*=[\t ]*)(?:(\d+)([\t ]*=[\t ]*))?(#[0-9a-fA-F]{6})([\t ]*(?:#[^\r\n]*)?)(\r?)$/gm
    var candidate = /^[\t ]*(palette|background|foreground|cursor-color|cursor-text|selection-background|selection-foreground)[\t ]*=/gm
    var candidateCount = 0
    while (candidate.exec(text) !== null)
        candidateCount++

    var output = text.replace(assignment, function(full, indent, key, separator, paletteIndex, paletteSeparator, oldColor, suffix, carriageReturn) {
        var target
        if (key === "palette") {
            if (paletteIndex === undefined || Number(paletteIndex) < 0 || Number(paletteIndex) > 15)
                throw new Error("invalid palette assignment")
            target = "palette:" + Number(paletteIndex)
        } else {
            if (paletteIndex !== undefined)
                throw new Error("invalid " + key + " assignment")
            target = key
        }
        counts[target] = (counts[target] || 0) + 1
        return indent + key + separator + (paletteIndex === undefined ? "" : paletteIndex + paletteSeparator) + colors[target] + suffix + carriageReturn
    })

    var targets = []
    for (var index = 0; index < 16; index++)
        targets.push("palette:" + index)
    targets = targets.concat(dynamicKeys)
    if (candidateCount !== targets.length)
        throw new Error("expected exactly 22 target assignments")
    for (var targetIndex = 0; targetIndex < targets.length; targetIndex++) {
        var target = targets[targetIndex]
        if (counts[target] !== 1)
            throw new Error("missing, duplicate, or malformed assignment: " + target)
    }
    return output
}
