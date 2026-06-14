import "../shared/components" as Shared
import "../theme"
import QtQuick

Rectangle {
    id: action

    readonly property var
    theme: AppTheme {
    }

    required property string icon
    required property string title
    property bool selected: false
    readonly property bool active: selected || mouseArea.containsMouse

    signal activated()
    signal hovered()

    width: theme.sizing.screenshotToolActionWidth
    height: theme.sizing.screenshotToolActionHeight
    radius: theme.shape.screenshotToolActionRadius
    opacity: enabled ? 1 : 0.45
    color: active ? theme.colors.surface0 : theme.colors.crustTransparent
    border.width: active ? theme.shape.screenshotToolActionBorderWidth : 0
    border.color: theme.colors.mauve

    Column {
        anchors.fill: parent
        anchors.margins: action.theme.spacing.screenshotToolActionPadding
        spacing: action.theme.spacing.screenshotToolActionSpacing

        Shared.AppText {
            width: parent.width
            height: action.theme.sizing.screenshotToolActionIconSlotSize
            text: action.icon
            color: action.selected ? action.theme.colors.mauve : action.theme.colors.blue
            font.family: action.theme.typography.iconFontFamily
            font.pixelSize: action.theme.typography.actionIconFontSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Shared.AppText {
            width: parent.width
            text: action.title
            color: action.theme.colors.text
            font.pixelSize: action.theme.typography.sizeSm
            font.styleName: action.theme.typography.styleMedium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        enabled: action.enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: action.hovered()
        onClicked: action.activated()
    }

}
