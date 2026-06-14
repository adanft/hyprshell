import ".."
import "../components"
import QtQuick

Item {
    id: root

    readonly property var icons: BarIcons {}
    readonly property var theme: BarTheme {}

    required property var palette
    required property var services

    readonly property int level: services.brightnessLevel
    readonly property int iconIndex: Math.max(0, Math.min(icons.backlightLevels.length - 1, Math.floor(level / 100 * (icons.backlightLevels.length - 1))))

    visible: services.brightnessAvailable
    implicitWidth: visible ? content.implicitWidth : 0
    implicitHeight: theme.height
    width: implicitWidth
    height: implicitHeight

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.gap

        BarText {
            text: root.icons.backlightLevels[root.iconIndex]
            color: root.palette.yellow
        }

        BarText {
            text: `${root.level}%`
            color: root.palette.yellow
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => {
            const delta = wheel.angleDelta.y
            if (delta === 0)
                return

            root.services.changeBrightness(delta > 0 ? 1 : -1)
            wheel.accepted = true
        }
    }
}
