import QtQuick
import "../components"
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons {}
    readonly property var theme: AppTheme {}
    required property var colors
    required property var services

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.centerIn: parent

        Repeater {
            model: root.services.statusWorkspaceIds

            BarText {
                required property int modelData

                readonly property bool active: root.services.statusActiveWorkspaceId === modelData
                readonly property bool onOtherMonitor: root.services.statusOtherMonitorWorkspaceIds[modelData] ?? false
                readonly property bool urgent: root.services.statusUrgentWorkspaceIds[modelData] ?? false
                readonly property bool empty: !(root.services.statusOccupiedWorkspaceIds[modelData] ?? false)
                readonly property bool hovered: mouseArea.containsMouse

                width: root.theme.sizing.statusBarWorkspaceSlotSize
                text: root.icons.workspaceDot
                color: root.workspaceColor(urgent, active, onOtherMonitor, hovered, empty)
                font.family: root.theme.typography.iconFontFamily
                horizontalAlignment: Text.AlignHCenter

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(modelData)
                }
            }
        }
    }

    function focusWorkspace(workspaceId) {
        root.services.focusWorkspace(workspaceId)
    }

    function workspaceColor(urgent, active, onOtherMonitor, hovered, empty) {
        if (urgent)
            return colors.workspaceUrgent
        if (active)
            return colors.workspaceActive
        if (onOtherMonitor)
            return colors.workspaceRemote
        if (hovered)
            return colors.workspaceHover
        return empty ? colors.workspaceEmpty : colors.workspaceOccupied
    }
}
