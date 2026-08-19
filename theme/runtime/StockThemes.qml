pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import ".."
import "../PaletteRoles.js" as PaletteRoles

QtObject {
    id: stockThemes

    property var themes: fallbackThemes
    readonly property string currentTheme: normalizeName(AppSettings.currentTheme)

    readonly property string sourceFile: `${Quickshell.shellDir}/theme/runtime/themes.json`
    readonly property var availableThemes: list()
    readonly property var themeData: theme(currentTheme)

    // Colors is a plain palette holder with no Quickshell dependency, so the
    // active theme is pushed into it rather than pulled out of here. That keeps
    // every component that reads a color loadable outside the shell runtime.
    onThemeDataChanged: Colors.palette = themeData

    // Themes are exactly 16 roles. PaletteRoles validates them; nothing is
    // derived, so what a layout paints is what a theme authored.
    readonly property var fallbackRoles: ({
        "catppuccin": PaletteRoles.FALLBACK_PALETTE
    })
    readonly property var fallbackThemes: PaletteRoles.readPalettes(fallbackRoles)

    readonly property var sourceView: FileView {
        path: stockThemes.sourceFile
        printErrors: false
        watchChanges: true
        onLoaded: stockThemes.load()
        onLoadFailed: stockThemes.themes = stockThemes.fallbackThemes

        onFileChanged: reload()
    }

    Component.onCompleted: Colors.palette = themeData

    function defaultName() {
        return "catppuccin"
    }

    function names() {
        return Object.keys(themes)
    }

    // A palette is already exactly displayName plus the 16 roles, so the
    // selector gets the whole thing rather than a hand-picked subset that
    // would have to be kept in step with it.
    function list() {
        return names().map(name => Object.assign({
            name
        }, themes[name]))
    }

    function normalizeName(name) {
        const value = String(name || "").trim().toLowerCase()
        return themes[value] ? value : defaultName()
    }

    function theme(name) {
        return themes[normalizeName(name)] || fallbackThemes[defaultName()]
    }

    function setTheme(name) {
        const nextTheme = normalizeName(name)
        return AppSettings.setCurrentTheme(nextTheme)
    }

    function load() {
        try {
            const parsedRoles = JSON.parse(sourceView.text())
            if (!parsedRoles || !parsedRoles[defaultName()])
                throw new Error("themes.json must include catppuccin")

            themes = PaletteRoles.readPalettes(parsedRoles)
        } catch (error) {
            console.warn(`Failed to load stock themes from ${sourceFile}: ${error}`)
            themes = fallbackThemes
        }
    }
}
