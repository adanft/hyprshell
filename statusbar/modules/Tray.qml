import "../components"
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons {}

    readonly property var theme: AppTheme {}

    required property var colors
    required property var barWindow
    readonly property bool hasItems: trayItems.count > 0

    function trayIconSourceFor(trayItem) {
        const icon = trayItem && trayItem.icon ? trayItem.icon : ""
        if (typeof icon !== "string" || icon === "")
            return ""

        if (icon.includes("?path=")) {
            const split = icon.split("?path=")
            if (split.length !== 2)
                return icon

            const name = split[0]
            const path = split[1]
            let fileName = name.substring(name.lastIndexOf("/") + 1)
            if (fileName.startsWith("dropboxstatus"))
                fileName = `hicolor/16x16/status/${fileName}`

            return `file://${path}/${fileName}`
        }
        if (icon.startsWith("/") && !icon.startsWith("file://"))
            return `file://${icon}`

        return icon
    }

    function openTrayMenu(trayItem, anchorItem, localX, localY) {
        trayMenuLoader.active = true
        Qt.callLater(() => {
            if (trayMenuLoader.item)
                trayMenuLoader.item.open(trayItem, anchorItem, localX, localY)
        })
    }

    implicitWidth: hasItems ? iconRow.implicitWidth : 0
    width: implicitWidth
    height: theme.sizing.statusBarHeight

    Row {
        id: iconRow

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        Repeater {
            id: trayItems

            IconImage {
                required property var modelData

                width: root.theme.sizing.statusBarIconSize
                height: root.theme.sizing.statusBarHeight
                implicitSize: root.theme.sizing.statusBarIconSize
                source: root.trayIconSourceFor(modelData)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton && modelData.hasMenu)
                            root.openTrayMenu(modelData, parent, mouse.x, mouse.y)
                        else if (mouse.button === Qt.MiddleButton)
                            modelData.secondaryActivate()
                        else if (modelData.onlyMenu && modelData.hasMenu)
                            root.openTrayMenu(modelData, parent, mouse.x, mouse.y)
                        else
                            modelData.activate()
                    }
                }
            }

            model: ScriptModel {
                values: SystemTray.items && SystemTray.items.values ? SystemTray.items.values : []
            }
        }
    }

    LazyLoader {
        id: trayMenuLoader
        active: false

        TrayMenu {
            colors: root.colors
            barWindow: root.barWindow
        }
    }

    Connections {
        target: trayMenuLoader.item
        enabled: target !== null
        function onMenuOpenChanged() {
            const menu = trayMenuLoader.item
            if (menu && !menu.menuOpen)
                trayMenuLoader.active = false
        }
    }
}
