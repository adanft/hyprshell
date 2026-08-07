import "../shared/components" as Shared
import "../theme"
import "AppLauncherOpenWorkflow.js" as AppLauncherOpenWorkflow
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: launcher

    readonly property var theme: AppTheme
    readonly property var icons: Icons

    property alias visible: panel.visible
    property bool quitOnClose: false
    property string searchText: ""
    property int selectedIndex: 0
    property var apps: []
    property var appSearchKeys: []
    property var filteredApps: []
    property string appliedSearchText: ""
    readonly property int searchFilterDebounceMs: 60
    readonly property var contentItem: contentLoader.item

    function open() {
        AppLauncherOpenWorkflow.open(searchText, {
            clearSearch: () => searchText = "",
            refreshApplications: () => refreshApplications(),
            resetSelection: () => selectedIndex = 0,
            show: () => panel.visible = true,
            scheduleFocus: () => Qt.callLater(() => contentItem?.searchField?.forceActiveFocus())
        })
    }

    function close() {
        panel.visible = false
        if (quitOnClose)
            Qt.quit()
    }

    function toggle() {
        panel.visible ? close() : open()
    }

    function refreshApplications() {
        if (typeof DesktopEntries === "undefined") {
            appSearchKeys = []
            apps = []
            applySearchFilter(false)
            return
        }
        const refreshedApps = (DesktopEntries.applications.values || []).filter(app => {
            return app && !app.hidden && !app.noDisplay
        }).sort((a, b) => {
            return appName(a).localeCompare(appName(b))
        })
        appSearchKeys = refreshedApps.map(searchableText)
        apps = refreshedApps
        applySearchFilter(false)
    }

    function scheduleSearchFilter() {
        searchFilterTimer.restart()
    }

    function applySearchFilter(resetView) {
        searchFilterTimer.stop()

        const queryChanged = searchText !== appliedSearchText
        filteredApps = filterApps(searchText)
        appliedSearchText = searchText

        if (queryChanged) {
            selectedIndex = 0
            if (resetView)
                contentItem?.appGrid?.positionViewAtBeginning()
        } else {
            clampSelection()
        }
    }

    function filterApps(query) {
        const normalizedQuery = normalizeText(query)
        if (normalizedQuery.length === 0)
            return apps

        return apps.filter((app, index) => {
            return (appSearchKeys[index] || searchableText(app)).includes(normalizedQuery)
        })
    }

    function searchableText(app) {
        return [appName(app), app ? (app.genericName || "") : "", app ? (app.comment || "") : "", app ? (app.id || "") :
                                                                                                        "", app ? (
                                                                                                                      app.desktopEntry
                                                                                                                      || "") : ""].map(
                    normalizeText).join(" ")
    }

    function normalizeText(value) {
        return String(value || "").toLowerCase()
    }

    function appName(app) {
        return app ? (app.name || app.id || app.desktopEntry || "") : ""
    }

    function clampSelection() {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, filteredApps.length - 1)))
    }

    function moveSelection(direction) {
        const count = filteredApps.length
        if (count === 0)
            return
        selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex + direction))
        contentItem?.appGrid?.positionViewAtIndex(selectedIndex, GridView.Contain)
    }

    function launchSelection() {
        if (searchFilterTimer.running)
            applySearchFilter(false)

        const app = filteredApps[selectedIndex]
        if (app)
            launchApp(app)
    }

    function launchApp(app) {
        if (!app)
            return
        if (typeof app.execute === "function") {
            close()
            Qt.callLater(() => {
                return app.execute()
            })
            return
        }
        const command = fallbackCommand(app)
        close()
        if (command.length > 0)
            Qt.callLater(() => {
                return Quickshell.execDetached(command)
            })
    }

    function fallbackCommand(app) {
        const command = app.command || ""
        if (Array.isArray(command))
            return command

        if (typeof command === "string" && command.length > 0 && !/\s/.test(command))
            return [command]

        return []
    }

    Timer {
        id: searchFilterTimer
        interval: launcher.searchFilterDebounceMs
        repeat: false
        onTriggered: launcher.applySearchFilter(true)
    }

    Component.onCompleted: refreshApplications()
    onSearchTextChanged: scheduleSearchFilter()
    onFilteredAppsChanged: clampSelection()

    Component {
        id: launcherContent

        Column {
            id: content

            property alias searchField: searchInput
            property alias appGrid: grid
            readonly property int columns: Math.min(4, Math.max(1, Math.floor(width
                                                                              / launcher.theme.sizing.appLauncherGridCellWidth)))
            readonly property int gridWidth: columns * launcher.theme.sizing.appLauncherGridCellWidth

            anchors.fill: parent
            anchors.margins: launcher.theme.spacing.appLauncherPadding
            spacing: launcher.theme.spacing.appLauncherSectionSpacing

            Rectangle {
                width: content.gridWidth
                height: launcher.theme.sizing.appLauncherSearchHeight
                anchors.horizontalCenter: parent.horizontalCenter
                radius: launcher.theme.shape.appLauncherSearchRadius
                color: launcher.theme.colors.surfaceActive
                border.width: launcher.theme.shape.appLauncherSearchBorderWidth
                border.color: searchInput.activeFocus ? launcher.theme.colors.focus : launcher.theme.colors.border

                Shared.AppText {
                    anchors.left: parent.left
                    anchors.leftMargin: launcher.theme.spacing.appLauncherSearchHorizontalPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: launcher.theme.sizing.appLauncherSearchIconSlotWidth
                    text: launcher.icons.search
                    color: searchInput.activeFocus ? launcher.theme.colors.focus : launcher.theme.colors.textSubtle
                    font.family: launcher.theme.typography.iconFontFamily
                    font.pixelSize: launcher.theme.typography.sizeLg
                    font.styleName: launcher.theme.typography.styleMedium
                    horizontalAlignment: Text.AlignLeft
                }

                Shared.AppText {
                    anchors.left: parent.left
                    anchors.leftMargin: launcher.theme.spacing.appLauncherSearchHorizontalPadding
                                        + launcher.theme.sizing.appLauncherSearchIconSlotWidth
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    text: "Search Apps"
                    color: launcher.theme.colors.textSubtle
                    font.pixelSize: launcher.theme.typography.sizeLg
                    font.styleName: launcher.theme.typography.styleMedium
                }

                TextInput {
                    id: searchInput

                    anchors.fill: parent
                    anchors.leftMargin: launcher.theme.spacing.appLauncherSearchHorizontalPadding
                                        + launcher.theme.sizing.appLauncherSearchIconSlotWidth
                    anchors.rightMargin: launcher.theme.spacing.appLauncherSearchHorizontalPadding
                    clip: true
                    color: launcher.theme.colors.text
                    selectionColor: launcher.theme.colors.selection
                    selectedTextColor: launcher.theme.colors.selectionText
                    font.family: launcher.theme.typography.textFontFamily
                    font.pixelSize: launcher.theme.typography.sizeLg
                    font.styleName: launcher.theme.typography.styleMedium
                    verticalAlignment: TextInput.AlignVCenter
                    text: launcher.searchText
                    onTextChanged: launcher.searchText = text
                    Keys.onEscapePressed: launcher.close()
                    Keys.onLeftPressed: event => {
                        if (cursorPosition === 0)
                            launcher.moveSelection(-1)
                        else
                            event.accepted = false
                    }
                    Keys.onRightPressed: event => {
                        if (cursorPosition === text.length)
                            launcher.moveSelection(1)
                        else
                            event.accepted = false
                    }
                    Keys.onUpPressed: launcher.moveSelection(-grid.columns)
                    Keys.onDownPressed: launcher.moveSelection(grid.columns)
                    Keys.onReturnPressed: launcher.launchSelection()
                    Keys.onEnterPressed: launcher.launchSelection()
                }
            }

            GridView {
                id: grid

                readonly property int columns: content.columns

                width: columns * cellWidth
                height: parent.height - launcher.theme.sizing.appLauncherSearchHeight - parent.spacing
                anchors.horizontalCenter: parent.horizontalCenter
                clip: true
                cellWidth: launcher.theme.sizing.appLauncherGridCellWidth
                cellHeight: launcher.theme.sizing.appLauncherGridCellHeight
                model: launcher.filteredApps
                currentIndex: launcher.selectedIndex

                Shared.AppText {
                    anchors.centerIn: parent
                    visible: launcher.filteredApps.length === 0
                    width: parent.width - launcher.theme.spacing.appLauncherEmptyTextHorizontalMargin
                    text: launcher.searchText.length > 0 ? "No applications found" : "No applications available"
                    color: launcher.theme.colors.textMuted
                    font.pixelSize: launcher.theme.typography.sizeLg
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    AppLauncherCard {
                        anchors.centerIn: parent
                        app: modelData
                        theme: launcher.theme
                        selected: launcher.selectedIndex === index
                        onActivated: launcher.launchApp(modelData)
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
        color: launcher.theme.colors.transparent
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
            color: launcher.theme.colors.scrim
            focus: true
            Keys.onEscapePressed: launcher.close()
            Keys.onLeftPressed: launcher.moveSelection(-1)
            Keys.onRightPressed: launcher.moveSelection(1)
            Keys.onUpPressed: launcher.moveSelection(-(launcher.contentItem?.appGrid?.columns ?? 1))
            Keys.onDownPressed: launcher.moveSelection(launcher.contentItem?.appGrid?.columns ?? 1)
            Keys.onReturnPressed: launcher.launchSelection()
            Keys.onEnterPressed: launcher.launchSelection()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: launcher.close()
            }

            Rectangle {
                id: container

                anchors.centerIn: parent
                width: Math.min(parent.width - launcher.theme.spacing.appLauncherScreenMargin,
                                launcher.theme.sizing.appLauncherMaxWidth)
                height: Math.min(parent.height - launcher.theme.spacing.appLauncherScreenMargin,
                                 launcher.theme.sizing.appLauncherMaxHeight)
                radius: launcher.theme.shape.appLauncherRadius
                color: launcher.theme.colors.panel
                border.width: launcher.theme.shape.appLauncherBorderWidth
                border.color: launcher.theme.colors.border

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Loader {
                    id: contentLoader

                    anchors.fill: parent
                    active: panel.visible
                    sourceComponent: launcherContent
                }
            }
        }
    }
}
