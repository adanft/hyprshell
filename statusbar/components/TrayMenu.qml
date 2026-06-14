import ".."
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root

    readonly property var
    icons: BarIcons {
    }

    readonly property var
    theme: BarTheme {
    }

    required property var palette
    required property var barWindow
    property var currentTrayItem: null
    property bool menuOpen: false
    property real menuAnchorX: 0
    property real menuAnchorY: theme.trayMenuAnchorDefaultY
    property int openRetryCount: 0
    readonly property int maxOpenRetries: 2

    function open(trayItem, anchorItem) {
        close();
        const globalPosition = anchorItem.mapToGlobal(anchorItem.width / 2, anchorItem.height);
        const screenX = barWindow.screen ? (barWindow.screen.x || 0) : 0;
        const screenY = barWindow.screen ? (barWindow.screen.y || 0) : 0;
        currentTrayItem = trayItem;
        menuAnchorX = globalPosition.x - screenX;
        menuAnchorY = globalPosition.y - screenY + theme.gap;
        finishOpen(anchorItem);
    }

    function finishOpen(anchorItem) {
        if (!currentTrayItem)
            return ;

        if (!hasRootMenuChildren()) {
            if (openRetryCount >= maxOpenRetries) {
                menuOpen = true;
                return ;
            }
            const retryTrayItem = currentTrayItem;
            const retryAnchorItem = anchorItem;
            openRetryCount += 1;
            Qt.callLater(function() {
                if (root.currentTrayItem === retryTrayItem)
                    root.finishOpen(retryAnchorItem);

            });
            return ;
        }
        if (anchorItem) {
            const globalPosition = anchorItem.mapToGlobal(anchorItem.width / 2, anchorItem.height);
            const screenX = barWindow.screen ? (barWindow.screen.x || 0) : 0;
            const screenY = barWindow.screen ? (barWindow.screen.y || 0) : 0;
            menuAnchorX = globalPosition.x - screenX;
            menuAnchorY = globalPosition.y - screenY + theme.gap;
        }
        menuOpen = true;
    }

    function hasRootMenuChildren() {
        if (!rootMenuOpener.children)
            return false;

        if (rootMenuOpener.children.values)
            return rootMenuOpener.children.values.length > 0;

        return rootMenuOpener.children.length > 0;
    }

    function close() {
        menuOpen = false;
        currentTrayItem = null;
        openRetryCount = 0;
        submenuStack.clear();
    }

    function openSubmenu(entry) {
        submenuStack.append({
            "handle": entry
        });
    }

    function closeSubmenu() {
        if (submenuStack.count > 0)
            submenuStack.remove(submenuStack.count - 1);

    }

    function topSubmenuEntry() {
        return submenuStack.count > 0 ? submenuStack.get(submenuStack.count - 1).handle : null;
    }

    ListModel {
        id: submenuStack
    }

    QsMenuOpener {
        id: rootMenuOpener

        menu: root.currentTrayItem ? root.currentTrayItem.menu : null
    }

    QsMenuOpener {
        id: submenuOpener

        menu: {
            const entry = root.topSubmenuEntry();
            return entry ? (entry.menu || entry) : null;
        }
    }

    PanelWindow {
        id: menuWindow

        visible: root.menuOpen && root.currentTrayItem && root.currentTrayItem.hasMenu
        screen: root.barWindow.screen
        color: root.palette.transparent
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-statusbar-tray-menu"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.close()
        }

        Rectangle {
            id: menuContainer

            readonly property real desiredWidth: root.theme.trayMenuWidth
            readonly property real desiredHeight: Math.max(root.theme.trayMenuMinHeight, menuColumn.implicitHeight + root.theme.trayMenuPadding * 2)

            width: desiredWidth
            height: desiredHeight
            x: Math.max(root.theme.trayMenuClampMargin, Math.min(menuWindow.width - width - root.theme.trayMenuClampMargin, root.menuAnchorX - width / 2))
            y: Math.max(root.theme.trayMenuClampMargin, Math.min(menuWindow.height - height - root.theme.trayMenuClampMargin, root.menuAnchorY))
            radius: root.theme.trayMenuRadius
            color: root.palette.base
            border.color: root.palette.surface1
            border.width: root.theme.trayMenuBorderWidth

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            }

            Column {
                id: menuColumn

                anchors.fill: parent
                anchors.margins: root.theme.trayMenuPadding
                spacing: root.theme.trayMenuSpacing

                Rectangle {
                    visible: submenuStack.count > 0
                    width: parent.width
                    height: root.theme.trayMenuItemHeight
                    radius: root.theme.trayMenuItemRadius
                    color: backArea.containsMouse ? root.palette.surface1 : root.palette.transparent

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: root.theme.trayMenuPadding
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.theme.trayMenuPadding

                        BarText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.icons.trayBack
                            color: root.palette.text
                            font.family: root.theme.textFontFamily
                            font.pixelSize: root.theme.fontSize
                        }

                        BarText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Back"
                            color: root.palette.text
                            font.family: root.theme.textFontFamily
                            font.pixelSize: root.theme.fontSize
                        }

                    }

                    MouseArea {
                        id: backArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeSubmenu()
                    }

                }

                Repeater {
                    model: submenuStack.count > 0 ? submenuOpener.children : rootMenuOpener.children

                    Rectangle {
                        id: menuEntryRoot

                        required property var modelData
                        readonly property bool separator: modelData && modelData.isSeparator
                        readonly property bool enabledEntry: modelData && modelData.enabled !== false

                        width: menuColumn.width
                        height: separator ? root.theme.trayMenuSeparatorHeight : root.theme.trayMenuItemHeight
                        radius: separator ? 0 : root.theme.trayMenuItemRadius
                        color: separator ? root.palette.surface1 : entryMouseArea.containsMouse ? root.palette.surface1 : root.palette.transparent

                        MouseArea {
                            id: entryMouseArea

                            anchors.fill: parent
                            enabled: !menuEntryRoot.separator && menuEntryRoot.enabledEntry
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const entry = menuEntryRoot.modelData;
                                if (!entry || entry.isSeparator)
                                    return ;

                                if (entry.hasChildren) {
                                    root.openSubmenu(entry);
                                    return ;
                                }
                                if (typeof entry.activate === "function")
                                    entry.activate();
                                else if (typeof entry.triggered === "function")
                                    entry.triggered();
                                root.close();
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: root.theme.trayMenuPadding
                            anchors.right: parent.right
                            anchors.rightMargin: root.theme.trayMenuPadding
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.theme.trayMenuPadding
                            visible: !menuEntryRoot.separator

                            Rectangle {
                                width: root.theme.trayMenuCheckSize
                                height: root.theme.trayMenuCheckSize
                                anchors.verticalCenter: parent.verticalCenter
                                visible: menuEntryRoot.modelData && menuEntryRoot.modelData.buttonType !== undefined && menuEntryRoot.modelData.buttonType !== 0
                                radius: menuEntryRoot.modelData && menuEntryRoot.modelData.buttonType === 2 ? width / 2 : root.theme.trayMenuCheckRadius
                                border.width: root.theme.trayMenuBorderWidth
                                border.color: root.palette.overlay1
                                color: root.palette.transparent

                                Text {
                                    anchors.centerIn: parent
                                    visible: menuEntryRoot.modelData && menuEntryRoot.modelData.checkState === 2
                                    text: root.icons.trayCheck
                                    color: root.palette.blue
                                    font.pixelSize: root.theme.trayMenuCheckFontSize
                                }

                            }

                            IconImage {
                                width: root.theme.trayMenuIconSize
                                height: root.theme.trayMenuIconSize
                                implicitSize: root.theme.trayMenuIconSize
                                anchors.verticalCenter: parent.verticalCenter
                                visible: menuEntryRoot.modelData && menuEntryRoot.modelData.icon !== ""
                                source: menuEntryRoot.modelData ? menuEntryRoot.modelData.icon : ""
                            }

                            BarText {
                                width: Math.max(root.theme.trayMenuTextMinWidth, parent.width - root.theme.trayMenuTextRightReserve)
                                anchors.verticalCenter: parent.verticalCenter
                                text: menuEntryRoot.modelData ? (menuEntryRoot.modelData.text || "") : ""
                                color: menuEntryRoot.enabledEntry ? root.palette.text : root.palette.overlay1
                                font.family: root.theme.textFontFamily
                                font.pixelSize: root.theme.fontSize
                                elide: Text.ElideRight
                            }

                            BarText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: menuEntryRoot.modelData && menuEntryRoot.modelData.hasChildren
                                text: root.icons.traySubmenu
                                color: root.palette.subtext1
                                font.family: root.theme.textFontFamily
                            }

                        }

                    }

                }

            }

        }

    }

}
