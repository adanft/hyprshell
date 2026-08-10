import "../components"
import QtQuick
import "../../theme"
import "../../shared/components"

Row {
    id: root

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var services

    spacing: theme.spacing.space6

    BarText {
        text: root.icons.date
        color: Colors.on_surface
    }

    BarText {
        text: root.services.date
        color: Colors.on_surface
    }
}
