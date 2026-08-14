//@ pragma UseQApplication

// Covers the two panels that do not open like the other five.
//
// The overlays go through OverlayArbiter and OverlayLifecycleLoader, and
// panel-interaction-harness.qml drives that. These two do not. The control
// centre is opened by a signal that rises BarLayout -> BarContent -> BarWindow
// and lands on a handler inside BarWindow.qml, which toggles its own
// requestedOpen, flips a private LazyLoader and calls open(anchorItem, section)
// on the next tick. The notification centre is a loader with
// directVisibility: true, a branch of OverlayLifecycleLoader that nothing else
// in the suite has ever taken — the lifecycle harness leaves it at its default.
//
// Two things here are real and one is a reconstruction, and the difference
// matters when reading a failure:
//
//   Real: BarWindow's control-centre handler, its private loader, and
//     ControlCenter.open()/close(). The signal is emitted on the actual
//     BarContent instance, so the whole chain below it runs.
//   Real: OverlayLifecycleLoader with directVisibility set, and the
//     NotificationCenter it loads.
//   Reconstructed: the line that connects the bar's notification signal to that
//     loader, because it is declared in shell.qml and a harness cannot reach
//     into it. What is proved here is the loader's behaviour, not shell.qml's
//     wiring — scripts/shell-cycle-bench.sh is the stage that runs shell.qml.
//
// Deliberately stops at the edge of the shell. The control centre's sections
// are exercised by name, and nothing is asked of BlueZ or NetworkManager: those
// live on the system bus, which the isolated session does not isolate, so a
// test that toggled them would be flipping a real radio on a real machine.
//
//     qs -p centre-interaction-harness.qml

import QtQuick
import Quickshell
import "features/controlcenter" as Controlcenter
import "features/notifications" as Notifications
import "features/statusbar" as Statusbar
import "services" as Services

ShellRoot {
    id: root

    readonly property int pollMs: 25
    readonly property int phaseTimeoutMs: 8000

    // A pause before acting, not a deadline for asserting. Same reason as the
    // panel harness: destroying a panel while its content is still incubating
    // makes Qt say so, and that is a property of the shell worth leaving
    // visible rather than a wait worth shortening.
    readonly property int actionGraceMs: 250

    // Every section BarLayout can ask for, including the empty one the bar's
    // own button sends. A section that stopped resolving would open the panel
    // on the wrong card, which is invisible to any test that only opens it once.
    readonly property var sections: ["", "wifi", "bluetooth", "output", "microphone"]

    property int phase: 0
    property int sectionIndex: 0
    property int waitedMs: 0
    property int graceMs: 0
    property string waitingFor: "the bar to build its content"
    property var barContent: null

    Services.Services {
        id: serviceState
    }

    Statusbar.BarWindow {
        id: barWindow

        screen: Quickshell.screens[0]
        services: serviceState

        // The reconstruction. shell.qml writes this same line.
        onOpenNotificationCenterRequested: notificationCentreLoader.toggle()

        OverlayLifecycleLoader {
            id: notificationCentreLoader

            directVisibility: true

            property var ownerWindow: barWindow

            Notifications.NotificationCenter {
                services: serviceState
                barWindow: notificationCentreLoader.ownerWindow
            }
        }
    }

    // Instantiated directly as well as reached through the bar, because the
    // loader BarWindow keeps is private: driving the real chain proves it runs,
    // and only a reference we hold can prove what it did. One says the path
    // works, the other says the panel does.
    Controlcenter.ControlCenter {
        id: directCentre

        services: serviceState
        barWindow: barWindow
    }

    function fail(message) {
        console.error(`CENTRE-INTERACTION-HARNESS: ${message}`);
        Qt.quit();
    }

    function require(condition, message) {
        if (!condition)
            fail(message);
        return condition;
    }

    // BarContent declares the signal and BarWindow handles it, so the emit has
    // to happen on the instance in between. It carries no id reachable from
    // here, so it is found by the signal it declares rather than by name.
    function findBarContent(node) {
        if (!node)
            return null;
        if (typeof node.openControlCenterRequested === "function")
            return node;
        const children = node.children || [];
        for (let index = 0; index < children.length; index++) {
            const found = root.findBarContent(children[index]);
            if (found)
                return found;
        }
        return null;
    }

    function ready() {
        if (root.phase === 0)
            return root.findBarContent(barWindow.contentItem) !== null;
        if (root.phase === 1 || root.phase === 2)
            return true;
        if (root.phase === 3)
            return directCentre.menuOpen && directCentre.expandedNetworkSection === root.sections[root.sectionIndex];
        if (root.phase === 4)
            return !directCentre.menuOpen;
        if (root.phase === 5)
            return notificationCentreLoader.item !== null && notificationCentreLoader.item.visible;
        return notificationCentreLoader.item === null;
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
            if (root.waitedMs >= root.phaseTimeoutMs)
                root.fail(`waited ${root.phaseTimeoutMs}ms for ${root.waitingFor}`);
        }
    }

    function step() {
        if (root.phase === 0) {
            root.barContent = root.findBarContent(barWindow.contentItem);
            root.sectionIndex = 0;
            root.phase = 1;
            root.waitingFor = "the bar to accept a control centre request";
            return;
        }

        // Through the real chain. There is nothing to assert on afterwards —
        // the loader is private — so what this proves is that the handler, the
        // lazy activation and ControlCenter.open() run for every section
        // without a warning, and the wrapper reads those warnings.
        if (root.phase === 1) {
            root.barContent.openControlCenterRequested(root.barContent, root.sections[root.sectionIndex]);
            root.phase = 2;
            return;
        }

        if (root.phase === 2) {
            // The same signal again: BarWindow's handler treats it as a toggle,
            // and its closing half takes a different branch depending on whether
            // the panel had finished opening.
            root.barContent.openControlCenterRequested(root.barContent, root.sections[root.sectionIndex]);
            root.sectionIndex++;
            if (root.sectionIndex < root.sections.length) {
                root.phase = 1;
                return;
            }

            root.sectionIndex = 0;
            root.phase = 3;
            root.waitingFor = `the control centre to open on section "${root.sections[0]}"`;
            directCentre.open(root.barContent, root.sections[0]);
            return;
        }

        // Now with something to read. open() has to land on the section it was
        // given, which is the part a bar module getting its section wrong would
        // break silently.
        if (root.phase === 3) {
            root.phase = 4;
            root.waitingFor = "the control centre to close";
            directCentre.close();
            return;
        }

        if (root.phase === 4) {
            root.sectionIndex++;
            if (root.sectionIndex < root.sections.length) {
                root.phase = 3;
                root.waitingFor = `the control centre to open on section "${root.sections[root.sectionIndex]}"`;
                directCentre.open(root.barContent, root.sections[root.sectionIndex]);
                return;
            }

            root.phase = 5;
            root.waitingFor = "the notification centre to open";
            barWindow.openNotificationCenterRequested();
            return;
        }

        if (root.phase === 5) {
            // directVisibility means the loader shows the item itself rather
            // than calling open() on it, and clears active when the item hides
            // rather than when it reports closing. Both halves are only reached
            // through this flag.
            root.phase = 6;
            root.waitingFor = "the notification centre to be destroyed on toggle";
            notificationCentreLoader.toggle();
            return;
        }

        pollTimer.running = false;

        console.info(`CENTRE-INTERACTION-HARNESS: sections exercised: ${root.sections.length}`);
        console.info("CENTRE-INTERACTION-HARNESS: control centre and notification centre passed");
        Qt.quit();
    }
}
