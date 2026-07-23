pragma Singleton

import QtQuick

Item {
    id: appSettings

    property string currentTheme: ""
    property string currentWallpaper: ""

    Component.onCompleted: persistence.start()

    AppSettingsPersistence {
        id: persistence

        onLoaded: function(nextTheme, nextWallpaper) {
            if (appSettings.currentTheme !== nextTheme)
                appSettings.currentTheme = nextTheme
            if (appSettings.currentWallpaper !== nextWallpaper)
                appSettings.currentWallpaper = nextWallpaper
        }
    }

    function setCurrentTheme(name) {
        if (currentTheme === name)
            return false

        currentTheme = name
        persistence.persist(currentTheme, currentWallpaper)
        return true
    }

    function setCurrentWallpaper(path) {
        if (currentWallpaper === path)
            return false

        currentWallpaper = path
        persistence.persist(currentTheme, currentWallpaper)
        return true
    }
}
