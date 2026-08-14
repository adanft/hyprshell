//@ pragma UseQApplication

// Proves that the overlays a person actually opens, open.
//
// Two things already look like they cover this and neither does.
//
// smoketest.qml instantiates all five directly. That compiles them, which is
// what it is for, and it is not how they are reached: shell.qml puts every one
// behind an OverlayLifecycleLoader and opens it through OverlayArbiter, so the
// path with the lazy activation, the arbiter's displacement and the panel's own
// open() in it is the one path the suite never runs.
//
// overlay-lifecycle-harness.qml does drive the real loader, but against a
// seven-line FakeOverlay. It proves the loader honours its contract. It cannot
// say whether any real panel does.
//
// Between them, no test has ever opened a real overlay. This one does, through
// the real arbiter, and holds the invariant the arbiter exists for: exactly one
// overlay alive at a time, and a displaced one destroyed rather than hidden.
// Hidden is the failure that costs memory instead of pixels, which is why the
// count is asserted rather than the visibility.
//
//     qs -p panel-interaction-harness.qml

import QtQuick
import Quickshell
import "features/applauncher" as Applauncher
import "features/powermenu" as Powermenu
import "features/screenshot" as Screenshot
import "features/themeselector" as Themeselector
import "features/wallpaperselector" as Wallpaperselector

ShellRoot {
    id: root

    // Long enough for the loader's Qt.callLater dispatch, the panel's own
    // open(), and the compositor to map the surface. The nested compositor the
    // isolated suite runs against is slower than a real one, and a settle too
    // short reads as "the panel never opened".
    readonly property int settleMs: 200

    property int phase: 0
    property int index: -1
    property var firstLauncherItem: null

    readonly property var panels: [
        { name: "AppLauncher", loader: appLauncherLoader },
        { name: "PowerMenu", loader: powerMenuLoader },
        { name: "WallpaperSelector", loader: wallpaperSelectorLoader },
        { name: "ThemeSelector", loader: themeSelectorLoader },
        { name: "ScreenshotTool", loader: screenshotToolLoader }
    ]

    // The same list shell.qml hands the arbiter, in the same order.
    OverlayArbiter {
        id: arbiter

        loaders: [appLauncherLoader, powerMenuLoader, wallpaperSelectorLoader, themeSelectorLoader, screenshotToolLoader]
    }

    OverlayLifecycleLoader {
        id: appLauncherLoader

        Applauncher.AppLauncher {}
    }
    OverlayLifecycleLoader {
        id: powerMenuLoader

        Powermenu.PowerMenu {}
    }
    OverlayLifecycleLoader {
        id: wallpaperSelectorLoader

        Wallpaperselector.WallpaperSelector {}
    }
    OverlayLifecycleLoader {
        id: themeSelectorLoader

        Themeselector.ThemeSelector {}
    }
    OverlayLifecycleLoader {
        id: screenshotToolLoader

        Screenshot.ScreenshotTool {}
    }

    function fail(message) {
        console.error(`PANEL-INTERACTION-HARNESS: ${message}`);
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

    function loadedNames() {
        return root.panels.filter(entry => entry.loader.item !== null).map(entry => entry.name);
    }

    Timer {
        id: stageTimer

        repeat: false
        onTriggered: root.runStage()
    }

    Component.onCompleted: root.advance(root.settleMs)

    function runStage() {
        if (root.phase === 0) {
            // Verify the overlay opened by the previous pass, then open the
            // next. Checking one pass late is what makes the displacement
            // assertion free: by the time a panel is verified, opening it has
            // already had to destroy the one before it.
            if (root.index >= 0) {
                const current = root.panels[root.index];
                if (!root.require(current.loader.item !== null, `${current.name} loaded nothing when opened`))
                    return;
                if (!root.require(current.loader.item.visible, `${current.name} loaded but never became visible`))
                    return;

                const loaded = root.loadedNames();
                if (!root.require(loaded.length === 1,
                                  `opening ${current.name} left ${loaded.length} overlays alive: ${loaded.join(", ")}`))
                    return;

                if (root.index === 0)
                    root.firstLauncherItem = current.loader.item;
            }

            root.index++;
            if (root.index < root.panels.length) {
                arbiter.open(root.panels[root.index].loader);
                root.advance(root.settleMs);
                return;
            }

            arbiter.closeOthers(null);
            root.phase = 1;
            root.advance(root.settleMs);
        } else if (root.phase === 1) {
            const loaded = root.loadedNames();
            if (!root.require(loaded.length === 0, `closing every overlay left ${loaded.join(", ")} alive`))
                return;

            arbiter.open(appLauncherLoader);
            root.phase = 2;
            root.advance(root.settleMs);
        } else if (root.phase === 2) {
            if (!root.require(appLauncherLoader.item !== null, "reopening the launcher loaded nothing"))
                return;
            // A different object than the first run handed back. Same-instance
            // reuse would mean the first close hid the panel instead of
            // destroying it, which is the leak this whole file is watching for.
            if (!root.require(appLauncherLoader.item !== root.firstLauncherItem,
                              "reopening the launcher reused the destroyed instance"))
                return;

            // Through toggle rather than close: it is the entry point every
            // IpcHandler in shell.qml actually calls, and its closing half took
            // a different branch than close() until it did not.
            arbiter.toggle(appLauncherLoader);
            root.phase = 3;
            root.advance(root.settleMs);
        } else {
            const loaded = root.loadedNames();
            if (!root.require(loaded.length === 0, `a toggled-closed overlay stayed alive: ${loaded.join(", ")}`))
                return;

            // The count goes in a separate line: the wrapper greps this one
            // literally, and a message that carries the number would have to be
            // edited in two files every time an overlay is added.
            console.info(`PANEL-INTERACTION-HARNESS: overlays exercised: ${root.panels.length}`);
            console.info("PANEL-INTERACTION-HARNESS: open/displace/close/reopen passed");
            Qt.quit();
        }
    }
}
