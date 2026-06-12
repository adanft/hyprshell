import QtQuick
import ".."
import "../components"

Row {
    id: root

    readonly property var icons: BarIcons {}
    readonly property var theme: BarTheme {}

    required property var palette
    required property var services

    spacing: theme.gap

    BarText {
        text: root.icons.time
        color: root.palette.text
    }

    BarText {
        text: root.services.time
        color: root.palette.text
    }
}
