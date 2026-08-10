import QtQuick

// Keeps a set of full-screen overlays mutually exclusive, and hands each one
// the screen it should map on.
//
// Each of them takes the whole screen with exclusive keyboard focus, so two up
// at once is the case the layer-shell protocol leaves undefined: "no guarantee
// is made when this surface will receive keyboard focus (if ever)". Their dim
// backdrops stack on top of each other as well, so the screen darkens once per
// open overlay.
//
// Every entry in loaders must expose requestedVisible, targetScreen, open(),
// close() and toggle() — OverlayLifecycleLoader does.
QtObject {
    id: arbiter

    property var loaders: []

    // Supplies the screen an overlay should open on. Injected rather than read
    // here so this stays free of the Quickshell and Hyprland imports; the shell
    // passes an OverlayScreenResolver. A missing resolver assigns no screen,
    // which leaves the overlay on the default output rather than unmapped.
    property var screenResolver: null

    function closeOthers(keptLoader) {
        for (const loader of arbiter.loaders) {
            if (loader !== keptLoader)
                loader.close()
        }
    }

    // The overlays are single instances rather than one per monitor, so the
    // screen they belong on is only known when the user asks for one. Resolved
    // per open rather than bound, so an overlay cannot hop monitors while it is
    // already on screen.
    function aimAtFocusedScreen(loader) {
        if (!arbiter.screenResolver)
            return
        loader.targetScreen = arbiter.screenResolver.focusedScreen()
    }

    function open(loader) {
        arbiter.closeOthers(loader)
        arbiter.aimAtFocusedScreen(loader)
        loader.open()
    }

    // Only an opening toggle displaces the others and re-aims. A closing one has
    // nothing to displace, and clearing them there would dismiss an overlay the
    // user never asked to lose.
    function toggle(loader) {
        if (!loader.requestedVisible) {
            arbiter.closeOthers(loader)
            arbiter.aimAtFocusedScreen(loader)
        }
        loader.toggle()
    }
}
