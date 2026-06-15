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
    readonly property var previewColors: themeData && themeData.previewColors ? themeData.previewColors.slice(0, 3) : []
    readonly property int paletteDotSize: 40

    signal activated()
    signal pointerEntered()
    signal pointerExited()

    radius: theme.shape.appLauncherCardRadius
    color: active ? theme.colors.surfaceActive : theme.colors.background
    border.width: selected ? theme.shape.appLauncherCardBorderWidth : 0
    border.color: theme.colors.focus

    Shared.AppText {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: card.theme.spacing.appLauncherCardPadding
        text: card.themeData.displayName
        color: card.theme.colors.text
        font.pixelSize: card.theme.typography.sizeLg
        font.styleName: card.theme.typography.styleMedium
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: card.theme.spacing.space16
        height: card.paletteDotSize

        Repeater {
            model: card.previewColors

            Item {
                required property color modelData

                width: parent.width / Math.max(1, card.previewColors.length)
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: card.paletteDotSize
                    height: width
                    radius: width / 2
                    color: modelData
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: card.theme.spacing.space8
        width: card.theme.spacing.space4
        height: parent.height - card.theme.spacing.space24
        radius: width / 2
        visible: card.activeTheme
        color: card.theme.colors.focus
    }

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: card.theme.spacing.space8
        width: card.theme.spacing.space4
        height: parent.height - card.theme.spacing.space24
        radius: width / 2
        visible: card.activeTheme
        color: card.theme.colors.focus
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
