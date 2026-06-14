import ".."
import "../components"
import QtQuick

Item {
    id: root

    readonly property var icons: BarIcons {}
    readonly property var theme: BarTheme {}

    required property var palette
    required property var services

    readonly property int level: services.batteryLevel
    readonly property int iconIndex: Math.max(0, Math.min(icons.batteryLevels.length - 1, Math.ceil(level / (100 / icons.batteryLevels.length)) - 1))
    readonly property string iconText: {
        if (services.batteryCharging || services.batteryPendingCharge)
            return icons.batteryCharging
        if (services.batteryFull)
            return icons.batteryFull
        if (services.batteryUnknown)
            return icons.batteryUnknown
        if (services.batteryEmpty)
            return icons.batteryCritical
        if (services.batteryPendingDischarge)
            return icons.batteryWarning
        return icons.batteryLevels[iconIndex]
    }
    readonly property color textColor: {
        if (services.batteryEmpty || services.batteryCritical)
            return palette.red
        if (services.batteryPendingCharge || services.batteryPendingDischarge || services.batteryLow)
            return palette.yellow
        return palette.green
    }

    visible: services.batteryAvailable
    implicitWidth: visible ? content.implicitWidth : 0
    implicitHeight: theme.height
    width: implicitWidth
    height: implicitHeight

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.gap

        BarText {
            text: root.iconText
            color: root.textColor
        }

        BarText {
            text: services.batteryUnknown ? "%" : `${root.level}%`
            color: root.textColor
        }
    }
}
