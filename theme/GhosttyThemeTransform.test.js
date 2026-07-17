const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")

const source = fs.readFileSync(`${__dirname}/GhosttyThemeTransform.js`, "utf8")
const transform = {}
vm.createContext(transform)
vm.runInContext(source, transform)

const theme = {
    surfaceInverse: "#010203", danger: "#110000", success: "#002200", warning: "#333300",
    info: "#000044", primary: "#550055", secondary: "#006666", textMuted: "#777777",
    borderStrong: "#888888", critical: "#990000", link: "#0000aa", focus: "#bb00bb",
    text: "#cccccc", background: "#102030", primaryText: "#dddddd",
    selection: "#80ffffff", selectionText: "#eeeeee"
}
const colors = transform.colorsForTheme(theme)
assert.equal(colors["selection-background"], "#889098", "alpha selection is composited over background")

function fixture(eol = "\n", finalNewline = true) {
    const lines = []
    for (let index = 15; index >= 0; index--)
        lines.push(`  palette\t= ${index} = #ABCDEF  # palette ${index}`)
    for (const key of ["foreground", "background", "selection-foreground", "cursor-text", "cursor-color", "selection-background"])
        lines.push(`${key} = #123456`)
    lines.push("font-family = Keep This #ABCDEF")
    return lines.join(eol) + (finalNewline ? eol : "")
}

for (const input of [fixture(), fixture("\r\n"), fixture("\n", false)]) {
    const output = transform.transform(input, colors)
    const stripColors = text => text.replace(/#[0-9a-fA-F]{6}/g, "#COLOR")
    assert.equal(stripColors(output), stripColors(input), "all non-color bytes are preserved")
    assert.equal(output.includes("#ABCDEF  # palette 15"), false)
    assert.equal(output.includes("font-family = Keep This #ABCDEF"), true)
}

const valid = fixture()
assert.throws(() => transform.transform(valid.replace(/^.*palette.*0.*\n/m, ""), colors), /22|palette:0/)
assert.throws(() => transform.transform(valid.replace(/(.*palette.*0.*\n)/, "$1$1"), colors), /22|palette:0/)
assert.throws(() => transform.transform(valid.replace("palette\t= 0 = #ABCDEF", "palette = 0 = nope"), colors), /22|palette:0/)
assert.throws(() => transform.transform(valid.replace("background = #123456", "background = #12345g"), colors), /22|background/)

const themes = JSON.parse(fs.readFileSync(`${__dirname}/themes.json`, "utf8"))
assert.equal(Object.keys(themes).length, 12)
for (const [name, data] of Object.entries(themes)) {
    const mapping = transform.colorsForTheme(data)
    assert.equal(Object.keys(mapping).length, 22, `${name} has 22 Ghostty colors`)
    for (const color of Object.values(mapping))
        assert.match(color, /^#[0-9a-f]{6}$/, `${name} emits opaque lowercase colors`)
}

console.log("GhosttyThemeTransform: all fixtures and 12 themes passed")
