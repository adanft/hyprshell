import "../components"
import QtQuick
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons {}
    readonly property var theme: AppTheme {}

    required property var colors
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
            return colors.critical
        if (services.batteryPendingCharge || services.batteryPendingDischarge || services.batteryLow)
            return colors.warning
        return colors.success
    }

    visible: services.batteryAvailable
    implicitWidth: visible ? content.implicitWidth : 0
    implicitHeight: theme.sizing.statusBarHeight
    width: implicitWidth
    height: implicitHeight

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.theme.spacing.space6

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
