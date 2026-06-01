import QtQuick
import Quickshell
import Quickshell.Hyprland

Rectangle {
    id: root

    required property var palette

    readonly property var workspaces: [1, 2, 3, 4, 5, 6, 7, 8, 9]

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 30
    radius: 999
    color: palette.base

    Row {
        id: row
        anchors.centerIn: parent

        Repeater {
            model: root.workspaces

            Text {
                required property int modelData

                readonly property var workspace: Hyprland.workspaces.values.find(ws => ws.id === modelData)
                readonly property bool active: workspace ? workspace.active : false
                readonly property bool urgent: (workspace ? workspace.urgent : false)
                    || Hyprland.toplevels.values.some(toplevel => toplevel.urgent && toplevel.workspace && toplevel.workspace.id === modelData)
                readonly property bool empty: workspace ? workspace.toplevels.values.length === 0 : true
                readonly property bool hovered: mouseArea.containsMouse

                width: 24
                text: ""
                color: urgent ? root.palette.red : active ? root.palette.mauve : hovered ? root.palette.teal : empty ? root.palette.surface1 : root.palette.overlay1
                font.family: "Symbols Nerd Font"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = ${modelData} })`])
                }
            }
        }
    }
}
