pragma Singleton

import QtQuick

Item {
    id: appSettings

    property string currentTheme: ""
    property string currentWallpaper: ""
    property bool startupReady: false
    property bool startupThemeChanged: false
    property bool startupWallpaperChanged: false

    Component.onCompleted: persistence.start()

    AppSettingsPersistence {
        id: persistence

        onStartupSettled: {
            appSettings.startupReady = true
            if (appSettings.startupThemeChanged || appSettings.startupWallpaperChanged)
                persistence.persist(appSettings.currentTheme, appSettings.currentWallpaper)
        }

        onLoaded: function (nextTheme, nextWallpaper) {
            if (!appSettings.startupThemeChanged && appSettings.currentTheme !== nextTheme)
                appSettings.currentTheme = nextTheme
            if (!appSettings.startupWallpaperChanged && appSettings.currentWallpaper !== nextWallpaper)
                appSettings.currentWallpaper = nextWallpaper
        }
    }

    function setCurrentTheme(name) {
        if (currentTheme === name)
            return false

        currentTheme = name
        if (startupReady)
            persistence.persist(currentTheme, currentWallpaper)
        else
            startupThemeChanged = true
        return true
    }

    function setCurrentWallpaper(path) {
        if (currentWallpaper === path)
            return false

        currentWallpaper = path
        if (startupReady)
            persistence.persist(currentTheme, currentWallpaper)
        else
            startupWallpaperChanged = true
        return true
    }
}
