import QtQuick
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

    PanelWindow {
        id: panel

        visible: false
        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        mask: null
        color: "transparent"
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
            color: selector.theme.overlayScrimColor
            focus: true

            Keys.onEscapePressed: selector.close()
            Keys.onLeftPressed: selector.moveSelection(-1)
            Keys.onRightPressed: selector.moveSelection(1)
            Keys.onUpPressed: selector.moveSelection(-grid.columns)
            Keys.onDownPressed: selector.moveSelection(grid.columns)
            Keys.onReturnPressed: selector.applySelection()
            Keys.onEnterPressed: selector.applySelection()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: selector.close()
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - selector.theme.wallpaperSelectorScreenMargin, selector.theme.wallpaperSelectorMaxWidth)
                height: Math.min(parent.height - selector.theme.wallpaperSelectorScreenMargin, selector.theme.wallpaperSelectorMaxHeight)
                radius: selector.theme.wallpaperSelectorRadius
                color: selector.theme.wallpaperSelectorBackgroundColor
                border.width: selector.theme.wallpaperSelectorBorderWidth
                border.color: selector.theme.wallpaperSelectorBorderColor

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                GridView {
                    id: grid

                    readonly property int minCellWidth: selector.theme.wallpaperSelectorGridMinCellWidth
                    readonly property int columns: Math.max(1, Math.floor(width / minCellWidth))

                    anchors.fill: parent
                    anchors.margins: selector.theme.wallpaperSelectorGridMargin
                    clip: true

                    cellWidth: width / columns
                    cellHeight: selector.theme.wallpaperSelectorGridCellHeight
                    model: wallpaperFolderModel
                    currentIndex: selector.selectedIndex

                    delegate: Item {
                        required property string filePath
                        required property int index

                        readonly property string wallpaperPath: String(filePath || "").replace(/^file:\/\//, "")

                        width: grid.cellWidth
                        height: grid.cellHeight

                        WallpaperCard {
                            anchors.centerIn: parent
                            path: wallpaperPath
                            selected: selector.selectedIndex === index
                            onHovered: selector.selectedIndex = index
                            onActivated: selector.setWallpaper(wallpaperPath)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: wallpaperFolderModel.status !== FolderListModel.Loading && wallpaperFolderModel.count === 0
                        width: parent.width - selector.theme.wallpaperSelectorEmptyTextHorizontalMargin
                        text: `No wallpapers found. Add images to ${selector.wallpapersDir}`
                        color: selector.theme.wallpaperSelectorEmptyTextColor
                        font.pixelSize: selector.theme.wallpaperSelectorEmptyFontSize
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
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
        grid.positionViewAtIndex(selector.selectedIndex, GridView.Contain)
    }

    function applySelection() {
        const entry = wallpaperFolderModel.get(selector.selectedIndex, "filePath")
        if (entry)
            selector.setWallpaper(String(entry).replace(/^file:\/\//, ""))
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
