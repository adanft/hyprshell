import "../shared/components" as Shared
import "../theme"
import QtQuick

Rectangle {
    id: card

    readonly property var icons: Icons
    readonly property var theme: AppTheme
    required property var themeData
    property bool selected: false
    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool active: selected || hovered
    readonly property color previewBackground: themeData && themeData.background ? themeData.background :
                                                                                   theme.colors.background
    readonly property color previewSurface: themeData && themeData.surface ? themeData.surface : previewBackground
    readonly property color previewSurfaceActive: themeData && themeData.surfaceActive ? themeData.surfaceActive :
                                                                                         previewSurface
    readonly property color previewText: themeData && themeData.text ? themeData.text : theme.colors.text
    readonly property color previewBorder: themeData && themeData.border ? themeData.border : theme.colors.border
    readonly property color previewFocus: themeData && themeData.focus ? themeData.focus : theme.colors.focus
    readonly property var previewColors: themeData && themeData.previewColors && themeData.previewColors.length >= 4
                                         ? themeData.previewColors.slice(0, 4) : [previewText, previewBorder,
                                                                                  previewSurface, previewBackground]
    readonly property int paletteDotSize: theme.sizing.themeSelectorPaletteDotSize
    readonly property int nameLineHeight: theme.typography.sizeMd + theme.spacing.space4

    implicitHeight: theme.spacing.appLauncherCardPadding * 2 + paletteDotSize + theme.spacing.appLauncherCardSpacing
                    + nameLineHeight

    signal activated

    radius: theme.shape.appLauncherCardRadius
    color: active ? previewSurfaceActive : previewBackground
    border.width: selected ? theme.shape.appLauncherCardBorderWidth : 0
    border.color: previewFocus

    Column {
        anchors.centerIn: parent
        spacing: card.theme.spacing.appLauncherCardSpacing

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: card.theme.spacing.appLauncherCardSpacing

            Repeater {
                model: 4

                Shared.AppText {
                    required property int index

                    width: card.paletteDotSize
                    height: card.paletteDotSize
                    text: card.icons.workspaceDot
                    color: card.previewColors[index]
                    font.family: card.theme.typography.iconFontFamily
                    font.pixelSize: card.theme.typography.actionIconFontSize
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Shared.AppText {
            width: card.width - card.theme.spacing.appLauncherCardPadding * 2
            height: card.nameLineHeight
            text: card.themeData.displayName
            color: card.previewText
            font.pixelSize: card.theme.typography.sizeMd
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
