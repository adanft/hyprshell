import "../theme"
import QtQuick
import QtQuick.Effects

Rectangle {
    id: card

    readonly property var
    theme: AppTheme {
    }

    readonly property var
    icons: Icons {
    }

    required property string path
    property bool selected: false
    readonly property bool active: selected || mouseArea.containsMouse
    readonly property int previewScale: 2

    signal activated()
    signal hovered()

    width: theme.wallpaperCardWidth
    height: theme.wallpaperCardHeight
    radius: theme.wallpaperCardRadius
    color: theme.colors.mantle

    Image {
        anchors.fill: parent
        source: card.path
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        sourceSize: Qt.size(card.width * card.previewScale, card.height * card.previewScale)
        layer.enabled: true

        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: imageMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

    }

    Rectangle {
        id: imageMask

        anchors.fill: parent
        radius: card.radius
        color: card.theme.colors.black
        visible: false
        layer.enabled: true
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: card.theme.colors.transparent
        border.width: card.active ? card.theme.wallpaperCardBorderWidth : 0
        border.color: card.selected ? card.theme.colors.pink : mouseArea.containsMouse ? card.theme.colors.mauve : card.theme.colors.surface0
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: card.theme.wallpaperCardSelectedBadgeMargin
        width: card.theme.wallpaperCardSelectedBadgeSize
        height: card.theme.wallpaperCardSelectedBadgeSize
        radius: card.theme.wallpaperCardSelectedBadgeRadius
        visible: card.selected
        color: card.theme.colors.pink

        Text {
            anchors.centerIn: parent
            text: card.icons.wallpaperSelectedCheck
            color: card.theme.colors.crust
            font.pixelSize: card.theme.wallpaperCardSelectedBadgeIconFontSize
            font.bold: true
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
