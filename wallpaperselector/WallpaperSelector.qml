import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import "../theme"

Scope {
    id: selector

    readonly property var theme: AppTheme {}
    property alias visible: panel.visible
    property bool quitOnClose: false
    property bool transitionsEnabled: false
        property bool visualsActive: false
    readonly property int residencyRadius: 5

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string wallpapersDir: Quickshell.env("AWWW_WALLPAPERS_DIR") || `${home}/Wallpapers`
    readonly property string wallpapersFolderUrl: wallpapersDir ? "file://" + wallpapersDir.split('/').map(segment => encodeURIComponent(segment)).join('/') : ""
    readonly property var transitionArgs: [
        "--transition-type", "center",
        "--transition-duration", "1.0",
        "--transition-fps", "60"
    ]

    property int selectedIndex: 0
    readonly property var contentItem: contentLoader.item
    readonly property string selectedWallpaperPath: wallpaperFolderModel.count > selectedIndex ? fileUrlToPath(wallpaperFolderModel.get(selectedIndex, "filePath")) : ""
    readonly property string previewWallpaperSource: pathToFileUrl(AppSettings.currentWallpaper)

    WallpaperThumbnailCache {
        id: thumbnailCache
    }

    Component {
        id: selectorContent

        Column {
            property alias wallpaperListView: wallpaperList

            anchors.fill: parent
            anchors.margins: selector.theme.spacing.wallpaperSelectorGridMargin
            spacing: selector.theme.spacing.appLauncherSectionSpacing

            Rectangle {
                id: preview

                readonly property int preferredHeight: Math.round(width * 9 / 16)
                readonly property int minimumGridHeight: selector.theme.sizing.wallpaperCardHeight + selector.theme.spacing.space12

                width: parent.width
                height: Math.min(preferredHeight, Math.max(0, parent.height - parent.spacing - minimumGridHeight))
                radius: selector.theme.shape.wallpaperCardRadius
                color: selector.theme.colors.background
                clip: true

                Image {
                    id: previewImage

                    anchors.fill: parent
                    source: selector.previewWallpaperSource
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    sourceSize: Qt.size(width * 2, height * 2)
                    visible: source.toString().length > 0
                    layer.enabled: true

                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: previewMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                }

                Rectangle {
                    id: previewMask

                    anchors.fill: parent
                    radius: preview.radius
                    color: selector.theme.colors.mask
                    visible: false
                    layer.enabled: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: wallpaperFolderModel.status !== FolderListModel.Loading && wallpaperFolderModel.count === 0
                    width: parent.width - selector.theme.spacing.wallpaperSelectorEmptyTextHorizontalMargin
                    text: `No wallpapers found. Add images to ${selector.wallpapersDir}`
                    color: selector.theme.colors.textMuted
                    font.pixelSize: selector.theme.typography.sizeLg
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            Flickable {
                id: wallpaperList

                readonly property real selectedWidth: Math.min(width * 0.58, height * 1.62)
                readonly property real sideWidth: Math.max(1, height * 0.34)
                readonly property real cardHeight: Math.max(1, height - selector.theme.spacing.space4)
                readonly property real slant: Math.min(cardHeight * 0.08, sideWidth * 0.35)
                readonly property real stride: sideWidth - slant
                readonly property real centeringMargin: Math.max(0, (width - selectedWidth) / 2)
                readonly property int viewportIndex: stride > 0 && wallpaperFolderModel.count > 0
                    ? Math.max(0, Math.min(wallpaperFolderModel.count - 1, Math.round(contentX / stride)))
                    : 0
                    property int transitionFromIndex: selector.selectedIndex
                    property int transitionToIndex: selector.selectedIndex
                    property int queuedIndex: -1
                    property real transitionProgress: 1
                    property bool transitionRunning: false

                width: parent.width
                height: Math.max(0, parent.height - preview.height - parent.spacing)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                interactive: false
                contentWidth: wallpaperFolderModel.count > 0
                    ? 2 * centeringMargin + (wallpaperFolderModel.count - 1) * stride + selectedWidth
                    : width
                contentHeight: height

                NumberAnimation {
                    id: transitionAnimation
                    target: wallpaperList
                    property: "transitionProgress"
                    from: 0
                    to: 1
                    duration: 120
                    easing.type: Easing.InOutCubic
                    onFinished: wallpaperList.finishTransition()
                }

                function weightAt(index, fromIndex, toIndex, progress) {
                    if (fromIndex === toIndex)
                        return index === toIndex ? 1 : 0
                    return index === fromIndex ? 1 - progress
                        : (index === toIndex ? progress : 0)
                }

                function weight(index) {
                    return weightAt(index, transitionFromIndex, transitionToIndex, transitionProgress)
                }

                Component.onCompleted: {
                    function check(ok, message) { if (!ok) console.warn(message) }
                    check(weightAt(1, 1, 2, 0) === 1 && weightAt(2, 1, 2, 0) === 0,
                        "selection weight at 0 failed")
                    check(weightAt(1, 1, 2, 0.5) === 0.5 && weightAt(2, 1, 2, 0.5) === 0.5,
                        "selection weight at 0.5 failed")
                    check(weightAt(1, 1, 2, 1) === 0 && weightAt(2, 1, 2, 1) === 1,
                        "selection weight at 1 failed")
                    check(weightAt(2, 2, 2, 1) === 1 && 2 === 2,
                        "settled selection invariant failed")
                }

                    function expansionBefore(index) {
                        if (transitionFromIndex === transitionToIndex)
                            return transitionToIndex < index ? 1 : 0
                        return (transitionFromIndex < index ? 1 - transitionProgress : 0)
                            + (transitionToIndex < index ? transitionProgress : 0)
                    }

                    function focusIndex() {
                        return transitionFromIndex + (transitionToIndex - transitionFromIndex) * transitionProgress
                    }

                    function selectionContentX(index) {
                        return Math.max(0, Math.min(index * stride, Math.max(0, contentWidth - width)))
                    }

                    onTransitionProgressChanged: contentX = selectionContentX(focusIndex())

                    function finishTransition() {
                        transitionProgress = 1
                        if (queuedIndex >= 0 && queuedIndex !== transitionToIndex) {
                            const next = queuedIndex
                            queuedIndex = -1
                            startTransition(next)
                            return
                        }
                        queuedIndex = -1
                        selector.selectedIndex = transitionToIndex
                        transitionRunning = false
                    }

                    function startTransition(index) {
                        if (index === transitionToIndex) {
                            jumpToIndex(index)
                            return
                        }
                        transitionFromIndex = transitionToIndex
                        transitionToIndex = index
                        transitionRunning = true
                        transitionAnimation.restart()
                    }

                    function requestIndex(index) {
                        if (index < 0 || index >= wallpaperFolderModel.count)
                            return
                        if (!selector.transitionsEnabled) {
                            jumpToIndex(index)
                            return
                        }
                        if (transitionRunning) {
                            queuedIndex = index
                            selector.selectedIndex = index
                            return
                        }
                        selector.selectedIndex = index
                        startTransition(index)
                    }

                    function stopTransition() {
                        transitionAnimation.stop()
                        queuedIndex = -1
                        transitionRunning = false
                    }

                    function jumpToIndex(index) {
                        transitionAnimation.stop()
                        transitionFromIndex = index
                        transitionToIndex = index
                        transitionProgress = 1
                        queuedIndex = -1
                        transitionRunning = false
                        selector.selectedIndex = index
                        contentX = selectionContentX(index)
                    }

                    Repeater {
                    model: wallpaperFolderModel

                    delegate: Item {
                    required property string filePath
                    required property int index
                    required property date fileModified
                    required property var fileSize
                    readonly property string freshnessToken: `${Number(fileModified)}:${Number(fileSize)}`
                    readonly property string wallpaperPath: selector.fileUrlToPath(filePath)

                    readonly property bool cardActive: Math.abs(index - wallpaperList.viewportIndex) <= selector.residencyRadius
                    // Only resident delegates need transition-dependent geometry.
                    readonly property real distance: cardActive ? Math.abs(index - wallpaperList.focusIndex()) : 0
                    readonly property bool isSelected: cardActive
                        && index === wallpaperList.transitionToIndex
                        && !wallpaperList.transitionRunning
                    readonly property real depth: Math.min(distance, selector.residencyRadius)
                    readonly property real finalWidth: cardActive
                        ? wallpaperList.sideWidth
                            + (wallpaperList.selectedWidth - wallpaperList.sideWidth) * wallpaperList.weight(index)
                        : wallpaperList.sideWidth
                    readonly property real finalX: cardActive
                        ? wallpaperList.centeringMargin + index * wallpaperList.stride
                            + ((wallpaperList.selectedWidth - wallpaperList.sideWidth)
                                * wallpaperList.expansionBefore(index))
                        : wallpaperList.centeringMargin + index * wallpaperList.stride

                    x: finalX
                    width: finalWidth
                    height: wallpaperList.height
                    z: isSelected ? 100 : 50 - distance

                    Loader {
                        anchors.centerIn: parent
                        width: parent.width
                        height: wallpaperList.cardHeight
                        active: selector.visualsActive && cardActive
                        sourceComponent: wallpaperCardComponent
                    }

                    Component {
                        id: wallpaperCardComponent

                        WallpaperCard {
                            anchors.fill: parent
                            renderWidth: wallpaperList.selectedWidth
                            path: wallpaperPath
                            thumbnailPath: thumbnailCache.sourceFor(wallpaperPath)
                                thumbnailCached: thumbnailPath !== selector.pathToFileUrl(wallpaperPath)
                            selected: isSelected
                                focusWeight: wallpaperList.weight(index)
                            Component.onCompleted: thumbnailCache.request(wallpaperPath, freshnessToken)
                            Connections {
                                target: wallpaperFolderModel
                            function onDataChanged() { thumbnailCache.request(wallpaperPath, freshnessToken) }
                            }
                            opacity: Math.max(0.22, 1 - depth * 0.14)
                            Connections {
                                target: thumbnailCache
                            function onThumbnailReady(sourcePath, thumbnailUrl) {
                                    if (sourcePath === wallpaperPath)
                                        thumbnailPath = thumbnailUrl
                                }
                            }
                            onActivated: {
                                if (isSelected)
                                    selector.setWallpaper(wallpaperPath)
                                else
                                    selector.selectIndex(index)
                            }
                            onWheelStepped: direction => selector.moveSelection(direction)
                        }
                    }
                }
            }
        }
    }

    }

    PanelWindow {
        id: panel

        visible: false
        onVisibleChanged: selector.visualsActive = visible
            aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        mask: null
        color: selector.theme.colors.transparent
        surfaceFormat.opaque: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        Rectangle {
            anchors.fill: parent
            color: selector.theme.colors.scrim
            focus: true

            Keys.onEscapePressed: selector.close()
            Keys.onLeftPressed: selector.moveSelection(-1)
            Keys.onRightPressed: selector.moveSelection(1)
            Keys.onUpPressed: selector.moveSelection(-2)
            Keys.onDownPressed: selector.moveSelection(2)
            Keys.onReturnPressed: selector.applySelection()
            Keys.onEnterPressed: selector.applySelection()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: selector.close()
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - selector.theme.spacing.wallpaperSelectorScreenMargin, selector.theme.sizing.appLauncherMaxWidth)
                height: Math.min(parent.height - selector.theme.spacing.wallpaperSelectorScreenMargin, selector.theme.sizing.appLauncherMaxHeight)
                radius: selector.theme.shape.wallpaperSelectorRadius
                color: selector.theme.colors.panel
                border.width: selector.theme.shape.wallpaperSelectorBorderWidth
                border.color: selector.theme.colors.border

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Loader {
                    id: contentLoader

                    anchors.fill: parent
                    active: true
                    sourceComponent: selectorContent
                }
            }
        }
    }

    FolderListModel {
        id: wallpaperFolderModel

        showDirsFirst: false
        showDotAndDotDot: false
        showHidden: false
        caseSensitive: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr"]
        showFiles: true
        showDirs: false
        sortField: FolderListModel.Name
        folder: selector.wallpapersFolderUrl

        onCountChanged: selector.scheduleClampSelection()
        onStatusChanged: selector.scheduleClampSelection()
    }

    Timer {
        id: clampSelectionTimer
        interval: 0
        repeat: false
        onTriggered: selector.clampSelection()
    }

    Timer {
        id: enableTransitionsTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (panel.visible)
                selector.transitionsEnabled = true
        }
    }

    function open() {
        enableTransitionsTimer.stop()
        transitionsEnabled = false
        visualsActive = true
            selectedIndex = 0
        clampSelection()
        contentItem?.wallpaperListView?.jumpToIndex(selectedIndex)
        panel.visible = true
        enableTransitionsTimer.start()
    }

    function close() {
        enableTransitionsTimer.stop()
        transitionsEnabled = false
        contentItem?.wallpaperListView?.stopTransition()
            panel.visible = false
            visualsActive = false

        if (quitOnClose)
            Qt.quit()
    }

    function toggle() {
        panel.visible ? close() : open()
    }

    function moveSelection(direction) {
        const count = wallpaperFolderModel.count
        if (count === 0)
            return

        selector.selectIndex(Math.max(0, Math.min(count - 1, selector.selectedIndex + direction)))
    }

    function selectIndex(index) {
        if (index < 0 || index >= wallpaperFolderModel.count)
            return

        const list = contentItem?.wallpaperListView
        if (list)
            list.requestIndex(index)
        else
            selectedIndex = index
    }

    function applySelection() {
        const path = selectedWallpaperPath
        if (path.length > 0)
            selector.setWallpaper(path)
    }

    function scheduleClampSelection() {
        if (!clampSelectionTimer.running)
            clampSelectionTimer.start()
    }

    function clampSelection() {
        const nextIndex = Math.min(selector.selectedIndex, Math.max(0, wallpaperFolderModel.count - 1))
        if (selector.selectedIndex !== nextIndex)
            selector.selectedIndex = nextIndex
    }

    function fileUrlToPath(url) {
        return decodeURIComponent(String(url || "").replace(/^file:\/\//, ""))
    }

    function pathToFileUrl(path) {
        const value = String(path || "")
        return value.length > 0 ? "file://" + value.split('/').map(segment => encodeURIComponent(segment)).join('/') : ""
    }

    function setWallpaper(path) {
        if (!path || path.length === 0)
            return

        Quickshell.execDetached(["awww", "img", path, ...selector.transitionArgs])
        AppSettings.setCurrentWallpaper(path)
        selector.close()
    }
}
