pragma Singleton

import "policy"
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import "HyprlandThemeCommand.js" as HyprlandThemeCommand
import ".."
import "../PaletteRoles.js" as PaletteRoles
import "ThemeSyncState.js" as ThemeSyncState

QtObject {
    id: stockThemes

    property var themes: fallbackThemes
    readonly property string currentTheme: normalizeName(AppSettings.currentTheme)
    property var pendingHyprlandTheme: null
    property bool hyprlandSyncBusy: false
    property var hyprlandState: ThemeSyncState.createHyprlandState()
    property bool externalThemeSyncReady: false

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

    readonly property var externalThemeSyncTimer: Timer {
        interval: 0
        repeat: false
        onTriggered: startupCoordinator.request(false)
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
        externalThemeSyncReady = true
        startupCoordinator.request(force)
    }

        function syncExternalTheme(themeId, force) {
        const normalizedTheme = normalizeName(themeId)
        const nextTheme = theme(normalizedTheme)
        GhosttyTheme.sync(normalizedTheme, force)
        syncHyprlandTheme(nextTheme, force)
    }

        function syncHyprlandTheme(nextTheme, force) {
        const decision = ThemeSyncState.requestHyprland(hyprlandState, nextTheme, force)
        if (decision.action !== "start")
        return
        startHyprlandTheme(decision.request)
    }

        function startHyprlandTheme(request) {
        let processArgs
        try {
        processArgs = HyprlandThemeCommand.processArguments(request.theme)
    } catch (error) {
        hyprlandState.busy = false
        hyprlandState.pending = null
        console.warn(`Failed to build Hyprland theme command: ${error}`)
        return
    }
        hyprlandSyncBusy = true
        let process
        try {
        process = hyprlandProcessComponent.createObject(stockThemes)
    } catch (error) {
        const next = ThemeSyncState.finishHyprland(hyprlandState, request.signature, false)
        hyprlandSyncBusy = hyprlandState.busy
        console.warn(`Failed to create Hyprland theme process: ${error}`)
        if (next.action === "start")
        startHyprlandTheme(next.request)
        return
    }
        if (!process) {
        const next = ThemeSyncState.finishHyprland(hyprlandState, request.signature, false)
        hyprlandSyncBusy = hyprlandState.busy
        console.warn("Failed to create Hyprland theme process")
        if (next.action === "start")
        startHyprlandTheme(next.request)
        return
    }
        process.onExited.connect(function (exitCode) {
        const next = ThemeSyncState.finishHyprland(hyprlandState, request.signature, exitCode === 0)
        if (exitCode !== 0)
        console.warn(`Failed to apply Hyprland theme (exit ${exitCode})`)
        process.destroy()
        hyprlandSyncBusy = hyprlandState.busy
        if (next.action === "start")
        startHyprlandTheme(next.request)
    })
        try {
        process.exec(processArgs)
    } catch (error) {
        const next = ThemeSyncState.finishHyprland(hyprlandState, request.signature, false)
        process.destroy()
        hyprlandSyncBusy = hyprlandState.busy
        console.warn(`Failed to start Hyprland theme process: ${error}`)
        if (next.action === "start")
        startHyprlandTheme(next.request)
    }
    }

        readonly property Component hyprlandProcessComponent: Component {
        Process {}
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
