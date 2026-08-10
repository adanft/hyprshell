import QtQuick

// Keeps a set of full-screen overlays mutually exclusive.
//
// Each of them takes the whole screen with exclusive keyboard focus, so two up
// at once is the case the layer-shell protocol leaves undefined: "no guarantee
// is made when this surface will receive keyboard focus (if ever)". Their dim
// backdrops stack on top of each other as well, so the screen darkens once per
// open overlay.
//
// Every entry in loaders must expose requestedVisible, open(), close() and
// toggle() — OverlayLifecycleLoader does.
QtObject {
    id: arbiter

    property var loaders: []

    function closeOthers(keptLoader) {
        for (const loader of arbiter.loaders) {
            if (loader !== keptLoader)
                loader.close()
        }
    }

    function open(loader) {
        arbiter.closeOthers(loader)
        loader.open()
    }

    // Only an opening toggle displaces the others. A closing one has nothing to
    // displace, and clearing them there would dismiss an overlay the user never
    // asked to lose.
    function toggle(loader) {
        if (!loader.requestedVisible)
            arbiter.closeOthers(loader)
        loader.toggle()
    }
}
