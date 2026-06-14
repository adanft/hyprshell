import "../shared/components" as Shared
import "../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: launcher

    readonly property var
    theme: AppTheme {
    }

    property alias visible: panel.visible
    property bool quitOnClose: false
    property string searchText: ""
    property int selectedIndex: 0
    property var apps: []
    readonly property var filteredApps: filterApps(searchText)

    function open() {
        refreshApplications();
        searchText = "";
        selectedIndex = 0;
        panel.visible = true;
        Qt.callLater(() => {
            return searchInput.forceActiveFocus();
        });
    }

    function close() {
        panel.visible = false;
        if (quitOnClose)
            Qt.quit();

    }

    function toggle() {
        panel.visible ? close() : open();
    }

    function refreshApplications() {
        if (typeof DesktopEntries === "undefined") {
            apps = [];
            return ;
        }
        apps = (DesktopEntries.applications.values || []).filter((app) => {
            return app && !app.hidden && !app.noDisplay;
        }).sort((a, b) => {
            return appName(a).localeCompare(appName(b));
        });
        clampSelection();
    }

    function filterApps(query) {
        const normalizedQuery = normalizeText(query);
        if (normalizedQuery.length === 0)
            return apps;

        return apps.filter((app) => {
            return searchableText(app).includes(normalizedQuery);
        });
    }

    function searchableText(app) {
        return [appName(app), app ? (app.genericName || "") : "", app ? (app.comment || "") : "", app ? (app.id || "") : "", app ? (app.desktopEntry || "") : ""].map(normalizeText).join(" ");
    }

    function normalizeText(value) {
        return String(value || "").toLowerCase();
    }

    function appName(app) {
        return app ? (app.name || app.id || app.desktopEntry || "") : "";
    }

    function clampSelection() {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, filteredApps.length - 1)));
    }

    function moveSelection(direction) {
        const count = filteredApps.length;
        if (count === 0)
            return ;

        selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex + direction));
        grid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }

    function launchSelection() {
        const app = filteredApps[selectedIndex];
        if (app)
            launchApp(app);

    }

    function launchApp(app) {
        if (!app)
            return ;

        if (typeof app.execute === "function") {
            close();
            Qt.callLater(() => {
                return app.execute();
            });
            return ;
        }
        const command = fallbackCommand(app);
        close();
        if (command.length > 0)
            Qt.callLater(() => {
            return Quickshell.execDetached(command);
        });

    }

    function fallbackCommand(app) {
        const command = app.command || "";
        if (Array.isArray(command))
            return command;

        if (typeof command === "string" && command.length > 0 && !/\s/.test(command))
            return [command];

        return [];
    }

    Component.onCompleted: refreshApplications()
    onSearchTextChanged: {
        selectedIndex = 0;
        grid.positionViewAtBeginning();
    }
    onFilteredAppsChanged: clampSelection()

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
            color: launcher.theme.colors.baseScrim
            focus: true
            Keys.onEscapePressed: launcher.close()
            Keys.onLeftPressed: launcher.moveSelection(-1)
            Keys.onRightPressed: launcher.moveSelection(1)
            Keys.onUpPressed: launcher.moveSelection(-grid.columns)
            Keys.onDownPressed: launcher.moveSelection(grid.columns)
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
                width: Math.min(parent.width - launcher.theme.appLauncherScreenMargin, launcher.theme.appLauncherMaxWidth)
                height: Math.min(parent.height - launcher.theme.appLauncherScreenMargin, launcher.theme.appLauncherMaxHeight)
                radius: launcher.theme.appLauncherRadius
                color: launcher.theme.colors.mantlePanel
                border.width: launcher.theme.appLauncherBorderWidth
                border.color: launcher.theme.colors.surface1

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Column {
                    id: content

                    readonly property int columns: Math.min(4, Math.max(1, Math.floor(width / launcher.theme.appLauncherGridCellWidth)))
                    readonly property int gridWidth: columns * launcher.theme.appLauncherGridCellWidth

                    anchors.fill: parent
                    anchors.margins: launcher.theme.appLauncherPadding
                    spacing: launcher.theme.appLauncherSectionSpacing

                    Rectangle {
                        width: content.gridWidth
                        height: launcher.theme.appLauncherSearchHeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: launcher.theme.appLauncherSearchRadius
                        color: launcher.theme.colors.surface0
                        border.width: launcher.theme.appLauncherSearchBorderWidth
                        border.color: searchInput.activeFocus ? launcher.theme.colors.mauve : launcher.theme.colors.surface1

                        Shared.AppText {
                            anchors.left: parent.left
                            anchors.leftMargin: launcher.theme.appLauncherSearchHorizontalPadding
                            anchors.verticalCenter: parent.verticalCenter
                            width: launcher.theme.appLauncherSearchIconSlotWidth
                            text: ""
                            color: searchInput.activeFocus ? launcher.theme.colors.mauve : launcher.theme.colors.overlay1
                            font.family: launcher.theme.iconFontFamily
                            font.pixelSize: launcher.theme.appLauncherSearchIconSize
                            font.styleName: "Medium"
                            horizontalAlignment: Text.AlignLeft
                        }

                        Shared.AppText {
                            anchors.left: parent.left
                            anchors.leftMargin: launcher.theme.appLauncherSearchHorizontalPadding + launcher.theme.appLauncherSearchIconSlotWidth
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text.length === 0
                            text: "Search Apps"
                            color: launcher.theme.colors.overlay1
                            font.pixelSize: launcher.theme.appLauncherSearchFontSize
                            font.styleName: "Medium"
                        }

                        TextInput {
                            id: searchInput

                            anchors.fill: parent
                            anchors.leftMargin: launcher.theme.appLauncherSearchHorizontalPadding + launcher.theme.appLauncherSearchIconSlotWidth
                            anchors.rightMargin: launcher.theme.appLauncherSearchHorizontalPadding
                            clip: true
                            color: launcher.theme.colors.text
                            selectionColor: launcher.theme.colors.mauve
                            selectedTextColor: launcher.theme.colors.crust
                            font.family: launcher.theme.textFontFamily
                            font.pixelSize: launcher.theme.appLauncherSearchFontSize
                            font.styleName: "Medium"
                            verticalAlignment: TextInput.AlignVCenter
                            text: launcher.searchText
                            onTextChanged: launcher.searchText = text
                            Keys.onEscapePressed: launcher.close()
                            Keys.onLeftPressed: (event) => {
                                if (cursorPosition === 0)
                                    launcher.moveSelection(-1);
                                else
                                    event.accepted = false;
                            }
                            Keys.onRightPressed: (event) => {
                                if (cursorPosition === text.length)
                                    launcher.moveSelection(1);
                                else
                                    event.accepted = false;
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
                        height: parent.height - launcher.theme.appLauncherSearchHeight - parent.spacing
                        anchors.horizontalCenter: parent.horizontalCenter
                        clip: true
                        cellWidth: launcher.theme.appLauncherGridCellWidth
                        cellHeight: launcher.theme.appLauncherGridCellHeight
                        model: launcher.filteredApps
                        currentIndex: launcher.selectedIndex

                        Shared.AppText {
                            anchors.centerIn: parent
                            visible: launcher.filteredApps.length === 0
                            width: parent.width - launcher.theme.appLauncherEmptyTextHorizontalMargin
                            text: launcher.searchText.length > 0 ? "No applications found" : "No applications available"
                            color: launcher.theme.colors.subtext0
                            font.pixelSize: launcher.theme.appLauncherEmptyFontSize
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
                                onHovered: launcher.selectedIndex = index
                                onActivated: launcher.launchApp(modelData)
                            }

                        }

                    }

                }

            }

        }

    }

}
