import "../../shared/components" as Shared
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../theme"

Rectangle {
    id: card

    required property var app
    required property var theme
    property bool selected: false
    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool active: selected || hovered
    readonly property string fallbackIcon: "application-x-executable"
    readonly property string iconSource: app && app.icon ? Quickshell.iconPath(app.icon, fallbackIcon) : Quickshell.iconPath(
                                                               fallbackIcon)

    signal activated

    width: theme.sizing.appLauncherCardWidth
    height: theme.sizing.appLauncherCardHeight
    radius: theme.shape.appLauncherCardRadius
    color: hovered ? Colors.hover : (selected ? Colors.primary : "transparent")

    Column {
        anchors.fill: parent
        anchors.margins: card.theme.spacing.appLauncherCardPadding
        spacing: card.theme.spacing.appLauncherCardSpacing

        Item {
            width: parent.width
            height: card.theme.sizing.appLauncherIconSlotSize

            IconImage {
                anchors.centerIn: parent
                width: card.theme.sizing.appLauncherIconSize
                height: card.theme.sizing.appLauncherIconSize
                implicitSize: card.theme.sizing.appLauncherIconSize
                source: card.iconSource
            }
        }

        Shared.AppText {
            width: parent.width
            text: card.app ? (card.app.name || "Unnamed") : "Unnamed"
            color: card.hovered ? Colors.on_hover : (card.selected ? Colors.on_primary : Colors.on_surface)
            font.pixelSize: card.theme.typography.textBase
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
