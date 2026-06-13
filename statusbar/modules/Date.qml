import ".."
import "../components"
import QtQuick

Row {
    id: root

    readonly property var
    icons: BarIcons {
    }

    readonly property var
    theme: BarTheme {
    }

    required property var palette
    required property var services

    spacing: theme.gap

    BarText {
        text: root.icons.date
        color: root.palette.text
    }

    BarText {
        text: root.services.date
        color: root.palette.text
    }

}
