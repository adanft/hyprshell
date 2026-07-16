pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: stockThemes

    property var themes: fallbackThemes
    readonly property string currentTheme: normalizeName(AppSettings.currentTheme)

    readonly property string sourceFile: `${Quickshell.shellDir}/theme/themes.json`
    readonly property var availableThemes: list()
    readonly property var themeData: theme(currentTheme)
    readonly property var fallbackThemes: ({
        "catppuccin": {
            displayName: "Catppuccin Mocha",
            transparent: "transparent",
            mask: "black",
            scrim: "#bf1e1e2e",
            background: "#1e1e2e",
            panel: "#f0181825",
            surface: "#181825",
            surfaceTransparent: "#0011111b",
            surfaceHover: "#45475a",
            surfaceActive: "#313244",
            surfaceInverse: "#11111b",
            border: "#45475a",
            borderStrong: "#7f849c",
            text: "#cdd6f4",
            textMuted: "#bac2de",
            textSubtle: "#7f849c",
            textInactive: "#45475a",
            primary: "#cba6f7",
            primaryText: "#11111b",
            secondary: "#94e2d5",
            focus: "#cba6f7",
            selection: "#cba6f7",
            selectionText: "#11111b",
            info: "#89b4fa",
            link: "#89b4fa",
            success: "#a6e3a1",
            warning: "#f9e2af",
            danger: "#f38ba8",
            critical: "#f38ba8",
            previewColors: ["#cba6f7", "#94e2d5", "#89b4fa", "#a6e3a1", "#f9e2af", "#f38ba8"]
        }
    })

    readonly property var sourceView: FileView {
        path: stockThemes.sourceFile
        printErrors: false
        watchChanges: true
        onLoaded: stockThemes.load()
        onLoadFailed: stockThemes.themes = stockThemes.fallbackThemes
        onFileChanged: reload()
    }

    function defaultName() {
        return "catppuccin"
    }

    function names() {
        return Object.keys(themes)
    }

    function list() {
        return names().map(name => ({
            name,
            displayName: themes[name].displayName,
            primary: themes[name].primary,
            secondary: themes[name].secondary,
            previewColors: themes[name].previewColors,
            background: themes[name].background,
            surface: themes[name].surface,
            surfaceActive: themes[name].surfaceActive,
            border: themes[name].border,
            focus: themes[name].focus,
            text: themes[name].text
        }))
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
            const parsedThemes = JSON.parse(sourceView.text())
            if (!parsedThemes || !parsedThemes[defaultName()])
                throw new Error("themes.json must include catppuccin")

            themes = parsedThemes
        } catch (error) {
            console.warn(`Failed to load stock themes from ${sourceFile}: ${error}`)
            themes = fallbackThemes
        }
    }
}
