import "../shared/components" as Shared
import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: card

    required property var app
    required property var theme
    property bool selected: false
    readonly property bool active: selected || mouseArea.containsMouse
    readonly property string fallbackIcon: "application-x-executable"
    readonly property string iconSource: app && app.icon ? Quickshell.iconPath(app.icon, fallbackIcon) : Quickshell.iconPath(fallbackIcon)

    signal activated()
    signal hovered()

    width: theme.sizing.appLauncherCardWidth
    height: theme.sizing.appLauncherCardHeight
    radius: theme.shape.appLauncherCardRadius
    color: active ? theme.colors.surfaceActive : theme.colors.surfaceTransparent
    border.width: active ? theme.shape.appLauncherCardBorderWidth : 0
    border.color: theme.colors.focus

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
            color: card.theme.colors.text
            font.pixelSize: card.theme.typography.sizeLg
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
        onEntered: card.hovered()
        onClicked: card.activated()
    }

}
