import QtQuick
import QtTest
import "."

TestCase {
    name: "ThemeStartupCoordinator"

    property int effectCount: 0
    property bool lastForce: false

    Loader {
        id: loader
        source: Qt.resolvedUrl("../ThemeStartupCoordinator.qml")
        onStatusChanged: console.warn("coordinator loader", status, loader.item, loader.source)
    }
    property var coordinator: loader.item
    Connections {
        target: loader.item
        function onSyncRequested(themeId, force) {
            effectCount += 1
            lastForce = force
        }
    }

    function initTestCase() {
        wait(100)
        verify(loader.item !== null)
    }

    function init() {
        verify(loader.item !== null)
        effectCount = 0
        lastForce = false
        coordinator.settingsReady = false
        coordinator.themeSourceReady = false
        coordinator.pendingForce = false
    }

    function test_readinessOrderAndSettledFailure() {
        coordinator.themeSourceReady = true
        compare(effectCount, 0)
        coordinator.settingsReady = true
        compare(effectCount, 1)
        coordinator.settingsReady = false
        coordinator.themeSourceReady = false
        coordinator.settingsReady = true
        coordinator.themeSourceReady = true
        compare(effectCount, 2)
    }

    function test_changesBeforeReadyAndRealChange() {
        coordinator.currentTheme = "gruvbox"
        compare(effectCount, 0)
        coordinator.settingsReady = true
        coordinator.themeSourceReady = true
        compare(effectCount, 1)
        coordinator.currentTheme = "tokyo-night"
        compare(effectCount, 2)
    }

    function test_repeatedReadinessAndExplicitForce() {
        coordinator.settingsReady = true
        coordinator.themeSourceReady = true
        compare(effectCount, 1)
        coordinator.settingsReady = true
        coordinator.themeSourceReady = true
        compare(effectCount, 1)
        coordinator.request(true)
        compare(effectCount, 2)
        compare(lastForce, true)
    }
}
