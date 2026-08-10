pragma Singleton
import QtQuick

QtObject {
    readonly property string textFontFamily: "SF Pro Display"
    readonly property string iconFontFamily: "Symbols Nerd Font"
    readonly property string defaultFontFamily: textFontFamily

    // Every font size in the shell is one of these, glyphs included. A Nerd Font
    // glyph is text, and sizing it from Sizing put font sizes in two files: three
    // different tokens there and here spelled the same 24, and two more sat in
    // Sizing describing nothing but a font.
    //
    // textBase is the body size AppText paints unless a caller overrides it, and
    // the rest are named against it.
    readonly property int textSm: 12
    readonly property int textMd: 14
    readonly property int textBase: 16
    readonly property int textLg: 20

    readonly property int glyphSm: 16
    readonly property int glyphMd: 24
    readonly property int glyphLg: 28
    readonly property int glyphXl: 36
    readonly property int glyphHero: 68

    readonly property real notificationBodyLineHeight: 1.35

    readonly property string styleRegular: "Regular"
    readonly property string styleMedium: "Medium"
    readonly property string styleSemibold: "Semibold"
    readonly property string styleBold: "Bold"
}
