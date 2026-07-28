import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: persistence

    signal loaded(string currentTheme, string currentWallpaper)

    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string configRoot: `${configDir}/qsrice`
    readonly property string configFile: `${configRoot}/settings.json`
    readonly property string legacyFile: `${configDir}/qscomponents/settings.json`
    property bool migrationReady: false
    property bool startupStarted: false

    readonly property var settingsReloadTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: settingsFileView.reload()
    }

    readonly property var settingsFileView: FileView {
        path: persistence.migrationReady ? persistence.configFile : ""
        printErrors: false
        watchChanges: true
        atomicWrites: true
        onLoaded: persistence.deliverLoaded()
        onFileChanged: persistence.scheduleReload()

        JsonAdapter {
            id: settingsConfig

            property string currentTheme: ""
            property string currentWallpaper: ""
        }
    }

    function start() {
        if (startupStarted)
            return
        startupStarted = true
        ensureConfigDir()
    }

    function persist(currentTheme, currentWallpaper) {
        if (settingsConfig.currentTheme === currentTheme && settingsConfig.currentWallpaper === currentWallpaper)
            return false

        settingsConfig.currentTheme = currentTheme
        settingsConfig.currentWallpaper = currentWallpaper
        settingsFileView.writeAdapter()
        return true
    }

    function scheduleReload() {
        settingsReloadTimer.restart()
    }

    function deliverLoaded() {
        loaded(settingsConfig.currentTheme, settingsConfig.currentWallpaper)
    }

    function ensureConfigDir() {
        const mkdir = mkdirComponent.createObject(persistence)
        mkdir.onExited.connect(function (exitCode) {
            mkdir.destroy()
            if (exitCode !== 0)
                return
            const exists = existsComponent.createObject(persistence)
            exists.onExited.connect(function (newExitCode) {
                exists.destroy()
                if (newExitCode === 0) {
                    persistence.migrationReady = true
                    return
                }
                migrateOldSettings()
            })
            exists.exec(["test", "-e", configFile])
        })
        mkdir.exec(["mkdir", "-p", configRoot])
    }

    function migrateOldSettings() {
        const oldExists = oldExistsComponent.createObject(persistence)
        oldExists.onExited.connect(function (exitCode) {
            oldExists.destroy()
            if (exitCode !== 0) {
                persistence.migrationReady = true
                return
            }

            const copy = copyComponent.createObject(persistence)
            copy.onExited.connect(function (copyExitCode) {
                copy.destroy()
                migrationReady = true
            })
            copy.exec(["cp", "-n", "--", legacyFile, configFile])
        })
        oldExists.exec(["test", "-e", legacyFile])
    }

    Component {
        id: mkdirComponent
        Process {}
    }
    Component {
        id: existsComponent
        Process {}
    }
    Component {
        id: oldExistsComponent
        Process {}
    }
    Component {
        id: copyComponent
        Process {}
    }
}
