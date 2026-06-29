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
    property int selectedIndex: 0
    property int previewIndex: 0
    readonly property var contentItem: contentLoader.item

    function open() {
        if (selectedIndex !== 0)
            selectedIndex = 0
        if (previewIndex !== 0)
            previewIndex = 0
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
        selectIndex(selectedIndex + direction)
    }

    function selectIndex(index) {
        const count = themes.length
        if (count === 0)
            return

        const nextIndex = Math.max(0, Math.min(count - 1, index))
        const selectionChanged = selectedIndex !== nextIndex

        if (selectionChanged)
            selectedIndex = nextIndex
        setPreviewIndex(nextIndex)

        if (selectionChanged && contentItem && contentItem.themeGridView)
            contentItem.themeGridView.positionViewAtIndex(nextIndex, GridView.Contain)
    }

    function setPreviewIndex(index) {
        if (previewIndex !== index)
            previewIndex = index
    }

    function previewThemeData() {
        return themes[previewIndex]
    }

    function applySelection() {
        const selectedTheme = themes[selectedIndex]
        if (!selectedTheme)
            return

        theme.colors.setTheme(selectedTheme.name)
        close()
    }

    function activateIndex(index) {
        selectIndex(index)
        applySelection()
    }

    function selectTheme(name) {
        theme.colors.setTheme(name)
    }

    function handleNavigationKey(event) {
        if (event.key === Qt.Key_Home) {
            selectIndex(0)
            event.accepted = true
        } else if (event.key === Qt.Key_End) {
            selectIndex(themes.length - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            applySelection()
            event.accepted = true
        } else {
            event.accepted = false
        }
    }

    onThemesChanged: {
        const maxIndex = Math.max(0, themes.length - 1)
        const nextSelectedIndex = Math.max(0, Math.min(selectedIndex, maxIndex))
        const nextPreviewIndex = Math.max(0, Math.min(previewIndex, maxIndex))

        if (selectedIndex !== nextSelectedIndex)
            selectedIndex = nextSelectedIndex
        if (previewIndex !== nextPreviewIndex)
            previewIndex = nextPreviewIndex
    }

    Component {
        id: selectorContent

        Column {
            property alias themeGridView: themeGrid

            anchors.fill: parent
            anchors.margins: selector.theme.spacing.wallpaperSelectorGridMargin
            spacing: selector.theme.spacing.appLauncherSectionSpacing

            Rectangle {
                id: preview

                readonly property var themeData: selector.previewThemeData()
                readonly property var previewColors: themeData && themeData.previewColors ? themeData.previewColors : []
                readonly property int preferredHeight: Math.round(width * 9 / 16)
                readonly property int minimumGridHeight: selector.theme.sizing.wallpaperCardHeight + selector.theme.spacing.space12

                width: parent.width
                height: Math.min(preferredHeight, Math.max(0, parent.height - parent.spacing - minimumGridHeight))
                radius: selector.theme.shape.wallpaperCardRadius
                color: themeData && themeData.background ? themeData.background : selector.theme.colors.background
                clip: true

                Column {
                    anchors.centerIn: parent
                    width: parent.width - selector.theme.spacing.space24 * 2
                    spacing: selector.theme.spacing.space24

                    Rectangle {
                        id: sceneBar

                        width: Math.min(parent.width, selector.theme.sizing.appLauncherGridCellWidth * 2)
                        height: selector.theme.sizing.statusBarHeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: height / 2
                        color: preview.themeData && preview.themeData.surface ? preview.themeData.surface : selector.theme.colors.surface
                        border.width: selector.theme.shape.borderThin
                        border.color: preview.themeData && preview.themeData.border ? preview.themeData.border : selector.theme.colors.border

                        Row {
                            anchors.centerIn: parent
                            spacing: selector.theme.spacing.space12

                            Repeater {
                                model: preview.previewColors.slice(0, 3)

                                Text {
                                    required property color modelData

                                    text: ""
                                    color: modelData
                                    font.family: selector.theme.typography.iconFontFamily
                                    font.pixelSize: selector.theme.typography.sizeLg
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: preview.themeData ? preview.themeData.displayName : "Theme"
                        color: preview.themeData && preview.themeData.text ? preview.themeData.text : selector.theme.colors.text
                        font.family: selector.theme.typography.textFontFamily
                        font.pixelSize: selector.theme.typography.sizeLg
                        font.styleName: selector.theme.typography.styleSemibold
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: selector.theme.spacing.space24

                        Repeater {
                            model: preview.previewColors.slice(0, 3)

                            Text {
                                required property color modelData

                                text: ""
                                color: modelData
                                font.family: selector.theme.typography.iconFontFamily
                                font.pixelSize: selector.theme.typography.actionIconFontSize
                            }
                        }
                    }

                }
            }

            GridView {
                id: themeGrid

                readonly property int columns: 2

                width: parent.width
                height: Math.max(0, parent.height - preview.height - parent.spacing)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flow: GridView.FlowLeftToRight
                cellWidth: width / columns
                cellHeight: Math.round((cellWidth - selector.theme.spacing.space12) * 9 / 16) + selector.theme.spacing.space12
                model: selector.themes
                currentIndex: selector.selectedIndex
                highlightFollowsCurrentItem: false

                Text {
                    anchors.centerIn: parent
                    visible: selector.themes.length === 0
                    width: parent.width - selector.theme.spacing.wallpaperSelectorEmptyTextHorizontalMargin
                    text: "No themes found"
                    color: selector.theme.colors.textMuted
                    font.pixelSize: selector.theme.typography.sizeLg
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: themeGrid.cellWidth
                    height: themeGrid.cellHeight

                    ThemeCard {
                        anchors.centerIn: parent
                        width: parent.width - selector.theme.spacing.space12
                        height: Math.round(width * 9 / 16)
                        themeData: modelData
                        selected: selector.selectedIndex === index
                        activeTheme: selector.theme.colors.currentTheme === modelData.name
                        onPointerEntered: selector.setPreviewIndex(index)
                        onPointerExited: {
                            if (selector.previewIndex === index)
                                selector.setPreviewIndex(selector.selectedIndex)
                        }
                        onActivated: selector.activateIndex(index)
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
            Keys.onPressed: (event) => selector.handleNavigationKey(event)

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
}
