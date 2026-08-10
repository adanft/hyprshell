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

    Component {
        id: arbiterComponent
        OverlayArbiter {}
    }

    function buildArbiter(loaderCount) {
        const loaders = []
        for (let index = 0; index < loaderCount; index++)
            loaders.push(fakeLoaderComponent.createObject(testCase))
        const arbiter = arbiterComponent.createObject(testCase, {
            "loaders": loaders
        })
        return {
            arbiter: arbiter,
            loaders: loaders
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

    function test_an_empty_set_is_harmless() {
        const arbiter = arbiterComponent.createObject(testCase, {
            "loaders": []
        })
        const loader = fakeLoaderComponent.createObject(testCase)
        arbiter.open(loader)
        verify(loader.requestedVisible, "an arbiter with no registered loaders refused to open one")
    }
}
