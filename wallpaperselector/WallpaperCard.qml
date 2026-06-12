import QtQuick
import QtQuick.Effects
import "../theme"

Rectangle {
    id: card

    readonly property var theme: AppTheme {}
    readonly property var icons: Icons {}
    required property string path
    property bool selected: false

    signal activated()
    signal hovered()

    readonly property bool active: selected || mouseArea.containsMouse
    readonly property int previewScale: 2

    width: theme.wallpaperCardWidth
    height: theme.wallpaperCardHeight
    radius: theme.wallpaperCardRadius
    color: theme.wallpaperCardBackgroundColor

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
        color: "black"
        visible: false
        layer.enabled: true
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: card.active ? card.theme.wallpaperCardBorderWidth : 0
        border.color: card.selected ? card.theme.wallpaperCardSelectedBorderColor : mouseArea.containsMouse ? card.theme.wallpaperCardHoverBorderColor : card.theme.wallpaperCardInactiveBorderColor
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: card.theme.wallpaperCardSelectedBadgeMargin
        width: card.theme.wallpaperCardSelectedBadgeSize
        height: card.theme.wallpaperCardSelectedBadgeSize
        radius: card.theme.wallpaperCardSelectedBadgeRadius
        visible: card.selected
        color: card.theme.wallpaperCardSelectedBadgeColor

        Text {
            anchors.centerIn: parent
            text: card.icons.wallpaperSelectedCheck
            color: card.theme.wallpaperCardSelectedBadgeIconColor
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
