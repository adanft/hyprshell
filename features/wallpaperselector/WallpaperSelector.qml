import "../../shared/components" as Shared
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../theme/runtime"

Scope {
    id: selector

    readonly property var theme: AppTheme
    readonly property var icons: Icons
    property alias visible: panel.visible
    property bool quitOnClose: false
    readonly property var contentItem: contentLoader.item

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string wallpapersDir: Quickshell.env("AWWW_WALLPAPERS_DIR") || `${home}/Wallpapers`
    readonly property string wallpapersFolderUrl: wallpapersDir ? "file://" + wallpapersDir.split('/').map(segment => encodeURIComponent(
                                                                                                                          segment)).join(
                                                                      '/') : ""
    readonly property var transitionArgs: ["--transition-type", "center", "--transition-duration", "1.0",
        "--transition-fps", "60"]

    property string searchText: ""
    property int selectedIndex: 0
    readonly property var extensionFilters: ["png", "jpg", "gif"]
    readonly property var extensionFilterIcons: ({
            "png": Icons.fileFormat.png,
            "jpg": Icons.fileFormat.jpg,
            "gif": Icons.fileFormat.gif
        })
    property var activeExtensions: []
    readonly property var filteredIndices: computeFilteredIndices()
    readonly property string selectedWallpaperPath: filteredIndices.length > selectedIndex && selectedIndex >= 0 ?
                                                     fileUrlToPath(wallpaperFolderModel.get(
                                                                       filteredIndices[selectedIndex], "filePath")) : ""

    function computeFilteredIndices() {
        const query = searchText.trim().toLowerCase()
        const indices = []
        for (let i = 0; i < wallpaperFolderModel.count; i++) {
            const name = String(wallpaperFolderModel.get(i, "fileName") || "")
            const suffix = String(wallpaperFolderModel.get(i, "fileSuffix") || "").toLowerCase()
            const matchesQuery = query.length === 0 || name.toLowerCase().includes(query)
            const matchesExtension = activeExtensions.length === 0 || activeExtensions.includes(suffix)
            if (matchesQuery && matchesExtension)
                indices.push(i)
        }
        return indices
    }

    function toggleExtensionFilter(extension) {
        activeExtensions = activeExtensions.includes(extension) ? activeExtensions.filter(
                                                                        item => item !== extension) : [
                                                                        ...activeExtensions, extension]
        selectedIndex = 0
    }

    WallpaperThumbnailCache {
        id: thumbnailCache
    }

    Component {
        id: selectorContent

        Column {
            id: content

            property alias searchField: searchInput
            property alias appGrid: grid
            readonly property int columns: WallpaperSizing.gridColumns
            readonly property int cellWidth: WallpaperSizing.cardWidth
                                             + selector.theme.spacing.space6
            readonly property int cellHeight: WallpaperSizing.cardHeight
                                              + selector.theme.spacing.space6
                                              + WallpaperSizing.cardLabelHeight
                                              + selector.theme.spacing.space6
            readonly property int gridWidth: columns * cellWidth

            anchors.fill: parent
            anchors.margins: selector.theme.spacing.space12
            spacing: selector.theme.spacing.space12

            Item {
                width: content.gridWidth
                height: selector.theme.sizing.searchFieldHeight
                anchors.horizontalCenter: parent.horizontalCenter

                Row {
                    id: extensionFiltersRow

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: selector.theme.spacing.space12

                    Repeater {
                        model: selector.extensionFilters

                        WallpaperExtensionFilter {
                            required property string modelData

                            icon: selector.extensionFilterIcons[modelData]
                            selected: selector.activeExtensions.includes(modelData)
                            onActivated: selector.toggleExtensionFilter(modelData)
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - extensionFiltersRow.width - selector.theme.spacing.space12
                    height: parent.height
                    radius: selector.theme.shape.appLauncherSearchRadius
                    color: Colors.surface

                    Shared.AppText {
                        anchors.left: parent.left
                        anchors.leftMargin: selector.theme.spacing.space16
                        anchors.verticalCenter: parent.verticalCenter
                        width: selector.theme.sizing.searchFieldIconSlotWidth
                        text: selector.icons.ui.search
                        color: Colors.on_surface_variant
                        font.family: selector.theme.typography.iconFontFamily
                        font.pixelSize: selector.theme.typography.textBase
                        font.styleName: selector.theme.typography.styleMedium
                        horizontalAlignment: Text.AlignLeft
                    }

                    Shared.AppText {
                        anchors.left: parent.left
                        anchors.leftMargin: selector.theme.spacing.space16
                                            + selector.theme.sizing.searchFieldIconSlotWidth
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length === 0
                        text: "Search..."
                        color: Colors.on_surface_variant
                        font.pixelSize: selector.theme.typography.textBase
                        font.styleName: selector.theme.typography.styleMedium
                    }

                    TextInput {
                        id: searchInput

                        anchors.fill: parent
                        anchors.leftMargin: selector.theme.spacing.space16
                                            + selector.theme.sizing.searchFieldIconSlotWidth
                        anchors.rightMargin: selector.theme.spacing.space16
                        clip: true
                        color: Colors.on_surface
                        selectionColor: Colors.primary
                        selectedTextColor: Colors.on_primary
                        font.family: selector.theme.typography.textFontFamily
                        font.pixelSize: selector.theme.typography.textBase
                        font.styleName: selector.theme.typography.styleMedium
                        verticalAlignment: TextInput.AlignVCenter
                        text: selector.searchText
                        onTextChanged: selector.searchText = text
                        Keys.onEscapePressed: selector.close()
                        Keys.onLeftPressed: event => {
                            if (cursorPosition === 0)
                                selector.moveSelection(-1)
                            else
                                event.accepted = false
                        }
                        Keys.onRightPressed: event => {
                            if (cursorPosition === text.length)
                                selector.moveSelection(1)
                            else
                                event.accepted = false
                        }
                        Keys.onUpPressed: selector.moveSelection(-grid.columns)
                        Keys.onDownPressed: selector.moveSelection(grid.columns)
                        Keys.onReturnPressed: selector.applySelection()
                        Keys.onEnterPressed: selector.applySelection()
                    }
                }
            }

            GridView {
                id: grid

                readonly property int columns: content.columns

                width: columns * cellWidth
                height: parent.height - selector.theme.sizing.searchFieldHeight - parent.spacing
                anchors.horizontalCenter: parent.horizontalCenter
                clip: true
                cellWidth: content.cellWidth
                cellHeight: content.cellHeight
                model: selector.filteredIndices
                currentIndex: selector.selectedIndex

                Text {
                    anchors.centerIn: parent
                    visible: selector.filteredIndices.length === 0
                    width: parent.width - selector.theme.spacing.space80
                    text: selector.searchText.length > 0 ? `No wallpapers match "${selector.searchText}"` :
                                                           `No wallpapers found. Add images to ${selector.wallpapersDir}`
                    color: Colors.on_surface_variant
                    font.pixelSize: selector.theme.typography.textBase
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                delegate: Item {
                    id: cell

                    required property int index
                    required property int modelData

                    width: grid.cellWidth
                    height: grid.cellHeight

                    WallpaperCard {
                        id: wallpaperCard

                        readonly property string wallpaperPath: selector.fileUrlToPath(
                                                                     wallpaperFolderModel.get(cell.modelData,
                                                                                              "filePath"))
                        readonly property string wallpaperLabel: String(
                            wallpaperFolderModel.get(cell.modelData, "fileName") || "")

                        anchors.centerIn: parent
                        width: WallpaperSizing.cardWidth
                        height: WallpaperSizing.cardHeight
                               + selector.theme.spacing.space6
                               + WallpaperSizing.cardLabelHeight
                        path: wallpaperPath
                        label: wallpaperLabel
                        thumbnailPath: thumbnailCache.sourceFor(wallpaperPath)
                        thumbnailCached: thumbnailPath !== selector.pathToFileUrl(wallpaperPath)
                        selected: selector.selectedIndex === cell.index
                        isActive: wallpaperPath === AppSettings.currentWallpaper

                        onActivated: selector.setWallpaper(wallpaperPath)

                        Component.onCompleted: thumbnailCache.request(wallpaperPath, selector.freshnessTokenForIndex(
                                                                           cell.modelData))
                        Connections {
                            target: thumbnailCache
                            function onThumbnailReady(sourcePath, thumbnailUrl) {
                                if (sourcePath === wallpaperCard.wallpaperPath)
                                    wallpaperCard.thumbnailPath = thumbnailUrl
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
        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        mask: null
        color: "transparent"
        surfaceFormat.opaque: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "qs-wallpaperselector"

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colors.shadow, 0.5)
            focus: true

            Keys.onEscapePressed: selector.close()
            Keys.onLeftPressed: selector.moveSelection(-1)
            Keys.onRightPressed: selector.moveSelection(1)
            Keys.onUpPressed: selector.moveSelection(-WallpaperSizing.gridColumns)
            Keys.onDownPressed: selector.moveSelection(WallpaperSizing.gridColumns)
            Keys.onReturnPressed: selector.applySelection()
            Keys.onEnterPressed: selector.applySelection()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: selector.close()
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - selector.theme.spacing.space96,
                                WallpaperSizing.maxWidth)
                height: Math.min(parent.height - selector.theme.spacing.space96,
                                 WallpaperSizing.maxHeight)
                radius: selector.theme.shape.wallpaperSelectorRadius
                color: Colors.shadow

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

    function open() {
        searchText = ""
        activeExtensions = []
        selectedIndex = 0
        clampSelection()
        panel.visible = true
        Qt.callLater(() => contentItem?.searchField?.forceActiveFocus())
    }

    function close() {
        panel.visible = false

        if (quitOnClose)
            Qt.quit()
    }

    function toggle() {
        panel.visible ? close() : open()
    }

    onSearchTextChanged: selectedIndex = 0

    function moveSelection(direction) {
        const count = filteredIndices.length
        if (count === 0)
            return
        selector.selectIndex(Math.max(0, Math.min(count - 1, selector.selectedIndex + direction)))
    }

    function selectIndex(index) {
        if (index < 0 || index >= filteredIndices.length)
            return
        selectedIndex = index
    }

    function applySelection() {
        const path = selectedWallpaperPath
        if (path.length > 0)
            selector.setWallpaper(path)
    }

    function freshnessTokenForIndex(index) {
        if (index < 0 || index >= wallpaperFolderModel.count)
            return ""
        const modified = wallpaperFolderModel.get(index, "fileModified")
        const size = wallpaperFolderModel.get(index, "fileSize")
        return `${Number(modified)}:${Number(size)}`
    }

    function scheduleClampSelection() {
        if (!clampSelectionTimer.running)
            clampSelectionTimer.start()
    }

    function clampSelection() {
        const nextIndex = Math.min(selector.selectedIndex, Math.max(0, filteredIndices.length - 1))
        if (selector.selectedIndex !== nextIndex)
            selector.selectedIndex = nextIndex
    }

    function fileUrlToPath(url) {
        return decodeURIComponent(String(url || "").replace(/^file:\/\//, ""))
    }

    function pathToFileUrl(path) {
        const value = String(path || "")
        return value.length > 0 ? "file://" + value.split('/').map(segment => encodeURIComponent(segment)).join('/') :
                                  ""
    }

    function setWallpaper(path) {
        if (!path || path.length === 0)
            return
        Quickshell.execDetached(["awww", "img", path, ...selector.transitionArgs])
        AppSettings.setCurrentWallpaper(path)
        selector.close()
    }
}
