import QtQuick

QtObject {
    readonly property int durationShort: 120
    readonly property int durationNormal: 220
    readonly property int durationEntrance: 260
    readonly property int layoutFinalizeDelay: 32

    readonly property real opacityDisabled: 0.45
    readonly property real opacityInactive: 0.6
    readonly property real opacityPreviewMuted: 0.72
    readonly property real opacityPreviewInactive: 0.48
    readonly property real opacityPreviewBarMuted: 0.34
    readonly property real opacityPreviewBarActive: 0.82
    readonly property real opacityPreviewSubtle: 0.16
    readonly property real opacityCarouselMinimum: 0.22
    readonly property real opacityCarouselDepthStep: 0.14
}
