import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: persistence

    signal loaded(string currentTheme, string currentWallpaper)
    signal startupSettled

    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string configRoot: `${configDir}/hyprshell`
    readonly property string configFile: `${configRoot}/settings.json`
    property bool configDirReady: false
    property bool startupStarted: false
    property bool startupSettledEmitted: false
    readonly property bool ready: configDirReady && startupSettledEmitted

    readonly property var settingsReloadTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: settingsFileView.reload()
    }

    readonly property var settingsFileView: FileView {
        path: persistence.configDirReady ? persistence.configFile : ""
        printErrors: false
        watchChanges: true
        atomicWrites: true
        onLoaded: persistence.deliverLoaded()
        onLoadFailed: error => persistence.deliverLoadFailed(error)
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
        if (!ready)
            return false
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
        settleStartup()
    }

    function deliverLoadFailed(error) {
        if (error === FileViewError.FileNotFound)
            loaded(settingsConfig.currentTheme, settingsConfig.currentWallpaper)
        settleStartup()
    }

    function settleStartup() {
        if (startupSettledEmitted)
            return
        startupSettledEmitted = true
        startupSettled()
    }

    // Make the directory and say so. There is nothing else to wait for: a
    // settings file that is not there yet reaches the view as FileNotFound,
    // which the load-failure path already treats as "use the defaults".
    //
    // This used to also look for a file under the shell's earlier names and copy
    // it forward. That is gone deliberately, along with the names: one directory
    // is the whole story now, and a migration chain is a thing that has to be
    // extended and guarded at every rename forever. Removing it is why the
    // three lists that had to be kept in step with each other went too.
    function ensureConfigDir() {
        const mkdir = mkdirComponent.createObject(persistence)
        mkdir.onExited.connect(function (exitCode) {
            mkdir.destroy()
            if (exitCode !== 0) {
                persistence.settleStartup()
                return
            }
            persistence.configDirReady = true
        })
        mkdir.exec(["mkdir", "-p", configRoot])
    }

    Component {
        id: mkdirComponent
        Process {}
    }
}
