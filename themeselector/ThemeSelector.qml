import "../shared/components" as Shared
import "../theme"
import "../theme/runtime"
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: selector

    readonly property var theme: AppTheme
    readonly property var icons: Icons
    readonly property var themes: StockThemes.availableThemes
    property alias visible: panel.visible
    property bool quitOnClose: false
    property int selectedIndex: 0
    readonly property var contentItem: contentLoader.item

    property string searchText: ""
    readonly property var variantFilters: ["dark", "light"]
    property var activeVariants: []
    readonly property var filteredThemes: computeFilteredThemes()

    function themeCardHeight() {
        const nameLineHeight = theme.typography.sizeMd + theme.spacing.space4
        return theme.spacing.appLauncherCardPadding * 2 + theme.typography.actionIconFontSize
                + theme.spacing.appLauncherCardSpacing + nameLineHeight
    }

    function isDarkBackground(hex) {
        const value = String(hex || "").replace("#", "")
        if (value.length < 6)
            return true
        const r = parseInt(value.substring(0, 2), 16) / 255
        const g = parseInt(value.substring(2, 4), 16) / 255
        const b = parseInt(value.substring(4, 6), 16) / 255
        const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance < 0.5
    }

    function computeFilteredThemes() {
        const query = searchText.trim().toLowerCase()
        return themes.filter(themeData => {
            const matchesQuery = query.length === 0 || themeData.displayName.toLowerCase().includes(query)
            const variant = isDarkBackground(themeData.surface) ? "dark" : "light"
            const matchesVariant = activeVariants.length === 0 || activeVariants.includes(variant)
            return matchesQuery && matchesVariant
        })
    }

    function toggleVariantFilter(variant) {
        activeVariants = activeVariants.includes(variant) ? activeVariants.filter(
                                                                  item => item !== variant) : [...activeVariants,
            variant]
        selectedIndex = 0
    }

    function open() {
        searchText = ""
        activeVariants = []
        selectedIndex = 0
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
        const nextIndex = Math.max(0, Math.min(count - 1, index))
        const selectionChanged = selectedIndex !== nextIndex

        if (selectionChanged)
            selectedIndex = nextIndex
        if (selectionChanged && contentItem && contentItem.themeGridView)
            contentItem.themeGridView.positionViewAtIndex(nextIndex, GridView.Contain)
    }

    function applySelection() {
        const selectedTheme = filteredThemes[selectedIndex]
        if (!selectedTheme)
            return
        StockThemes.setTheme(selectedTheme.name)
        close()
    }

    function activateIndex(index) {
        selectIndex(index)
        applySelection()
    }

    function selectTheme(name) {
        StockThemes.setTheme(name)
    }

    function handleNavigationKey(event) {
        if (event.key === Qt.Key_Home) {
            selectIndex(0)
            event.accepted = true
        } else if (event.key === Qt.Key_End) {
            selectIndex(filteredThemes.length - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            applySelection()
            event.accepted = true
        } else {
            event.accepted = false
        }
    }

    onThemesChanged: {
        const maxIndex = Math.max(0, filteredThemes.length - 1)
        const nextSelectedIndex = Math.max(0, Math.min(selectedIndex, maxIndex))

        if (selectedIndex !== nextSelectedIndex)
            selectedIndex = nextSelectedIndex
    }

    onSearchTextChanged: selectedIndex = 0

    Component {
        id: selectorContent

        Column {
            id: content

            property alias themeGridView: themeGrid
            property alias searchField: searchInput
            readonly property int contentWidth: selector.theme.sizing.themeSelectorCellWidth
                                                * selector.theme.sizing.themeSelectorGridColumns

            anchors.fill: parent
            anchors.margins: selector.theme.spacing.themeSelectorPadding
            spacing: selector.theme.spacing.space12

            Item {
                width: content.contentWidth
                height: selector.theme.sizing.appLauncherSearchHeight
                anchors.horizontalCenter: parent.horizontalCenter

                Row {
                    id: variantFiltersRow

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: selector.theme.spacing.space12

                    Repeater {
                        model: selector.variantFilters

                        ThemeVariantFilter {
                            required property string modelData

                            icon: modelData === "dark" ? "" : ""
                            selected: selector.activeVariants.includes(modelData)
                            onActivated: selector.toggleVariantFilter(modelData)
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - variantFiltersRow.width - selector.theme.spacing.space12
                    height: parent.height
                    radius: selector.theme.shape.appLauncherSearchRadius
                    color: Colors.surface

                    Shared.AppText {
                        anchors.left: parent.left
                        anchors.leftMargin: selector.theme.spacing.appLauncherSearchHorizontalPadding
                        anchors.verticalCenter: parent.verticalCenter
                        width: selector.theme.sizing.appLauncherSearchIconSlotWidth
                        text: selector.icons.search
                        color: Colors.on_surface_variant
                        font.family: selector.theme.typography.iconFontFamily
                        font.pixelSize: selector.theme.typography.sizeLg
                        font.styleName: selector.theme.typography.styleMedium
                        horizontalAlignment: Text.AlignLeft
                    }

                    Shared.AppText {
                        anchors.left: parent.left
                        anchors.leftMargin: selector.theme.spacing.appLauncherSearchHorizontalPadding
                                            + selector.theme.sizing.appLauncherSearchIconSlotWidth
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length === 0
                        text: "Search..."
                        color: Colors.on_surface_variant
                        font.pixelSize: selector.theme.typography.sizeLg
                        font.styleName: selector.theme.typography.styleMedium
                    }

                    TextInput {
                        id: searchInput

                        anchors.fill: parent
                        anchors.leftMargin: selector.theme.spacing.appLauncherSearchHorizontalPadding
                                            + selector.theme.sizing.appLauncherSearchIconSlotWidth
                        anchors.rightMargin: selector.theme.spacing.appLauncherSearchHorizontalPadding
                        clip: true
                        color: Colors.on_surface
                        selectionColor: Colors.primary
                        selectedTextColor: Colors.on_primary
                        font.family: selector.theme.typography.textFontFamily
                        font.pixelSize: selector.theme.typography.sizeLg
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
                        Keys.onUpPressed: selector.moveSelection(-selector.theme.sizing.themeSelectorGridColumns)
                        Keys.onDownPressed: selector.moveSelection(selector.theme.sizing.themeSelectorGridColumns)
                        Keys.onReturnPressed: selector.applySelection()
                        Keys.onEnterPressed: selector.applySelection()
                        Keys.onPressed: event => selector.handleNavigationKey(event)
                    }
                }
            }

            GridView {
                id: themeGrid

                readonly property int columns: selector.theme.sizing.themeSelectorGridColumns
                readonly property int cardHeight: selector.themeCardHeight()

                width: parent.width
                height: Math.max(0, parent.height - parent.spacing
                                 - selector.theme.sizing.appLauncherSearchHeight)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flow: GridView.FlowLeftToRight
                cellWidth: width / columns
                cellHeight: cardHeight + selector.theme.spacing.space6
                model: selector.filteredThemes
                currentIndex: selector.selectedIndex
                highlightFollowsCurrentItem: false

                Text {
                    anchors.centerIn: parent
                    visible: selector.filteredThemes.length === 0
                    width: parent.width - selector.theme.spacing.wallpaperSelectorEmptyTextHorizontalMargin
                    text: selector.searchText.length > 0 || selector.activeVariants.length > 0 ?
                              "No themes match your filters" : "No themes found"
                    color: Colors.on_surface_variant
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
                        width: parent.width - selector.theme.spacing.space6
                        height: themeGrid.cardHeight
                        themeData: modelData
                        selected: selector.selectedIndex === index
                        isActive: modelData.name === StockThemes.currentTheme
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
            color: Qt.alpha(Colors.shadow, 0.25)
            focus: true

            Keys.onEscapePressed: selector.close()
            Keys.onLeftPressed: selector.moveSelection(-1)
            Keys.onRightPressed: selector.moveSelection(1)
            Keys.onUpPressed: selector.moveSelection(-selector.theme.sizing.themeSelectorGridColumns)
            Keys.onDownPressed: selector.moveSelection(selector.theme.sizing.themeSelectorGridColumns)
            Keys.onReturnPressed: selector.applySelection()
            Keys.onEnterPressed: selector.applySelection()
            Keys.onPressed: event => selector.handleNavigationKey(event)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: selector.close()
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - selector.theme.spacing.wallpaperSelectorScreenMargin,
                                selector.theme.sizing.themeSelectorMaxWidth)
                height: Math.min(parent.height - selector.theme.spacing.wallpaperSelectorScreenMargin,
                                 selector.theme.sizing.themeSelectorMaxHeight)
                radius: selector.theme.shape.wallpaperSelectorRadius
                color: Colors.shadow

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
