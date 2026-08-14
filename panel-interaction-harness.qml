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

    // Polled rather than scheduled, and the ceiling is a failure report rather
    // than a plan. A fixed settle is a guess about how long a compositor takes
    // to map a surface, and this suite has already paid for that guess once:
    // smoketest.qml checked its results at a fixed three seconds, which held
    // while it ran alone and failed a healthy shell about one run in three once
    // other stages ran ahead of it. A panel that opens in twenty milliseconds is
    // checked in twenty.
    readonly property int pollMs: 25
    readonly property int phaseTimeoutMs: 8000

    // A pause before the next action, which is a different thing from a deadline
    // for an assertion — the pattern this file just stopped using. Every check
    // still polls and still fails only on its own ceiling; this only limits how
    // fast one overlay is allowed to displace the next.
    //
    // It exists because displacing faster than this destroys AppLauncher's
    // content Loader mid-incubation and Qt says so, at AppLauncher.qml:354:
    // "Cannot create delegate" and "Object or context destroyed during
    // incubation". That is reachable by hand — two keybinds in quick succession
    // do it — so it is a real behaviour of the shell, recorded here rather than
    // filtered out of the run. Lower this to see it again.
    readonly property int actionGraceMs: 250

    property int phase: 0
    property int index: -1
    property int waitedMs: 0
    property int graceMs: 0
    property string waitingFor: "the first overlay to open"
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
        // Stopped before reporting rather than left to Qt.quit(), which unwinds
        // the event loop on its own schedule while this timer keeps firing every
        // 25 ms. Measured here, quit wins that race and the error prints once
        // either way — so this is not fixing an observed run of duplicate lines,
        // it is removing the race that decides whether there is one.
        pollTimer.running = false;
        console.error(`PANEL-INTERACTION-HARNESS: ${message}`);
        Qt.quit();
    }

    function require(condition, message) {
        if (!condition)
            fail(message);
        return condition;
    }

    function loadedNames() {
        return root.panels.filter(entry => entry.loader.item !== null).map(entry => entry.name);
    }

    // The arbiter's whole contract in one expression: this loader is up, and it
    // is the only one. The displacement belongs in the wait rather than in a
    // separate assertion after it, because a panel becoming visible and the one
    // before it being destroyed are two events, and asserting between them is a
    // race — which is exactly what a fixed settle hides instead of removing.
    function isSoleVisible(loader) {
        return loader.item !== null && loader.item.visible && root.loadedNames().length === 1;
    }

    function ready() {
        if (root.phase === 0)
            return root.index < 0 || root.isSoleVisible(root.panels[root.index].loader);
        if (root.phase === 2)
            return root.isSoleVisible(appLauncherLoader);
        return root.loadedNames().length === 0;
    }

    Timer {
        id: pollTimer

        interval: root.pollMs
        running: true
        repeat: true
        onTriggered: {
            if (root.ready()) {
                root.graceMs += root.pollMs;
                if (root.graceMs < root.actionGraceMs)
                    return;
                root.graceMs = 0;
                root.waitedMs = 0;
                root.step();
                return;
            }

            root.graceMs = 0;
            root.waitedMs += root.pollMs;
            if (root.waitedMs >= root.phaseTimeoutMs) {
                // Reports the state that never arrived rather than the line that
                // gave up, so a timeout still says whether the panel failed to
                // open or the one before it failed to die.
                const alive = root.loadedNames();
                root.fail(`waited ${root.phaseTimeoutMs}ms for ${root.waitingFor};`
                          + ` alive: [${alive.join(", ")}]`);
            }
        }
    }

    function step() {
        if (root.phase === 0) {
            if (root.index === 0)
                root.firstLauncherItem = root.panels[0].loader.item;

            root.index++;
            if (root.index < root.panels.length) {
                const next = root.panels[root.index];
                root.waitingFor = `${next.name} to be open and alone`;
                arbiter.open(next.loader);
                return;
            }

            root.waitingFor = "every overlay to close";
            arbiter.closeOthers(null);
            root.phase = 1;
            return;
        }

        if (root.phase === 1) {
            root.waitingFor = "the launcher to reopen alone";
            arbiter.open(appLauncherLoader);
            root.phase = 2;
            return;
        }

        if (root.phase === 2) {
            // A different object than the first run handed back. Same-instance
            // reuse would mean the first close hid the panel instead of
            // destroying it, which is the leak this whole file is watching for.
            if (!root.require(appLauncherLoader.item !== root.firstLauncherItem,
                              "reopening the launcher reused the destroyed instance"))
                return;

            // Through toggle rather than close: it is the entry point every
            // IpcHandler in shell.qml actually calls, and its closing half took
            // a different branch than close() until it did not.
            root.waitingFor = "the toggled launcher to close";
            arbiter.toggle(appLauncherLoader);
            root.phase = 3;
            return;
        }

        pollTimer.running = false;

        // The count goes in a separate line: the wrapper greps this one
        // literally, and a message that carries the number would have to be
        // edited in two files every time an overlay is added.
        console.info(`PANEL-INTERACTION-HARNESS: overlays exercised: ${root.panels.length}`);
        console.info("PANEL-INTERACTION-HARNESS: open/displace/close/reopen passed");
        Qt.quit();
    }
}
