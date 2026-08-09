pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "GhosttyThemeTransform.js" as GhosttyTransform
import "ThemeSyncState.js" as ThemeSyncState

QtObject {
    id: ghosttyTheme

    readonly property string configDirectory: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string configFile: configDirectory + "/ghostty/config.ghostty"

    property var pendingTheme: null
    property bool pendingForce: false
    property bool busy: false
    property int lastLoadError: FileViewError.Success
    property var reloadState: ThemeSyncState.createGhosttyState()
    property bool pendingReloadForce: false

    readonly property var configView: FileView {
        path: ghosttyTheme.configFile
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onLoadFailed: error => ghosttyTheme.lastLoadError = error
        onSaved: {
            ghosttyTheme.reload(ghosttyTheme.pendingReloadForce)
            ghosttyTheme.pendingReloadForce = false
            ghosttyTheme.finish()
        }
        onSaveFailed: error => {
            console.warn(`Failed to save Ghostty theme: ${error}`)
            ghosttyTheme.finish()
        }
    }

    function sync(themeId, force) {
        pendingTheme = themeId
        pendingForce = pendingForce || Boolean(force)

        if (!busy)
            processNext()
    }

    function processNext() {
        if (!pendingTheme) {
            busy = false
            return
        }

        busy = true
        const theme = pendingTheme
        const force = pendingForce
        pendingTheme = null
        pendingForce = false
        ensureConfigDir(theme, force)
    }

    function ensureConfigDir(theme, force) {
        const configDirectory = configFile.substring(0, configFile.lastIndexOf("/"))
        let mkdir
        try {
            mkdir = mkdirComponent.createObject(ghosttyTheme)
            if (!mkdir)
                throw new Error("process creation returned null")
            mkdir.onExited.connect(function (exitCode) {
                mkdir.destroy()
                if (exitCode !== 0)
                    console.warn(`Failed to create Ghostty config directory: ${configDirectory}`)
                if (exitCode !== 0)
                    return finish()
                synchronize(theme, force)
            })
            mkdir.exec(["mkdir", "-p", "--", configDirectory])
        } catch (error) {
            if (mkdir)
                mkdir.destroy()
            console.warn(`Failed to start Ghostty config directory process: ${error}`)
            finish()
        }
    }

    function synchronize(theme, force) {
        try {
            lastLoadError = FileViewError.Success
            configView.reload()
            const loaded = configView.waitForJob()
            if (!loaded && lastLoadError !== FileViewError.FileNotFound)
                throw new Error("config file could not be loaded")
            const currentText = loaded ? configView.text() : ""
            const nextText = GhosttyTransform.transform(currentText, theme)
            if (!ThemeSyncState.ghosttyNeedsReload(nextText !== currentText, force)) {
                finish()
                return
            }
            pendingReloadForce = force
            configView.setText(nextText)
        } catch (error) {
            console.warn(`Failed to synchronize Ghostty theme: ${error}`)
            finish()
        }
    }

    function finish() {
        busy = false
        if (pendingTheme)
            processNext()
    }

    function reload(force) {
        const decision = ThemeSyncState.requestGhostty(reloadState, force)
        if (decision.action !== "start")
            return
        startReload(decision.force)
    }

    function startReload(force) {
        try {
            const process = reloadProcessComponent.createObject(ghosttyTheme)
            if (!process)
                throw new Error("process creation returned null")
            process.onExited.connect(function (exitCode) {
                const next = ThemeSyncState.finishGhostty(reloadState, exitCode === 0)
                if (exitCode !== 0)
                    console.warn(`Failed to reload Ghostty after theme synchronization (exit ${exitCode})`)
                process.destroy()
                if (next.action === "start")
                    startReload(next.force)
            })
            process.exec(["gapplication", "action", "com.mitchellh.ghostty", "reload-config"])
        } catch (error) {
            const next = ThemeSyncState.finishGhostty(reloadState, false)
            console.warn(`Failed to start Ghostty reload process: ${error}`)
            if (next.action === "start")
                startReload(next.force)
        }
    }

    readonly property Component reloadProcessComponent: Component {
        Process {}
    }
    readonly property Component mkdirComponent: Component {
        Process {}
    }
}
