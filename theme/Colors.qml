pragma Singleton
import QtQuick
import "PaletteRoles.js" as PaletteRoles

// The shell's palette: sixteen roles, and nothing else. Every colour painted
// anywhere in the shell is one of these, read straight off this singleton.
// Roles mirror Noctalia's ColorRole enum.
//
// The foreground roles are spelled on_primary, not onPrimary. Declaring both
// `primary` and `onPrimary` on one QML object silently leaves the second at the
// default colour — black — because onPrimary reads as a handler for primary.
// Snake case sidesteps that, and it is also how Noctalia spells these roles in
// kColorRoleTokens.
QtObject {
    // The active palette, pushed in by StockThemes. Holding it here rather than
    // reaching into StockThemes keeps this singleton free of any Quickshell
    // dependency, so a component that reads a colour still loads under a plain
    // QML test runner.
    property var palette: PaletteRoles.FALLBACK_PALETTE

    // Accents. Each pair is a fill and whatever is drawn on top of that fill.
    readonly property color primary: palette.primary
    readonly property color on_primary: palette.on_primary
    readonly property color secondary: palette.secondary
    readonly property color on_secondary: palette.on_secondary
    readonly property color tertiary: palette.tertiary
    readonly property color on_tertiary: palette.on_tertiary
    readonly property color error: palette.error
    readonly property color on_error: palette.on_error
    readonly property color hover: palette.hover
    readonly property color on_hover: palette.on_hover

    // Surfaces, painted deepest first: window bodies on `shadow`, cards and
    // rows on `surface`, hovered and active chrome on `surface_variant`.
    readonly property color shadow: palette.shadow
    readonly property color surface: palette.surface
    readonly property color on_surface: palette.on_surface
    readonly property color surface_variant: palette.surface_variant
    readonly property color on_surface_variant: palette.on_surface_variant
    readonly property color outline: palette.outline
}
