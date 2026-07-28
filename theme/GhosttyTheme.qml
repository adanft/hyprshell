pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "GhosttyThemeTransform.js" as GhosttyTransform

QtObject {
    id: ghosttyTheme

    readonly property string configDirectory: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string configFile: configDirectory + "/ghostty/config.ghostty"

    property var pendingTheme: null
    property bool busy: false
    property int lastLoadError: FileViewError.Success

    readonly property var configView: FileView {
        path: ghosttyTheme.configFile
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onLoadFailed: error => ghosttyTheme.lastLoadError = error
        onSaved: {
            ghosttyTheme.reload()
            ghosttyTheme.finish()
        }
        onSaveFailed: error => {
            console.warn(`Failed to save Ghostty theme: ${error}`)
            ghosttyTheme.finish()
        }
    }

    function sync(themeId) {
        pendingTheme = themeId
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
        pendingTheme = null
        ensureConfigDir(theme)
    }

    function ensureConfigDir(theme) {
        const configDirectory = configFile.substring(0, configFile.lastIndexOf("/"))
        const mkdir = mkdirComponent.createObject(ghosttyTheme)
        mkdir.onExited.connect(function (exitCode) {
            mkdir.destroy()
            if (exitCode !== 0) {
                console.warn(`Failed to create Ghostty config directory: ${configDirectory}`)
                finish()
                return
            }
            synchronize(theme)
        })
        mkdir.exec(["mkdir", "-p", "--", configDirectory])
    }

    function synchronize(theme) {
        try {
            lastLoadError = FileViewError.Success
            configView.reload()
            const loaded = configView.waitForJob()
            if (!loaded && lastLoadError !== FileViewError.FileNotFound)
                throw new Error("config file could not be loaded")
            const currentText = loaded ? configView.text() : ""
            const nextText = GhosttyTransform.transform(currentText, theme)
            if (nextText === currentText) {
                reload()
                finish()
                return
            }
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

    function reload() {
        const process = reloadProcessComponent.createObject(ghosttyTheme)
        process.onExited.connect(function (exitCode) {
            if (exitCode !== 0)
                console.warn(`Failed to reload Ghostty after theme synchronization (exit ${exitCode})`)
            process.destroy()
        })
        process.exec(["gapplication", "action", "com.mitchellh.ghostty", "reload-config"])
    }

    readonly property Component reloadProcessComponent: Component {
        Process {}
    }
    readonly property Component mkdirComponent: Component {
        Process {}
    }
}
