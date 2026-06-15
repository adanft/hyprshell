import "../shared/components" as Shared
import "../theme"
import QtQuick

Rectangle {
    id: card

    readonly property var theme: AppTheme {}
    required property var themeData
    property bool selected: false
    property bool activeTheme: false
    readonly property bool pointerHovered: mouseArea.containsMouse
    readonly property var previewColors: themeData && themeData.previewColors ? themeData.previewColors.slice(0, 3) : []
    readonly property int paletteDotSize: 40

    signal activated()
    signal hovered()
    signal unhovered()

    radius: theme.shape.appLauncherCardRadius
    color: themeData && themeData.background ? themeData.background : theme.colors.surface
    border.width: theme.shape.appLauncherCardBorderWidth
    border.color: selected ? theme.colors.focus : theme.colors.border

    Shared.AppText {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: card.theme.spacing.appLauncherCardPadding
        text: card.themeData.displayName
        color: card.themeData && card.themeData.text ? card.themeData.text : card.theme.colors.text
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
        anchors.fill: parent
        anchors.margins: card.border.width
        radius: parent.radius
        visible: card.pointerHovered
        color: Qt.rgba(card.theme.colors.background.r, card.theme.colors.background.g, card.theme.colors.background.b, 0.5)
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

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: card.hovered()
        onExited: card.unhovered()
        onClicked: card.activated()
    }
}
