import QtQuick
import QtTest
import ".."

TestCase {
    id: testCase
    name: "OverlayArbiter"
    when: windowShown

    // Stands in for OverlayLifecycleLoader with the same four members the
    // arbiter touches, and records the calls so a no-op close is visible.
    Component {
        id: fakeLoaderComponent
        QtObject {
            property bool requestedVisible: false
            property var targetScreen: null
            property int opens: 0
            property int closes: 0

            function open() {
                opens += 1
                requestedVisible = true
            }

            function close() {
                if (!requestedVisible)
                    return
                closes += 1
                requestedVisible = false
            }

            function toggle() {
                if (requestedVisible)
                    close()
                else
                    open()
            }
        }
    }

    // Stands in for OverlayScreenResolver, which cannot run here because it
    // reaches into Hyprland. Which screen it picks is OverlayScreen's job and is
    // covered by OverlayScreen.test.js.
    Component {
        id: fakeResolverComponent
        QtObject {
            property var screen: ({
                    "name": "DP-1"
                })
            property int calls: 0

            function focusedScreen() {
                calls += 1
                return screen
            }
        }
    }

    Component {
        id: arbiterComponent
        OverlayArbiter {}
    }

    function buildArbiter(loaderCount) {
        const loaders = []
        for (let index = 0; index < loaderCount; index++)
            loaders.push(fakeLoaderComponent.createObject(testCase))
        const resolver = fakeResolverComponent.createObject(testCase)
        const arbiter = arbiterComponent.createObject(testCase, {
            "loaders": loaders,
            "screenResolver": resolver
        })
        return {
            arbiter: arbiter,
            loaders: loaders,
            resolver: resolver
        }
    }

    function openCount(loaders) {
        return loaders.filter(loader => loader.requestedVisible).length
    }

    function test_opening_closes_whichever_other_overlay_was_up() {
        const built = buildArbiter(3)
        built.arbiter.open(built.loaders[0])
        compare(openCount(built.loaders), 1, "first open left more than one overlay up")

        built.arbiter.open(built.loaders[1])
        compare(openCount(built.loaders), 1, "second open did not displace the first")
        verify(built.loaders[1].requestedVisible, "the overlay just opened is not the one left up")
        compare(built.loaders[0].closes, 1, "the displaced overlay was not closed")
    }

    function test_opening_does_not_close_overlays_that_were_already_shut() {
        const built = buildArbiter(3)
        built.arbiter.open(built.loaders[0])
        compare(built.loaders[1].closes, 0, "a closed overlay received a redundant close")
        compare(built.loaders[2].closes, 0, "a closed overlay received a redundant close")
    }

    function test_reopening_the_same_overlay_does_not_close_it() {
        const built = buildArbiter(2)
        built.arbiter.open(built.loaders[0])
        built.arbiter.open(built.loaders[0])
        compare(built.loaders[0].closes, 0, "the overlay being opened closed itself")
        compare(built.loaders[0].opens, 2, "the second open did not reach the loader")
        verify(built.loaders[0].requestedVisible, "the overlay ended up closed")
    }

    function test_an_opening_toggle_displaces_the_others() {
        const built = buildArbiter(3)
        built.arbiter.open(built.loaders[0])
        built.arbiter.toggle(built.loaders[1])
        compare(openCount(built.loaders), 1, "an opening toggle left two overlays up")
        verify(built.loaders[1].requestedVisible, "the toggled overlay did not open")
        compare(built.loaders[0].closes, 1, "the opening toggle did not displace the other overlay")
    }

    // A closing toggle has nothing to displace. If it cleared the set anyway it
    // would be indistinguishable here, because the others are already shut, so
    // the guard is what keeps a future open overlay from being dismissed.
    function test_a_closing_toggle_only_closes_its_own_overlay() {
        const built = buildArbiter(3)
        built.arbiter.open(built.loaders[0])
        built.arbiter.toggle(built.loaders[0])
        compare(openCount(built.loaders), 0, "the closing toggle left an overlay up")
        compare(built.loaders[0].closes, 1, "the closing toggle did not close its own overlay")
        compare(built.loaders[1].opens, 0, "an unrelated overlay was opened")
        compare(built.loaders[2].opens, 0, "an unrelated overlay was opened")
    }

    // The screen has to be handed over before open(), because a PanelWindow
    // picks its output when it maps.
    function test_opening_hands_the_overlay_the_focused_screen() {
        const built = buildArbiter(2)
        built.arbiter.open(built.loaders[0])
        compare(built.loaders[0].targetScreen, built.resolver.screen, "open() did not hand the overlay the focused screen")
    }

    function test_an_opening_toggle_hands_the_overlay_the_focused_screen() {
        const built = buildArbiter(2)
        built.arbiter.toggle(built.loaders[0])
        compare(built.loaders[0].targetScreen, built.resolver.screen, "an opening toggle did not hand over the focused screen")
    }

    // Resolved per open, not once: the user may have moved to another monitor
    // between two opens.
    function test_each_open_resolves_the_screen_again() {
        const built = buildArbiter(2)
        built.arbiter.open(built.loaders[0])
        built.resolver.screen = ({
                "name": "HDMI-A-1"
            })
        built.arbiter.open(built.loaders[1])
        compare(built.loaders[1].targetScreen, built.resolver.screen, "the second open reused the first screen")
        compare(built.resolver.calls, 2, "the resolver was not consulted once per open")
    }

    function test_a_closing_toggle_does_not_consult_the_resolver() {
        const built = buildArbiter(2)
        built.arbiter.open(built.loaders[0])
        built.arbiter.toggle(built.loaders[0])
        compare(built.resolver.calls, 1, "a closing toggle re-resolved the screen")
    }

    // A shell that wires no resolver must still open its overlays; they land on
    // the default output rather than nowhere.
    function test_a_missing_resolver_still_opens_the_overlay() {
        const loader = fakeLoaderComponent.createObject(testCase)
        const arbiter = arbiterComponent.createObject(testCase, {
            "loaders": [loader],
            "screenResolver": null
        })
        arbiter.open(loader)
        verify(loader.requestedVisible, "a missing resolver stopped the overlay from opening")
        compare(loader.targetScreen, null, "a missing resolver invented a screen")
    }

    function test_an_empty_set_is_harmless() {
        const arbiter = arbiterComponent.createObject(testCase, {
            "loaders": []
        })
        const loader = fakeLoaderComponent.createObject(testCase)
        arbiter.open(loader)
        verify(loader.requestedVisible, "an arbiter with no registered loaders refused to open one")
    }
}
