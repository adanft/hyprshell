import QtQuick

QtObject {
    id: coordinator

    property bool settingsReady: false
    property bool themeSourceReady: false
    property string currentTheme: ""
    property bool pendingForce: false
    signal syncRequested(string themeId, bool force)

    function request(force) {
        if (!settingsReady || !themeSourceReady) {
            pendingForce = pendingForce || Boolean(force)
            return
        }
        const nextForce = pendingForce || Boolean(force)
        pendingForce = false
        syncRequested(currentTheme, nextForce)
    }

    onSettingsReadyChanged: request(false)
    onThemeSourceReadyChanged: request(false)
    onCurrentThemeChanged: request(false)
}
