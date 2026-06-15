import "../shared/components" as Shared
import "../theme"
import QtQuick

Rectangle {
    id: card

    readonly property var theme: AppTheme {}
    readonly property var icons: Icons {}
    required property var themeData
    property bool selected: false
    property bool activeTheme: false
    readonly property bool pointerHovered: mouseArea.containsMouse
    readonly property var previewColors: themeData.previewColors || [themeData.primary, themeData.secondary, themeData.info, themeData.success, themeData.warning, themeData.danger]

    signal activated()
    radius: theme.shape.appLauncherCardRadius
    color: themeData && themeData.background ? themeData.background : theme.colors.surface
    border.width: pointerHovered || selected ? theme.shape.appLauncherCardBorderWidth : 0
    border.color: theme.colors.focus

    Column {
        anchors.fill: parent
        anchors.margins: card.theme.spacing.space16
        spacing: card.theme.spacing.space12

        Rectangle {
            width: parent.width
            height: parent.height - swatches.height - parent.spacing
            radius: card.theme.shape.radius12
            color: card.themeData && card.themeData.surface ? card.themeData.surface : card.theme.colors.surfaceActive

            Shared.AppText {
                anchors.centerIn: parent
                width: parent.width - card.theme.spacing.space24
                text: card.themeData.displayName
                color: card.themeData && card.themeData.text ? card.themeData.text : card.theme.colors.text
                font.pixelSize: card.theme.typography.sizeLg
                font.styleName: card.theme.typography.styleBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        Row {
            id: swatches

            width: parent.width
            height: card.theme.sizing.statusBarOuterHeight
            spacing: card.theme.spacing.space8

            Repeater {
                model: card.previewColors

                Rectangle {
                    required property color modelData

                    width: (swatches.width - swatches.spacing * (card.previewColors.length - 1)) / card.previewColors.length
                    height: swatches.height
                    radius: height / 2
                    color: modelData
                }
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: card.theme.spacing.wallpaperCardSelectedBadgeMargin
        width: card.theme.sizing.wallpaperCardSelectedBadgeSize
        height: card.theme.sizing.wallpaperCardSelectedBadgeSize
        radius: card.theme.shape.wallpaperCardSelectedBadgeRadius
        visible: card.activeTheme
        color: card.themeData && card.themeData.primary ? card.themeData.primary : card.theme.colors.primary

        Text {
            anchors.centerIn: parent
            text: card.icons.wallpaperSelectedCheck
            color: card.themeData && card.themeData.primaryText ? card.themeData.primaryText : card.theme.colors.primaryText
            font.pixelSize: card.theme.typography.sizeXl
            font.styleName: card.theme.typography.styleBold
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activated()
    }
}
