pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: appSettings

    property string currentTheme: ""
    property string currentWallpaper: ""

    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string configFile: `${configDir}/qsrice/settings.json`
    readonly property string configRoot: `${configDir}/qsrice`
    property bool migrationReady: false

    Component.onCompleted: ensureConfigDir()

    readonly property var settingsReloadTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: settingsFileView.reload()
    }

    readonly property var settingsFileView: FileView {
        path: appSettings.migrationReady ? appSettings.configFile : ""
        printErrors: false
        watchChanges: true
        atomicWrites: true
        onLoaded: appSettings.load()
        onFileChanged: appSettings.scheduleReload()

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

    function scheduleReload() {
        settingsReloadTimer.restart()
    }

    function load() {
        const nextTheme = settingsConfig.currentTheme
        const nextWallpaper = settingsConfig.currentWallpaper

        if (currentTheme !== nextTheme)
            currentTheme = nextTheme
        if (currentWallpaper !== nextWallpaper)
            currentWallpaper = nextWallpaper
    }

    function persist() {
        if (settingsConfig.currentTheme === currentTheme && settingsConfig.currentWallpaper === currentWallpaper)
            return false

        settingsConfig.currentTheme = currentTheme
        settingsConfig.currentWallpaper = currentWallpaper
        settingsFileView.writeAdapter()
        return true
    }

    function ensureConfigDir() {
        const mkdir = mkdirComponent.createObject(appSettings)
        mkdir.onExited.connect(function(exitCode) {
            mkdir.destroy()
            if (exitCode !== 0)
                return

            const exists = existsComponent.createObject(appSettings)
            exists.onExited.connect(function(newExitCode) {
                exists.destroy()
                if (newExitCode === 0) {
                    appSettings.migrationReady = true
                    return
                }
                migrateOldSettings()
            })
            exists.exec(["test", "-e", configFile])
        })
        mkdir.exec(["mkdir", "-p", configRoot])
    }

    function migrateOldSettings() {
        const oldFile = `${configDir}/qscomponents/settings.json`
        const oldExists = oldExistsComponent.createObject(appSettings)
        oldExists.onExited.connect(function(exitCode) {
            oldExists.destroy()
            if (exitCode !== 0) {
                appSettings.migrationReady = true
                return
            }

            const copy = copyComponent.createObject(appSettings)
            copy.onExited.connect(function(copyExitCode) {
                copy.destroy()
                migrationReady = true
            })
            copy.exec(["cp", "-n", "--", oldFile, configFile])
        })
        oldExists.exec(["test", "-e", oldFile])
    }

    Component { id: mkdirComponent; Process {} }
    Component { id: existsComponent; Process {} }
    Component { id: oldExistsComponent; Process {} }
    Component { id: copyComponent; Process {} }
}
