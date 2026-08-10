//@ pragma UseQApplication

// Proves that a closed overlay is actually destroyed.
//
// This cannot be a qmltestrunner case: OverlayLifecycleLoader is a LazyLoader,
// and qmltestrunner cannot resolve the Quickshell imports. It also cannot be a
// source-text assertion — that is exactly how the bug this covers survived.
// IdleResourceLifecycle asserted the observing Connections block existed, and it
// did; it just never instantiated, because LazyLoader's default property is its
// component and every use site declared its overlay into the same property.
// Nothing observed the item, active was never cleared, and every overlay ever
// opened stayed alive for the life of the shell at roughly 8 MB each.
//
// So this drives the real loader and asserts on loader.item.

import QtQuick
import Quickshell

ShellRoot {
    id: root

    property int stage: 0
    property var firstItem: null

    // Stands in for an overlay: the loader only reads visible and calls these.
    component FakeOverlay: QtObject {
        property bool visible: false

        function open() {
            visible = true;
        }

        function close() {
            visible = false;
        }

        function toggle() {
            visible = !visible;
        }
    }

    function fail(message) {
        console.error(`OVERLAY-LIFECYCLE-HARNESS: ${message}`);
        Qt.quit();
    }

    function require(condition, message) {
        if (!condition)
            fail(message);
        return condition;
    }

    function advance(delay) {
        stageTimer.interval = delay;
        stageTimer.restart();
    }

    OverlayLifecycleLoader {
        id: loader

        FakeOverlay {}
    }

    Timer {
        id: stageTimer
        repeat: false
        onTriggered: root.runStage()
    }

    Component.onCompleted: {
        loader.open();
        advance(120);
    }

    function runStage() {
        if (root.stage === 0) {
            if (!root.require(loader.item !== null, "open did not load an item"))
                return;
            if (!root.require(loader.item.visible, "open did not show the item"))
                return;
            root.firstItem = loader.item;
            loader.close();
            root.stage = 1;
            root.advance(120);
        } else if (root.stage === 1) {
            // The regression this harness exists for.
            if (!root.require(loader.item === null, "a closed overlay was not destroyed"))
                return;
            if (!root.require(!loader.requestedVisible, "close left requestedVisible set"))
                return;
            loader.open();
            root.stage = 2;
            root.advance(120);
        } else if (root.stage === 2) {
            if (!root.require(loader.item !== null, "reopening did not load an item"))
                return;
            // A fresh object, not the first one handed back: proof the teardown
            // was real rather than the same instance being reused.
            if (!root.require(loader.item !== root.firstItem, "reopening reused the destroyed item"))
                return;

            // An overlay that closes itself, which is what Escape does. The
            // loader has to notice on its own, without a close() call.
            loader.item.visible = false;
            root.stage = 3;
            root.advance(120);
        } else {
            if (!root.require(loader.item === null, "an overlay that closed itself was not destroyed"))
                return;
            if (!root.require(!loader.requestedVisible, "a self-closed overlay left requestedVisible set"))
                return;
            console.info("OVERLAY-LIFECYCLE-HARNESS: close/reopen/self-close all destroy the item");
            Qt.quit();
        }
    }
}
