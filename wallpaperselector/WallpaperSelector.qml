import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

Scope {
    id: selector

    readonly property var theme: AppTheme {}
    property alias visible: panel.visible
    property bool quitOnClose: false

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string wallpapersDir: Quickshell.env("AWWW_WALLPAPERS_DIR") || `${home}/Wallpapers`
    readonly property var transitionArgs: [
        "--transition-type", "center",
        "--transition-duration", "1.0",
        "--transition-fps", "60"
    ]

    property int selectedIndex: 0
    property var wallpapers: []

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
                    model: selector.wallpapers
                    currentIndex: selector.selectedIndex

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: grid.cellWidth
                        height: grid.cellHeight

                        WallpaperCard {
                            anchors.centerIn: parent
                            path: modelData
                            selected: selector.selectedIndex === index
                            onHovered: selector.selectedIndex = index
                            onActivated: selector.setWallpaper(modelData)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: selector.wallpapers.length === 0
                        width: parent.width - selector.theme.wallpaperSelectorEmptyTextHorizontalMargin
                        text: `No wallpapers found in ${selector.wallpapersDir}`
                        color: selector.theme.wallpaperSelectorEmptyTextColor
                        font.pixelSize: selector.theme.wallpaperSelectorEmptyFontSize
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    Process {
        running: true
        command: [
            "find", "-L", selector.wallpapersDir,
            "-regextype", "posix-extended",
            "-type", "f",
            "-iregex", ".*\\.(jpg|jpeg|png|webp|tif|tiff|gif|bmp|avif)"
        ]

        stdout: StdioCollector {
            onStreamFinished: selector.loadWallpapers(text)
        }
    }

    function open() {
        selectedIndex = Math.min(selectedIndex, Math.max(0, wallpapers.length - 1))
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
        const count = selector.wallpapers.length
        if (count === 0)
            return

        selector.selectedIndex = Math.max(0, Math.min(count - 1, selector.selectedIndex + direction))
        grid.positionViewAtIndex(selector.selectedIndex, GridView.Contain)
    }

    function applySelection() {
        const entry = selector.wallpapers[selector.selectedIndex]
        if (entry)
            selector.setWallpaper(entry)
    }

    function loadWallpapers(output) {
        selector.wallpapers = (output || "")
            .split("\n")
            .filter(path => path.length > 0)
            .sort((a, b) => a.localeCompare(b))

        selector.selectedIndex = Math.min(selector.selectedIndex, Math.max(0, selector.wallpapers.length - 1))
    }

    function setWallpaper(path) {
        if (!path || path.length === 0)
            return

        Quickshell.execDetached(["awww", "img", path, ...selector.transitionArgs])
        selector.close()
    }
}
