pragma Singleton

import "policy"
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
    // every component that reads a colour loadable outside the shell runtime.
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
        onLoaded: {
            stockThemes.load()
            stockThemes.startupCoordinator.themeSourceReady = true
        }
        onLoadFailed: {
            stockThemes.themes = stockThemes.fallbackThemes
            stockThemes.startupCoordinator.themeSourceReady = true
        }
        onFileChanged: reload()
    }

    Component.onCompleted: {
        Colors.palette = themeData
        startupCoordinator.request(false)
    }
    readonly property var startupCoordinator: ThemeStartupCoordinator {
        currentTheme: stockThemes.currentTheme
        settingsReady: AppSettings.startupReady
        onSyncRequested: function (themeId, force) {
            stockThemes.syncExternalTheme(themeId, force)
        }
    }

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
        const changed = AppSettings.setCurrentTheme(nextTheme)
        if (!changed)
        scheduleExternalThemeSync(true)
        return changed
    }

        function scheduleExternalThemeSync(force) {
        startupCoordinator.request(force)
    }

        function syncExternalTheme(themeId, force) {
        const normalizedTheme = normalizeName(themeId)
        const nextTheme = theme(normalizedTheme)
        GhosttyTheme.sync(normalizedTheme, force)
        syncHyprTheme(nextTheme)
    }

        function syncHyprTheme(nextTheme) {
        HyprTheme.sync(nextTheme, AppSettings.currentWallpaper, AppTheme.typography.textFontFamily)
    }

    // theme.conf carries the wallpaper as well as the palette, because the lock
    // screen shows both. A wallpaper is picked without touching the theme, so
    // waiting for a theme change would leave the lock screen on the last
    // wallpaper the theme happened to be changed under.
    readonly property var wallpaperFollows: Connections {
        target: AppSettings
        function onCurrentWallpaperChanged() {
            stockThemes.syncHyprTheme(stockThemes.themeData)
        }
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
