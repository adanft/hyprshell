import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../shared/components"

Item {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var barWindow
    property var currentTrayItem: null
    property bool menuOpen: false
    property real menuAnchorX: 0
    property real menuAnchorY: theme.sizing.statusBarOuterHeight
    property int openRetryCount: 0
    readonly property int maxOpenRetries: 2

    function open(trayItem, anchorItem, localX, localY) {
        close()
        currentTrayItem = trayItem
        setMenuAnchor(anchorItem, localX, localY)
        finishOpen(anchorItem, localX, localY)
    }

    function setMenuAnchor(anchorItem, localX, localY) {
        if (!anchorItem)
            return
        const anchorX = localX === undefined ? anchorItem.width / 2 : localX
        const anchorY = localY === undefined ? anchorItem.height : localY
        const globalPosition = anchorItem.mapToGlobal(anchorX, anchorY)
        const screenX = barWindow.screen ? (barWindow.screen.x || 0) : 0
        const screenY = barWindow.screen ? (barWindow.screen.y || 0) : 0
        menuAnchorX = globalPosition.x - screenX
        menuAnchorY = globalPosition.y - screenY + theme.spacing.space6
    }

    function finishOpen(anchorItem, localX, localY) {
        if (!currentTrayItem)
            return
        if (!hasRootMenuChildren()) {
            if (openRetryCount >= maxOpenRetries) {
                menuOpen = true
                return
            }
            const retryTrayItem = currentTrayItem
            const retryAnchorItem = anchorItem
            const retryLocalX = localX
            const retryLocalY = localY
            openRetryCount += 1
            Qt.callLater(function () {
                if (root.currentTrayItem === retryTrayItem)
                    root.finishOpen(retryAnchorItem, retryLocalX, retryLocalY)
            })
            return
        }
        setMenuAnchor(anchorItem, localX, localY)
        menuOpen = true
    }

    function hasRootMenuChildren() {
        if (!rootMenuOpener.children)
            return false

        if (rootMenuOpener.children.values)
            return rootMenuOpener.children.values.length > 0

        return rootMenuOpener.children.length > 0
    }

    function close() {
        menuOpen = false
        currentTrayItem = null
        openRetryCount = 0
        submenuStack.clear()
    }

    function openSubmenu(entry) {
        submenuStack.append({
                                "handle": entry
                            })
    }

    function closeSubmenu() {
        if (submenuStack.count > 0)
            submenuStack.remove(submenuStack.count - 1)
    }

    function topSubmenuEntry() {
        return submenuStack.count > 0 ? submenuStack.get(submenuStack.count - 1).handle : null
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
            const entry = root.topSubmenuEntry()
            return entry ? (entry.menu || entry) : null
        }
    }

    PanelWindow {
        id: menuWindow

        visible: root.menuOpen && root.currentTrayItem && root.currentTrayItem.hasMenu
        screen: root.barWindow.screen
        color: "transparent"
        // Without keyboard focus the Escape shortcut below never receives an
        // event. OnDemand rather than Exclusive: this is a menu, not a modal,
        // so it must not lock the keyboard away from the focused application.
        focusable: true
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "qs-statusbar-tray-menu"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // Escape walks back one submenu level before dismissing the whole
        // menu, the same way the power menu cancels its confirmation first.
        Shortcut {
            sequence: "Escape"
            onActivated: submenuStack.count > 0 ? root.closeSubmenu() : root.close()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.close()
        }

        Rectangle {
            id: menuContainer

            readonly property real desiredHeight: Math.max(root.theme.sizing.statusBarTrayMenuMinHeight,
                                                           menuColumn.implicitHeight + root.theme.spacing.space8 * 2)

            width: root.theme.sizing.statusBarTrayMenuWidth
            height: desiredHeight
            x: Math.max(root.theme.spacing.space8, Math.min(menuWindow.width - width - root.theme.spacing.space8,
                                                            root.menuAnchorX))
            y: Math.max(root.theme.spacing.space8, Math.min(menuWindow.height - height - root.theme.spacing.space8,
                                                            root.menuAnchorY))
            radius: root.theme.shape.radius12
            color: Colors.shadow
            border.color: Colors.outline
            border.width: root.theme.shape.borderThin

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            }

            Column {
                id: menuColumn

                anchors.fill: parent
                anchors.margins: root.theme.spacing.space8
                spacing: root.theme.spacing.space2

                Rectangle {
                    visible: submenuStack.count > 0
                    width: parent.width
                    height: root.theme.sizing.statusBarTrayMenuItemHeight
                    radius: root.theme.shape.radius8
                    color: backArea.containsMouse ? Colors.hover : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: root.theme.spacing.space8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.theme.spacing.space8

                        AppText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.icons.trayBack
                            color: backArea.containsMouse ? Colors.on_hover : Colors.on_surface
                            font.family: root.theme.typography.textFontFamily
                            font.pixelSize: root.theme.typography.sizeLg
                        }

                        AppText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Back"
                            color: backArea.containsMouse ? Colors.on_hover : Colors.on_surface
                            font.family: root.theme.typography.textFontFamily
                            font.pixelSize: root.theme.typography.sizeLg
                            font.styleName: root.theme.typography.styleRegular
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
                        height: separator ? root.theme.shape.borderThin : root.theme.sizing.statusBarTrayMenuItemHeight
                        radius: separator ? 0 : root.theme.shape.radius8
                        color: separator ? Colors.outline : entryMouseArea.containsMouse ? Colors.hover :
                                                                                               "transparent"

                        MouseArea {
                            id: entryMouseArea

                            anchors.fill: parent
                            enabled: !menuEntryRoot.separator && menuEntryRoot.enabledEntry
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const entry = menuEntryRoot.modelData
                                if (!entry || entry.isSeparator)
                                    return
                                if (entry.hasChildren) {
                                    root.openSubmenu(entry)
                                    return
                                }
                                if (typeof entry.activate === "function")
                                    entry.activate()
                                else if (typeof entry.triggered === "function")
                                    entry.triggered()
                                root.close()
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: root.theme.spacing.space8
                            anchors.right: parent.right
                            anchors.rightMargin: root.theme.spacing.space8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.theme.spacing.space8
                            visible: !menuEntryRoot.separator

                            Rectangle {
                                width: root.theme.sizing.statusBarTrayMenuCheckSize
                                height: root.theme.sizing.statusBarTrayMenuCheckSize
                                anchors.verticalCenter: parent.verticalCenter
                                visible: menuEntryRoot.modelData && menuEntryRoot.modelData.buttonType !== undefined
                                         && menuEntryRoot.modelData.buttonType !== 0
                                radius: menuEntryRoot.modelData && menuEntryRoot.modelData.buttonType === 2 ? width / 2 :
                                                                                                              root.theme.shape.radius3
                                border.width: root.theme.shape.borderThin
                                border.color: Colors.outline
                                color: "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    visible: menuEntryRoot.modelData && menuEntryRoot.modelData.checkState === 2
                                    text: root.icons.trayCheck
                                    color: entryMouseArea.containsMouse ? Colors.on_hover : Colors.tertiary
                                    font.pixelSize: root.theme.typography.sizeSm
                                }
                            }

                            IconImage {
                                width: root.theme.sizing.statusBarTrayMenuIconSize
                                height: root.theme.sizing.statusBarTrayMenuIconSize
                                implicitSize: root.theme.sizing.statusBarTrayMenuIconSize
                                anchors.verticalCenter: parent.verticalCenter
                                visible: menuEntryRoot.modelData && menuEntryRoot.modelData.icon !== ""
                                source: menuEntryRoot.modelData ? menuEntryRoot.modelData.icon : ""
                            }

                            AppText {
                                width: Math.max(root.theme.sizing.statusBarTrayMenuTextMinWidth, parent.width
                                                - root.theme.sizing.statusBarTrayMenuTextRightReserve)
                                anchors.verticalCenter: parent.verticalCenter
                                text: menuEntryRoot.modelData ? (menuEntryRoot.modelData.text || "") : ""
                                color: entryMouseArea.containsMouse ? Colors.on_hover : (menuEntryRoot.enabledEntry
                                                                                             ? Colors.on_surface : Colors.on_surface_variant)
                                font.family: root.theme.typography.textFontFamily
                                font.pixelSize: root.theme.typography.sizeLg
                                font.styleName: root.theme.typography.styleRegular
                                elide: Text.ElideRight
                            }

                            AppText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: menuEntryRoot.modelData && menuEntryRoot.modelData.hasChildren
                                text: root.icons.traySubmenu
                                color: entryMouseArea.containsMouse ? Colors.on_hover : Colors.on_surface_variant
                                font.family: root.theme.typography.textFontFamily
                            }
                        }
                    }
                }
            }
        }
    }
}
