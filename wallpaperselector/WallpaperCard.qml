import "../theme"
import QtQuick
import QtQuick.Effects

Rectangle {
    id: card

    readonly property var
    theme: AppTheme {
    }

    required property string path
    property bool selected: false
    readonly property bool hovered: mouseArea.containsMouse
    readonly property int previewScale: 2

    signal activated()

    width: theme.sizing.wallpaperCardWidth
    height: theme.sizing.wallpaperCardHeight
    radius: theme.shape.wallpaperCardRadius
    color: theme.colors.surface

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
        color: card.theme.colors.mask
        visible: false
        layer.enabled: true
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: card.theme.colors.transparent
        border.width: card.theme.shape.appLauncherCardBorderWidth
        border.color: card.selected ? card.theme.colors.focus : card.theme.colors.border
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: card.theme.shape.appLauncherCardBorderWidth
        radius: parent.radius
        visible: card.hovered
        color: Qt.rgba(card.theme.colors.background.r, card.theme.colors.background.g, card.theme.colors.background.b, 0.5)
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activated()
    }

}
