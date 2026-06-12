import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import ".."
import "../components"

Item {
    id: root

    readonly property var icons: BarIcons {}
    readonly property var theme: BarTheme {}
    required property var palette
    required property var barWindow
    readonly property bool hasItems: trayItems.count > 0

    implicitWidth: hasItems ? iconRow.implicitWidth : 0
    width: implicitWidth
    height: theme.height

    Row {
        id: iconRow

        anchors.centerIn: parent
        spacing: root.theme.trayIconGap

        Repeater {
            id: trayItems

            model: ScriptModel {
                values: SystemTray.items && SystemTray.items.values ? SystemTray.items.values : []
            }

            IconImage {
                required property var modelData

                width: root.theme.iconSize
                height: root.theme.height
                implicitSize: root.theme.iconSize
                source: root.trayIconSourceFor(modelData)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                            trayMenu.open(modelData, parent)
                        } else if (mouse.button === Qt.MiddleButton)
                            modelData.secondaryActivate()
                        else if (modelData.onlyMenu && modelData.hasMenu)
                            trayMenu.open(modelData, parent)
                        else
                            modelData.activate()
                    }
                }
            }
        }
    }

    TrayMenu {
        id: trayMenu

        palette: root.palette
        barWindow: root.barWindow
    }

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

}
