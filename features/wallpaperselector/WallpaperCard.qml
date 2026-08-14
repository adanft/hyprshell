import "../../shared/components" as Shared
import QtQuick
import QtQuick.Effects
import "../../theme" as Theme

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

    color: "transparent"

    Column {
        anchors.fill: parent
        spacing: card.theme.spacing.space6

        Rectangle {
            id: imageFrame

            width: parent.width
            height: WallpaperSizing.cardHeight
            radius: card.theme.shape.wallpaperThumbnailRadius
            color: "transparent"
            border.width: (card.hovered || card.selected || card.isActive) ? card.theme.shape.wallpaperCardBorderWidth : 0
            border.color: card.hovered ? Theme.Colors.hover : (card.selected ? Theme.Colors.primary : Theme.Colors.tertiary)

            // Opening this selector once holds about 46 MB that closing it does
            // not give back, with 39 wallpapers on disk. That is measured, and
            // so is the fact that neither obvious explanation is the cause —
            // written down here so the next person does not spend the afternoon
            // this already cost.
            //
            // It is not a leak: repeated opens add 39.5 MB, then 13.7, then 2.1,
            // and stop. It is not the images. Eight wallpapers at 1920x1080 and
            // the same eight at 320x180 retain 23.5 MB and 23.7 MB, so sixteen
            // times less pixel data on disk costs the same. It is not this
            // cache either, and it is not the layer below: measured against the
            // same baseline, `cache: false` retains 22.9 MB and
            // `layer.enabled: false` retains 19.9 MB, against 23.5 MB as
            // written. All three are one number.
            //
            // What is left looks like a fixed cost of running the grid at all,
            // around 20 MB, plus something small per card: an empty directory
            // retains 2.7 MB, eight wallpapers 22 MB, thirty-nine 46 MB, so the
            // marginal cost halves as the view starts recycling delegates.
            // Naming it properly needs a heap profiler, not another guess.
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
                sourceSize: Qt.size(width * WallpaperSizing.cardPreviewScale,
                                    height * WallpaperSizing.cardPreviewScale)
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
                // An OpacityMask stencil: only its alpha is read, so this is
                // not a palette decision and does not belong to any role.
                color: "black"
                layer.enabled: true
                visible: false
            }
        }

        Shared.AppText {
            width: parent.width
            text: card.label
            color: Theme.Colors.on_surface
            font.pixelSize: card.theme.typography.textMd
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
