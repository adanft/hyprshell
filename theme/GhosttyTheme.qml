pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "GhosttyThemeTransform.js" as GhosttyTransform

QtObject {
    id: ghosttyTheme

    readonly property string configFile: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/ghostty/config.ghostty`
    property var pendingTheme: null
    property bool busy: false

    readonly property var configView: FileView {
        path: ghosttyTheme.configFile
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onSaved: {
            ghosttyTheme.reload()
            ghosttyTheme.finish()
        }
        onSaveFailed: error => {
            console.warn(`Failed to save Ghostty theme: ${error}`)
            ghosttyTheme.finish()
        }
    }

    function sync(theme) {
        pendingTheme = theme
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
        try {
            configView.reload()
            if (!configView.waitForJob())
                throw new Error("config file could not be loaded")
            const colors = GhosttyTransform.colorsForTheme(theme)
            const currentText = configView.text()
            const nextText = GhosttyTransform.transform(currentText, colors)
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
        process.onExited.connect(function(exitCode) {
            if (exitCode !== 0)
                console.warn(`Failed to reload Ghostty after theme synchronization (exit ${exitCode})`)
            process.destroy()
        })
        process.exec(["gapplication", "action", "com.mitchellh.ghostty", "reload-config"])
    }

    readonly property Component reloadProcessComponent: Component { Process {} }
}
