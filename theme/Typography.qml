import QtQuick

QtObject {
    readonly property string textFontFamily: "SF Pro Display"
    readonly property string iconFontFamily: "Symbols Nerd Font"
    readonly property string defaultFontFamily: textFontFamily

    readonly property int sizeSm: 12
    readonly property int sizeMd: 14
    readonly property int sizeLg: 16
    readonly property int sizeXl: 20
    readonly property int actionIconFontSize: 28
    readonly property int displayIconFontSize: 56
    readonly property int heroIconFontSize: 68

    readonly property string styleRegular: "Regular"
    readonly property string styleMedium: "Medium"
    readonly property string styleSemibold: "Semibold"
    readonly property string styleBold: "Bold"
}
