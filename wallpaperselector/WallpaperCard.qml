import "../theme"
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: card

    readonly property var theme: AppTheme {}

    required property string path
    property string thumbnailPath: path
    property bool thumbnailCached: false
    property bool selected: false
    property real focusWeight: selected ? 1 : 0
    property real renderWidth: width
    readonly property bool hovered: mouseArea.containsMouse
    readonly property real previewScale: theme.sizing.wallpaperCardPreviewScale
    readonly property real slant: Math.min(height * 0.08, width * 0.35)
    readonly property real borderWidth: theme.shape.appLauncherCardBorderWidth
    readonly property real pathInset: borderWidth / 2
    readonly property real innerHeight: Math.max(1, height - 2 * pathInset)
    readonly property real cornerRadius: Math.max(0, Math.min(theme.shape.wallpaperCardRadius, (width - slant - 2 * pathInset) / 2, innerHeight / 2))
    readonly property real slopeOffset: slant * cornerRadius / innerHeight
    readonly property color borderColor: Qt.rgba(theme.colors.border.r + (theme.colors.focus.r - theme.colors.border.r) * focusWeight, theme.colors.border.g + (theme.colors.focus.g - theme.colors.border.g) * focusWeight, theme.colors.border.b + (theme.colors.focus.b - theme.colors.border.b) * focusWeight, theme.colors.border.a + (theme.colors.focus.a - theme.colors.border.a) * focusWeight)

    signal activated
    signal wheelStepped(int direction)

    width: theme.sizing.wallpaperCardWidth
    height: theme.sizing.wallpaperCardHeight

    Image {
        anchors.fill: parent
        source: card.thumbnailPath || card.path
        // Only known local qsrice thumbnails may load synchronously; originals stay async.
        asynchronous: !card.thumbnailCached
        cache: true
        retainWhileLoading: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        sourceSize: Qt.size(Math.max(1, card.renderWidth * card.previewScale), Math.max(1, card.height * card.previewScale))
        layer.enabled: true

        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: imageMask
            maskThresholdMin: 0
            maskSpreadAtMin: 0
        }
    }

    // Alpha-only polygon mask: it clips the image without transforming its pixels.
    Shape {
        id: imageMask

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        visible: false
        layer.enabled: true
        layer.samples: 2

        ShapePath {
            fillColor: card.theme.colors.mask
            strokeColor: card.theme.colors.transparent
            startX: card.pathInset + card.slant + card.cornerRadius
            startY: card.pathInset
            PathLine {
                x: card.width - card.pathInset - card.cornerRadius
                y: card.pathInset
            }
            PathQuad {
                x: card.width - card.pathInset - card.slopeOffset
                y: card.pathInset + card.cornerRadius
                controlX: card.width - card.pathInset
                controlY: card.pathInset
            }
            PathLine {
                x: card.width - card.pathInset - card.slant + card.slopeOffset
                y: card.height - card.pathInset - card.cornerRadius
            }
            PathQuad {
                x: card.width - card.pathInset - card.slant - card.cornerRadius
                y: card.height - card.pathInset
                controlX: card.width - card.pathInset - card.slant
                controlY: card.height - card.pathInset
            }
            PathLine {
                x: card.pathInset + card.cornerRadius
                y: card.height - card.pathInset
            }
            PathQuad {
                x: card.pathInset + card.slopeOffset
                y: card.height - card.pathInset - card.cornerRadius
                controlX: card.pathInset
                controlY: card.height - card.pathInset
            }
            PathLine {
                x: card.pathInset + card.slant - card.slopeOffset
                y: card.pathInset + card.cornerRadius
            }
            PathQuad {
                x: card.pathInset + card.slant + card.cornerRadius
                y: card.pathInset
                controlX: card.pathInset + card.slant
                controlY: card.pathInset
            }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        containsMode: Shape.FillContains

        ShapePath {
            fillColor: card.theme.colors.transparent
            strokeColor: card.borderColor
            strokeWidth: card.borderWidth
            startX: card.pathInset + card.slant + card.cornerRadius
            startY: card.pathInset
            PathLine {
                x: card.width - card.pathInset - card.cornerRadius
                y: card.pathInset
            }
            PathQuad {
                x: card.width - card.pathInset - card.slopeOffset
                y: card.pathInset + card.cornerRadius
                controlX: card.width - card.pathInset
                controlY: card.pathInset
            }
            PathLine {
                x: card.width - card.pathInset - card.slant + card.slopeOffset
                y: card.height - card.pathInset - card.cornerRadius
            }
            PathQuad {
                x: card.width - card.pathInset - card.slant - card.cornerRadius
                y: card.height - card.pathInset
                controlX: card.width - card.pathInset - card.slant
                controlY: card.height - card.pathInset
            }
            PathLine {
                x: card.pathInset + card.cornerRadius
                y: card.height - card.pathInset
            }
            PathQuad {
                x: card.pathInset + card.slopeOffset
                y: card.height - card.pathInset - card.cornerRadius
                controlX: card.pathInset
                controlY: card.height - card.pathInset
            }
            PathLine {
                x: card.pathInset + card.slant - card.slopeOffset
                y: card.pathInset + card.cornerRadius
            }
            PathQuad {
                x: card.pathInset + card.slant + card.cornerRadius
                y: card.pathInset
                controlX: card.pathInset + card.slant
                controlY: card.pathInset
            }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activated()
        onWheel: wheel => {
            const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x
            if (delta !== 0)
                card.wheelStepped(delta > 0 ? -1 : 1)
            wheel.accepted = true
        }
    }
}
