import "../components"
import QtQuick
import "../../theme"

Item {
    id: root

    readonly property var icons: Icons
    readonly property var theme: AppTheme

    required property var colors
    required property var services

    readonly property int level: services.batteryPower.batteryLevel
    readonly property int iconIndex: Math.max(0, Math.min(icons.batteryLevels.length - 1, Math.ceil(level / (100
                                                                                                             / icons.batteryLevels.length))
                                                          - 1))
    readonly property string iconText: {
        if (services.batteryPower.batteryCharging || services.batteryPower.batteryPendingCharge)
            return icons.batteryCharging
        if (services.batteryPower.batteryFull)
            return icons.batteryFull
        if (services.batteryPower.batteryUnknown)
            return icons.batteryUnknown
        if (services.batteryPower.batteryEmpty)
            return icons.batteryCritical
        if (services.batteryPower.batteryPendingDischarge)
            return icons.batteryWarning
        return icons.batteryLevels[iconIndex]
    }
    readonly property color textColor: {
        if (services.batteryPower.batteryEmpty || services.batteryPower.batteryCritical)
            return colors.critical
        if (services.batteryPower.batteryLow || services.batteryPower.batteryPendingDischarge)
            return colors.danger
        if (services.batteryPower.batteryCharging || services.batteryPower.batteryPendingCharge
                || services.batteryPower.batteryFull)
            return colors.primary
        return colors.text
    }

    visible: services.batteryPower.batteryAvailable

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
            text: services.batteryPower.batteryUnknown ? "%" : `${root.level}%`
            color: root.textColor
        }
    }
}
