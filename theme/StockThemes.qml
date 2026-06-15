pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: stockThemes

    property var themes: fallbackThemes
    property string currentTheme: defaultName()

    readonly property string sourceFile: `${Quickshell.shellDir}/theme/themes.json`
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string configFile: `${configDir}/qscomponents/theme.json`
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
            textInverse: "#11111b",
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
            notification: "#f9e2af",
            notificationBadge: "#f38ba8",
            bluetooth: "#f5c2e7",
            network: "#89b4fa",
            wifiConnected: "#89b4fa",
            wifiDisconnected: "#f38ba8",
            backlight: "#f9e2af",
            workspaceActive: "#cba6f7",
            workspaceUrgent: "#f38ba8",
            workspaceRemote: "#89b4fa",
            workspaceHover: "#94e2d5",
            workspaceOccupied: "#7f849c",
            workspaceEmpty: "#45475a",
            powerPerformance: "#f38ba8",
            powerSaver: "#a6e3a1",
            powerBalanced: "#89b4fa",
            powerLock: "#fab387",
            audioOutput: "#b4befe",
            audioInput: "#f2cdcd",
            wallpaperSelected: "#f5c2e7",
            previewColors: ["#cba6f7", "#94e2d5", "#89b4fa", "#a6e3a1", "#f9e2af", "#f38ba8"]
        }
    })

    onThemesChanged: loadThemeConfig()

    readonly property var sourceView: FileView {
        path: stockThemes.sourceFile
        printErrors: false
        watchChanges: true
        onLoaded: stockThemes.load()
        onLoadFailed: stockThemes.themes = stockThemes.fallbackThemes
        onFileChanged: reload()
    }

    readonly property var themeConfigFile: FileView {
        id: themeConfigFile

        path: stockThemes.configFile
        printErrors: false
        watchChanges: true
        onLoaded: stockThemes.loadThemeConfig()
        onFileChanged: reload()

        JsonAdapter {
            id: themeConfig

            property string currentTheme: ""
        }
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
        if (nextTheme === currentTheme)
            return false

        currentTheme = nextTheme
        persistTheme()
        return true
    }

    function loadThemeConfig() {
        currentTheme = normalizeName(themeConfig.currentTheme)
    }

    function persistTheme() {
        themeConfig.currentTheme = currentTheme
        Quickshell.execDetached([
            "sh",
            "-c",
            "mkdir -p \"$1\" && printf '{\\n    \"currentTheme\": \"%s\"\\n}\\n' \"$2\" > \"$3\"",
            "sh",
            `${configDir}/qscomponents`,
            currentTheme,
            configFile
        ])
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
