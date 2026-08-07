import "../components"
import QtQuick
import "../../theme"

Row {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var colors
    required property var services

    spacing: theme.spacing.space6

    BarText {
        text: root.icons.date
        color: root.colors.text
    }

    BarText {
        text: root.services.date
        color: root.colors.text
    }
}
