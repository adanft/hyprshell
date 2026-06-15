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
    readonly property string selectedWallpaperPath: wallpaperFolderModel.count > selectedIndex ? String(wallpaperFolderModel.get(selectedIndex, "filePath") || "").replace(/^file:\/\//, "") : ""

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
                    source: selector.selectedWallpaperPath
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
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

            GridView {
                id: wallpaperList

                readonly property int columns: 2

                width: parent.width
                height: Math.max(0, parent.height - preview.height - parent.spacing)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flow: GridView.FlowLeftToRight
                cellWidth: width / columns
                cellHeight: Math.round((cellWidth - selector.theme.spacing.space12) * 9 / 16) + selector.theme.spacing.space12
                model: wallpaperFolderModel
                currentIndex: selector.selectedIndex

                delegate: Item {
                    required property string filePath
                    required property int index

                    readonly property string wallpaperPath: String(filePath || "").replace(/^file:\/\//, "")

                    width: wallpaperList.cellWidth
                    height: wallpaperList.cellHeight

                    WallpaperCard {
                        anchors.centerIn: parent
                        width: parent.width - selector.theme.spacing.space12
                        height: Math.round(width * 9 / 16)
                        path: wallpaperPath
                        selected: selector.selectedIndex === index
                        onActivated: selector.setWallpaper(wallpaperPath)
                    }
                }
            }
        }
    }

    PanelWindow {
        id: panel

        visible: false
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
                    active: panel.visible
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
        folder: selector.visible ? selector.wallpapersFolderUrl : ""

        onCountChanged: selector.clampSelection()
        onStatusChanged: selector.clampSelection()
    }

    function open() {
        clampSelection()
        panel.visible = true
    }

    function close() {
        panel.visible = false

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

        selector.selectedIndex = Math.max(0, Math.min(count - 1, selector.selectedIndex + direction))
        contentItem?.wallpaperListView?.positionViewAtIndex(selector.selectedIndex, GridView.Contain)
    }

    function applySelection() {
        const path = selectedWallpaperPath
        if (path.length > 0)
            selector.setWallpaper(path)
    }

    function clampSelection() {
        selector.selectedIndex = Math.min(selector.selectedIndex, Math.max(0, wallpaperFolderModel.count - 1))
    }

    function setWallpaper(path) {
        if (!path || path.length === 0)
            return

        Quickshell.execDetached(["awww", "img", path, ...selector.transitionArgs])
        selector.close()
    }
}
