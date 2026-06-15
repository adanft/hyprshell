import "../shared/components" as Shared
import "../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: selector

    readonly property var theme: AppTheme {}
    readonly property var themes: StockThemes.availableThemes
    readonly property var filteredThemes: filterThemes(searchText)
    property alias visible: panel.visible
    property bool quitOnClose: false
    property string searchText: ""
    property int selectedIndex: 0
    property int previewIndex: 0
    readonly property var contentItem: contentLoader.item

    function open() {
        searchText = ""
        selectedIndex = 0
        previewIndex = 0
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

    function moveSelection(direction) {
        selectIndex(selectedIndex + direction)
    }

    function selectIndex(index) {
        const count = filteredThemes.length
        if (count === 0)
            return

        selectedIndex = Math.max(0, Math.min(count - 1, index))
        previewIndex = selectedIndex
        contentItem?.themeListView?.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function previewThemeData() {
        return filteredThemes[previewIndex]
    }

    function applySelection() {
        const selectedTheme = filteredThemes[selectedIndex]
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

    function filterThemes(query) {
        const normalizedQuery = normalizeText(query)
        if (normalizedQuery.length === 0)
            return themes

        return themes.filter(themeData => searchableText(themeData).includes(normalizedQuery))
    }

    function searchableText(themeData) {
        return [themeData ? themeData.name : "", themeData ? themeData.displayName : ""].map(normalizeText).join(" ")
    }

    function normalizeText(value) {
        return String(value || "").toLowerCase()
    }

    function handleNavigationKey(event, allowHomeEnd, allowSpace) {
        if (allowHomeEnd && event.key === Qt.Key_Home) {
            selectIndex(0)
            event.accepted = true
        } else if (allowHomeEnd && event.key === Qt.Key_End) {
            selectIndex(filteredThemes.length - 1)
            event.accepted = true
        } else if (allowSpace && event.key === Qt.Key_Space) {
            applySelection()
            event.accepted = true
        } else {
            event.accepted = false
        }
    }

    onSearchTextChanged: {
        selectedIndex = 0
        previewIndex = 0
        contentItem?.themeListView?.positionViewAtBeginning()
    }

    onFilteredThemesChanged: {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, filteredThemes.length - 1)))
        previewIndex = Math.max(0, Math.min(previewIndex, Math.max(0, filteredThemes.length - 1)))
    }

    Component {
        id: selectorContent

        Column {
            property alias searchField: searchInput
            property alias themeListView: themeList

            anchors.fill: parent
            anchors.margins: selector.theme.spacing.appLauncherPadding
            spacing: selector.theme.spacing.appLauncherSectionSpacing

            Rectangle {
                width: parent.width
                height: selector.theme.sizing.appLauncherSearchHeight
                radius: selector.theme.shape.appLauncherSearchRadius
                color: selector.theme.colors.surfaceActive
                border.width: selector.theme.shape.appLauncherSearchBorderWidth
                border.color: searchInput.activeFocus ? selector.theme.colors.focus : selector.theme.colors.border

                Shared.AppText {
                    anchors.left: parent.left
                    anchors.leftMargin: selector.theme.spacing.appLauncherSearchHorizontalPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: selector.theme.sizing.appLauncherSearchIconSlotWidth
                    text: ""
                    color: searchInput.activeFocus ? selector.theme.colors.focus : selector.theme.colors.textSubtle
                    font.family: selector.theme.typography.iconFontFamily
                    font.pixelSize: selector.theme.typography.sizeLg
                    font.styleName: selector.theme.typography.styleMedium
                    horizontalAlignment: Text.AlignLeft
                }

                Shared.AppText {
                    anchors.left: parent.left
                    anchors.leftMargin: selector.theme.spacing.appLauncherSearchHorizontalPadding + selector.theme.sizing.appLauncherSearchIconSlotWidth
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    text: "Search Themes"
                    color: selector.theme.colors.textSubtle
                    font.pixelSize: selector.theme.typography.sizeLg
                    font.styleName: selector.theme.typography.styleMedium
                }

                TextInput {
                    id: searchInput

                    anchors.fill: parent
                    anchors.leftMargin: selector.theme.spacing.appLauncherSearchHorizontalPadding + selector.theme.sizing.appLauncherSearchIconSlotWidth
                    anchors.rightMargin: selector.theme.spacing.appLauncherSearchHorizontalPadding
                    clip: true
                    color: selector.theme.colors.text
                    selectionColor: selector.theme.colors.selection
                    selectedTextColor: selector.theme.colors.selectionText
                    font.family: selector.theme.typography.textFontFamily
                    font.pixelSize: selector.theme.typography.sizeLg
                    font.styleName: selector.theme.typography.styleMedium
                    verticalAlignment: TextInput.AlignVCenter
                    text: selector.searchText
                    onTextChanged: selector.searchText = text
                    Keys.onEscapePressed: selector.close()
                    Keys.onLeftPressed: (event) => {
                        if (cursorPosition === 0)
                            selector.moveSelection(-1)
                        else
                            event.accepted = false
                    }
                    Keys.onRightPressed: (event) => {
                        if (cursorPosition === text.length)
                            selector.moveSelection(1)
                        else
                            event.accepted = false
                    }
                    Keys.onUpPressed: selector.moveSelection(-1)
                    Keys.onDownPressed: selector.moveSelection(1)
                    Keys.onReturnPressed: selector.applySelection()
                    Keys.onEnterPressed: selector.applySelection()
                    Keys.onPressed: (event) => selector.handleNavigationKey(event, text.length === 0, false)
                }
            }

            Row {
                width: parent.width
                height: parent.height - selector.theme.sizing.appLauncherSearchHeight - parent.spacing
                spacing: selector.theme.spacing.appLauncherSectionSpacing

                Item {
                    width: parent.width - themeList.width - parent.spacing
                    height: parent.height

                    Rectangle {
                        id: preview

                        readonly property var themeData: selector.previewThemeData()
                        readonly property var previewColors: themeData && themeData.previewColors ? themeData.previewColors : []

                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Math.min(parent.height, Math.round(width * 16 / 9))
                        visible: preview.themeData !== undefined
                        clip: true
                        radius: selector.theme.shape.appLauncherCardRadius
                        color: themeData && themeData.background ? themeData.background : selector.theme.colors.surface

                        Column {
                            anchors.fill: parent
                            anchors.margins: selector.theme.spacing.space16
                            spacing: selector.theme.spacing.space16

                            Item {
                                width: parent.width
                                height: (parent.height - parent.spacing) / 2

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height
                                    radius: selector.theme.shape.radius12
                                    color: preview.themeData && preview.themeData.surface ? preview.themeData.surface : selector.theme.colors.surfaceActive
                                }
                            }

                            Item {
                                id: paletteContainer

                                width: parent.width
                                height: (parent.height - parent.spacing) / 2

                                readonly property int paletteColumns: 3
                                readonly property int paletteRows: Math.ceil(preview.previewColors.length / paletteColumns)
                                readonly property int paletteDotSize: 40

                                Grid {
                                    id: palette

                                    anchors.centerIn: parent
                                    width: paletteContainer.paletteColumns * paletteContainer.paletteDotSize + (paletteContainer.paletteColumns - 1) * spacing
                                    height: paletteContainer.paletteRows * paletteContainer.paletteDotSize + Math.max(0, paletteContainer.paletteRows - 1) * spacing
                                    columns: paletteContainer.paletteColumns
                                    spacing: selector.theme.spacing.space12

                                    Repeater {
                                        model: preview.previewColors

                                        Rectangle {
                                            required property color modelData

                                            width: paletteContainer.paletteDotSize
                                            height: width
                                            radius: width / 2
                                            color: modelData
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: themeList

                    width: selector.theme.sizing.appLauncherGridCellWidth * 2
                    height: parent.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    orientation: ListView.Vertical
                    spacing: selector.theme.spacing.space6
                    model: selector.filteredThemes
                    currentIndex: selector.selectedIndex
                    highlightFollowsCurrentItem: false

                    Shared.AppText {
                        anchors.centerIn: parent
                        visible: selector.filteredThemes.length === 0
                        width: parent.width
                        text: "No themes found"
                        color: selector.theme.colors.textMuted
                        font.pixelSize: selector.theme.typography.sizeLg
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: themeList.width
                        height: selector.theme.sizing.appLauncherGridCellHeight

                        ThemeCard {
                            anchors.centerIn: parent
                            width: selector.theme.sizing.appLauncherCardWidth * 2
                            height: selector.theme.sizing.appLauncherCardHeight
                            themeData: modelData
                            selected: selector.selectedIndex === index
                            activeTheme: selector.theme.colors.currentTheme === modelData.name
                            onPointerEntered: selector.previewIndex = index
                            onPointerExited: {
                                if (selector.previewIndex === index)
                                    selector.previewIndex = selector.selectedIndex
                            }
                            onActivated: selector.activateIndex(index)
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
            Keys.onPressed: (event) => selector.handleNavigationKey(event, true, true)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: selector.close()
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - selector.theme.spacing.appLauncherScreenMargin, selector.theme.sizing.appLauncherMaxWidth)
                height: Math.min(parent.height - selector.theme.spacing.appLauncherScreenMargin, selector.theme.sizing.appLauncherMaxHeight)
                radius: selector.theme.shape.appLauncherRadius
                color: selector.theme.colors.panel
                border.width: selector.theme.shape.appLauncherBorderWidth
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
