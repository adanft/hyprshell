import "../shared/components" as Shared
import QtQuick
import QtQuick.Effects
import "../theme" as Theme

Rectangle {
    id: card

    readonly property var theme: Theme.AppTheme

    required property string path
    required property string label
    property string thumbnailPath: path
    property bool thumbnailCached: false
    property bool selected: false
    property bool isActive: false
    readonly property bool hovered: mouseArea.containsMouse

    signal activated

    color: theme.colors.transparent

    Column {
        anchors.fill: parent
        spacing: card.theme.spacing.appLauncherCardSpacing

        Rectangle {
            id: imageFrame

            width: parent.width
            height: card.theme.sizing.wallpaperCardHeight
            radius: card.theme.shape.wallpaperThumbnailRadius
            color: card.theme.colors.transparent
            border.width: (card.hovered || card.selected || card.isActive) ? card.theme.shape.wallpaperCardBorderWidth : 0
            border.color: card.hovered ? card.theme.colors.secondary : (card.selected ? card.theme.colors.primary : card.theme.colors.info)

            Image {
                id: thumbnailImage

                anchors.fill: parent
                anchors.margins: card.theme.shape.wallpaperCardBorderWidth
                source: card.thumbnailPath || card.path
                asynchronous: !card.thumbnailCached
                cache: true
                retainWhileLoading: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                sourceSize: Qt.size(width * card.theme.sizing.wallpaperCardPreviewScale,
                                    height * card.theme.sizing.wallpaperCardPreviewScale)
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

                anchors.fill: thumbnailImage
                radius: Math.max(0, imageFrame.radius - card.theme.shape.wallpaperCardBorderWidth)
                color: card.theme.colors.mask
                layer.enabled: true
                visible: false
            }
        }

        Shared.AppText {
            width: parent.width
            text: card.label
            color: card.theme.colors.text
            font.pixelSize: card.theme.typography.sizeMd
            font.styleName: card.theme.typography.styleMedium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
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
