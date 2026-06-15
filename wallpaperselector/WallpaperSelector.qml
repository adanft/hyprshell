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

                width: parent.width
                height: (parent.height - parent.spacing) / 2
                radius: selector.theme.shape.wallpaperCardRadius
                color: selector.theme.colors.background
                clip: true

                Image {
                    anchors.fill: parent
                    source: selector.selectedWallpaperPath
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    visible: source.toString().length > 0
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

            ListView {
                id: wallpaperList

                width: parent.width
                height: (parent.height - parent.spacing) / 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                orientation: ListView.Horizontal
                spacing: selector.theme.spacing.space12
                model: wallpaperFolderModel
                currentIndex: selector.selectedIndex

                delegate: Item {
                    required property string filePath
                    required property int index

                    readonly property string wallpaperPath: String(filePath || "").replace(/^file:\/\//, "")

                    width: selector.theme.sizing.wallpaperSelectorGridMinCellWidth
                    height: wallpaperList.height

                    WallpaperCard {
                        anchors.centerIn: parent
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
            Keys.onUpPressed: selector.moveSelection(-1)
            Keys.onDownPressed: selector.moveSelection(1)
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
        contentItem?.wallpaperListView?.positionViewAtIndex(selector.selectedIndex, ListView.Contain)
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
