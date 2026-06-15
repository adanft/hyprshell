import "../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: selector

    readonly property var theme: AppTheme {}
    readonly property var themes: StockThemes.availableThemes
    property alias visible: panel.visible
    property bool quitOnClose: false
    property int selectedIndex: Math.max(0, StockThemes.names().indexOf(theme.colors.currentTheme))

    Connections {
        target: StockThemes

        function onCurrentThemeChanged() {
            selector.selectedIndex = Math.max(0, StockThemes.names().indexOf(selector.theme.colors.currentTheme))
        }

        function onThemesChanged() {
            selector.selectedIndex = Math.max(0, StockThemes.names().indexOf(selector.theme.colors.currentTheme))
        }
    }

    function open() {
        selectedIndex = Math.max(0, StockThemes.names().indexOf(theme.colors.currentTheme))
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
        selectedIndex = Math.max(0, Math.min(themes.length - 1, selectedIndex + direction))
    }

    function applySelection() {
        const selectedTheme = themes[selectedIndex]
        if (!selectedTheme)
            return

        theme.colors.setTheme(selectedTheme.name)
        close()
    }

    function selectTheme(name) {
        theme.colors.setTheme(name)
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
                width: Math.min(parent.width - selector.theme.spacing.wallpaperSelectorScreenMargin, 720)
                height: Math.min(parent.height - selector.theme.spacing.wallpaperSelectorScreenMargin, 420)
                radius: selector.theme.shape.wallpaperSelectorRadius
                color: selector.theme.colors.panel
                border.width: selector.theme.shape.wallpaperSelectorBorderWidth
                border.color: selector.theme.colors.border

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: selector.theme.spacing.wallpaperSelectorGridMargin
                    spacing: selector.theme.spacing.screenshotToolSectionSpacing

                    GridView {
                        id: grid

                        readonly property int columns: 2
                        readonly property int visibleRows: 3

                        width: parent.width
                        height: parent.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        cellWidth: width / columns
                        cellHeight: height / visibleRows
                        model: selector.themes
                        currentIndex: selector.selectedIndex

                        delegate: Item {
                            required property var modelData
                            required property int index

                            width: grid.cellWidth
                            height: grid.cellHeight

                            ThemeCard {
                                anchors.centerIn: parent
                                width: parent.width - selector.theme.spacing.space12
                                height: parent.height - selector.theme.spacing.space12
                                themeData: modelData
                                selected: selector.selectedIndex === index
                                activeTheme: selector.theme.colors.currentTheme === modelData.name
                                onActivated: {
                                    selector.selectedIndex = index
                                    selector.applySelection()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
