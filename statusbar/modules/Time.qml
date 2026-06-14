import "../components"
import QtQuick
import "../../theme"

Row {
    id: root

    readonly property var
    icons: Icons {
    }

    readonly property var
    theme: AppTheme {
    }

    required property var palette
    required property var services

    spacing: theme.spacing.space6

    BarText {
        text: root.icons.time
        color: root.palette.text
    }

    BarText {
        text: root.services.time
        color: root.palette.text
    }

}
