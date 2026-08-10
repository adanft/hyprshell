pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "HyprThemeTransform.js" as HyprThemeTransform
import "ThemeSyncState.js" as ThemeSyncState

// theme.conf, and the reload that makes Hyprland read it.
//
// Unlike the Ghostty config this file is not one the user also writes: hyprlock
// sources it and hyprland.lua reads it back, and nothing else touches it. So the
// shell owns every line — there is no marker to find, no surrounding settings to
// keep, nothing to parse back.
//
// Hyprlock needs no signal; it reads its config when it launches, so the next
// lock already has the current theme. Hyprland holds its config in memory and
// has to be told, which is what the reload is for. It is the only live path on
// purpose: a second command setting colours directly would leave the file and
// the command each claiming to be the truth.
QtObject {
    id: hyprTheme

    readonly property string configDirectory: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string configFile: configDirectory + "/hypr/theme.conf"

    property var pendingRequest: null
    property bool busy: false
    property int lastLoadError: FileViewError.Success
    property var reloadState: ThemeSyncState.createHyprlandState()
    // Whether the bytes about to be saved change anything Hyprland reads. Held
    // between the write and the save because onSaved carries no context.
    property bool reloadAfterSave: false

    readonly property var configView: FileView {
        path: hyprTheme.configFile
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onLoadFailed: error => hyprTheme.lastLoadError = error
        onSaved: {
            if (hyprTheme.reloadAfterSave)
                hyprTheme.requestReload()
            hyprTheme.reloadAfterSave = false
            hyprTheme.finish()
        }
        onSaveFailed: error => {
            console.warn(`Failed to save theme.conf: ${error}`)
            hyprTheme.reloadAfterSave = false
            hyprTheme.finish()
        }
    }

    function sync(theme, wallpaper, font) {
        pendingRequest = {
            theme,
            appearance: {
                wallpaper,
                font
            }
        }
        if (!busy)
            processNext()
    }

    function processNext() {
        if (!pendingRequest) {
            busy = false
            return
        }

        busy = true
        const request = pendingRequest
        pendingRequest = null
        ensureConfigDir(request)
    }

    function ensureConfigDir(request) {
        const directory = configFile.substring(0, configFile.lastIndexOf("/"))
        let mkdir
        try {
            mkdir = mkdirComponent.createObject(hyprTheme)
            if (!mkdir)
                throw new Error("process creation returned null")
            mkdir.onExited.connect(function (exitCode) {
                mkdir.destroy()
                if (exitCode !== 0) {
                    console.warn(`Failed to create the hypr config directory: ${directory}`)
                    return finish()
                }
                write(request)
            })
            mkdir.exec(["mkdir", "-p", "--", directory])
        } catch (error) {
            if (mkdir)
                mkdir.destroy()
            console.warn(`Failed to start the hypr config directory process: ${error}`)
            finish()
        }
    }

    function write(request) {
        try {
            lastLoadError = FileViewError.Success
            configView.reload()
            const loaded = configView.waitForJob()
            if (!loaded && lastLoadError !== FileViewError.FileNotFound)
                throw new Error("theme.conf could not be read back")

            const currentText = loaded ? configView.text() : ""
            const nextText = HyprThemeTransform.renderThemeConf(request.theme, request.appearance)
            // Read before writing so an unchanged theme neither rewrites the file
            // nor reloads the compositor for nothing.
            if (nextText === currentText) {
                finish()
                return
            }
            reloadAfterSave = HyprThemeTransform.needsReload(currentText, nextText)
            configView.setText(nextText)
        } catch (error) {
            console.warn(`Failed to write theme.conf: ${error}`)
            finish()
        }
    }

    function finish() {
        busy = false
        if (pendingRequest)
            processNext()
    }

    // The state machine exists to serialise reloads and retry a failed one once.
    // Its signature argument is what tells one request from another, and here
    // every request is the same request — reload — so the file path stands in for
    // it and `force` keeps it from ever being skipped as a repeat.
    function requestReload() {
        const decision = ThemeSyncState.requestHyprland(reloadState, configFile, true)
        if (decision.action !== "start")
            return
        startReload(decision.request)
    }

    function startReload(request) {
        let process
        try {
            process = reloadProcessComponent.createObject(hyprTheme)
            if (!process)
                throw new Error("process creation returned null")
            const processArgs = HyprThemeTransform.reloadArguments()
            process.onExited.connect(function (exitCode) {
                const next = ThemeSyncState.finishHyprland(hyprTheme.reloadState, request.signature, exitCode === 0)
                if (exitCode !== 0)
                    console.warn(`Failed to reload Hyprland after writing theme.conf (exit ${exitCode})`)
                process.destroy()
                if (next.action === "start")
                    hyprTheme.startReload(next.request)
            })
            process.exec(processArgs)
        } catch (error) {
            if (process)
                process.destroy()
            const next = ThemeSyncState.finishHyprland(reloadState, request.signature, false)
            console.warn(`Failed to start the Hyprland reload: ${error}`)
            if (next.action === "start")
                startReload(next.request)
        }
    }

    readonly property Component reloadProcessComponent: Component {
        Process {}
    }
    readonly property Component mkdirComponent: Component {
        Process {}
    }
}
