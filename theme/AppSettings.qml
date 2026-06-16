pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: appSettings

    property string currentTheme: ""
    property string currentWallpaper: ""

    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string configFile: `${configDir}/qscomponents/settings.json`

    Component.onCompleted: ensureConfigDir()

    readonly property var settingsFileView: FileView {
        path: appSettings.configFile
        printErrors: false
        watchChanges: true
        atomicWrites: true
        onLoaded: appSettings.load()
        onFileChanged: reload()

        JsonAdapter {
            id: settingsConfig

            property string currentTheme: ""
            property string currentWallpaper: ""
        }
    }

    function setCurrentTheme(name) {
        if (currentTheme === name)
            return false

        currentTheme = name
        persist()
        return true
    }

    function setCurrentWallpaper(path) {
        if (currentWallpaper === path)
            return false

        currentWallpaper = path
        persist()
        return true
    }

    function load() {
        currentTheme = settingsConfig.currentTheme
        currentWallpaper = settingsConfig.currentWallpaper
    }

    function persist() {
        settingsConfig.currentTheme = currentTheme
        settingsConfig.currentWallpaper = currentWallpaper
        settingsFileView.writeAdapter()
    }

    function ensureConfigDir() {
        Quickshell.execDetached(["mkdir", "-p", `${configDir}/qscomponents`])
    }
}
