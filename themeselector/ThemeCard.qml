import "../shared/components" as Shared
import "../theme"
import QtQuick

Rectangle {
    id: card

    readonly property var theme: AppTheme {}
    required property var themeData
    property bool selected: false
    property bool activeTheme: false
    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool active: selected || hovered
    readonly property var previewColors: themeData && themeData.previewColors ? themeData.previewColors.slice(0, 4) : []
    readonly property int paletteDotSize: 28

    signal activated()
    signal pointerEntered()
    signal pointerExited()

    radius: theme.shape.appLauncherCardRadius
    color: active ? theme.colors.surfaceActive : theme.colors.background
    border.width: selected ? theme.shape.appLauncherCardBorderWidth : 0
    border.color: theme.colors.focus

    Row {
        id: paletteRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.theme.spacing.space16
        height: card.paletteDotSize

        Repeater {
            model: card.previewColors

            Item {
                required property color modelData

                width: parent.width / Math.max(1, card.previewColors.length)
                height: parent.height

                Shared.AppText {
                    anchors.centerIn: parent
                    text: ""
                    color: modelData
                    font.family: card.theme.typography.iconFontFamily
                    font.pixelSize: card.theme.typography.actionIconFontSize
                }
            }
        }
    }

    Shared.AppText {
        id: themeName

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: card.theme.spacing.appLauncherCardPadding
        text: card.themeData.displayName
        color: card.theme.colors.text
        font.pixelSize: card.theme.typography.sizeMd
        font.styleName: card.theme.typography.styleMedium
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: paletteRow.bottom
        anchors.bottom: themeName.top

        Shared.AppText {
            anchors.centerIn: parent
            visible: card.activeTheme
            text: ""
            color: card.theme.colors.focus
            font.family: card.theme.typography.iconFontFamily
            font.pixelSize: card.theme.typography.actionIconFontSize
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: card.pointerEntered()
        onExited: card.pointerExited()
        onClicked: card.activated()
    }
}
