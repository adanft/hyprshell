import "../components"
import QtQuick
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons
    readonly property var theme: AppTheme

    required property var colors
    required property var services

    readonly property int level: services.brightness.brightnessLevel
    readonly property int iconIndex: Math.max(0, Math.min(icons.backlightLevels.length - 1, Math.floor(level / 100 * (
                                                                                                           icons.backlightLevels.length
                                                                                                           - 1))))

    visible: services.brightness.brightnessAvailable
    implicitWidth: visible ? content.implicitWidth : 0
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

        BarText {
            text: root.icons.backlightLevels[root.iconIndex]
            color: root.colors.text
        }

        BarText {
            text: `${root.level}%`
            color: root.colors.text
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => {
            const delta = wheel.angleDelta.y
            if (delta === 0)
                return
            root.services.brightness.changeBrightness(delta > 0 ? 1 : -1)
            wheel.accepted = true
        }
    }
}
