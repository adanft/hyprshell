import QtQuick
import QtTest
import "."

TestCase {
    id: testCase
    name: "ThemeStartupCoordinator"

    property int effectCount: 0
    property bool lastForce: false

    // Built with Qt.createComponent rather than a Loader: the coordinator's
    // root is a QtObject, and Loader.source rejects a non-visual root, so the
    // loader always settled on Loader.Error with a null item, hiding the real
    // error underneath.
    //
    // The coordinator lives in theme/policy/ because every QML file implicitly
    // imports its own directory. While it sat in theme/, loading it pulled in
    // that directory's qmldir, and therefore AppSettings and the Quickshell
    // plugin, which qmltestrunner cannot load.
    property var coordinator: null

    Connections {
        target: testCase.coordinator
        function onSyncRequested(themeId, force) {
            testCase.effectCount += 1
            testCase.lastForce = force
        }
    }

    function initTestCase() {
        const component = Qt.createComponent(Qt.resolvedUrl("../policy/ThemeStartupCoordinator.qml"))
        compare(component.status, Component.Ready, component.errorString())
        coordinator = component.createObject(testCase)
        verify(coordinator !== null)
    }

    function init() {
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
