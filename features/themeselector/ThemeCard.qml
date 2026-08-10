import "../../shared/components" as Shared
import "../../theme"
import QtQuick

Rectangle {
    id: card

    readonly property var icons: Icons
    readonly property var theme: AppTheme
    required property var themeData
    property bool selected: false
    property bool isActive: false
    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool active: selected || hovered
    readonly property color previewBackground: themeData && themeData.surface ? themeData.surface :
                                                                                Colors.surface
    readonly property color previewText: themeData && themeData.on_surface ? themeData.on_surface :
                                                                           Colors.on_surface
    readonly property color previewBorder: themeData && themeData.outline ? themeData.outline : Colors.outline
    // The four accents a theme is recognised by, straight off its roles.
    readonly property var previewColors: themeData && themeData.primary ? [themeData.primary, themeData.hover,
        themeData.tertiary, themeData.secondary] : [Colors.primary, Colors.hover, Colors.tertiary,
        Colors.secondary]
    readonly property int paletteDotSize: ThemeSelectorSizing.paletteDotSize
    readonly property int nameLineHeight: theme.typography.textMd + theme.spacing.space4

    implicitHeight: theme.spacing.space8 * 2 + paletteDotSize + theme.spacing.space6
                    + nameLineHeight

    signal activated

    radius: theme.shape.appLauncherCardRadius
    color: previewBackground
    border.width: (hovered || selected || isActive) ? theme.shape.wallpaperCardBorderWidth : 0
    border.color: hovered ? Colors.hover : (selected ? Colors.primary : Colors.tertiary)

    Column {
        anchors.centerIn: parent
        spacing: card.theme.spacing.space6

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: card.theme.spacing.space6

            Repeater {
                model: 4

                Shared.AppText {
                    required property int index

                    width: card.paletteDotSize
                    height: card.paletteDotSize
                    text: card.icons.ui.dot
                    color: card.previewColors[index]
                    font.family: card.theme.typography.iconFontFamily
                    font.pixelSize: card.theme.typography.glyphLg
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Shared.AppText {
            width: card.width - card.theme.spacing.space8 * 2
            height: card.nameLineHeight
            text: card.themeData.displayName
            color: card.previewText
            font.pixelSize: card.theme.typography.textMd
            font.styleName: card.theme.typography.styleMedium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activated()
    }
}
