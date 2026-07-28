pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import "HyprlandThemeCommand.js" as HyprlandThemeCommand
import "ThemeSyncState.js" as ThemeSyncState

QtObject {
    id: stockThemes

    property var themes: fallbackThemes
    readonly property string currentTheme: normalizeName(AppSettings.currentTheme)
    property var pendingHyprlandTheme: null
    property bool hyprlandSyncBusy: false
    property var hyprlandState: ThemeSyncState.createHyprlandState()
    property bool externalThemeSyncReady: false

    readonly property string sourceFile: `${Quickshell.shellDir}/theme/themes.json`
    readonly property var availableThemes: list()
    readonly property var themeData: theme(currentTheme)
    readonly property var fallbackThemes: ({
                                               "catppuccin": {
                                                   displayName: "Catppuccin",
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
                                                   previewColors: ["#cba6f7", "#94e2d5", "#89b4fa", "#a6e3a1", "#f9e2af",
                                                       "#f38ba8"]
                                               }
                                           })

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

    Component.onCompleted: startupCoordinator.request(false)
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
