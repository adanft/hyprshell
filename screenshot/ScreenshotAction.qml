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

    width: theme.screenshotToolActionWidth
    height: theme.screenshotToolActionHeight
    radius: theme.screenshotToolActionRadius
    opacity: enabled ? 1 : 0.45
    color: active ? theme.colors.surface0 : theme.colors.crustTransparent
    border.width: active ? theme.appLauncherCardBorderWidth : 0
    border.color: theme.colors.mauve

    Column {
        anchors.fill: parent
        anchors.margins: action.theme.screenshotToolActionPadding
        spacing: action.theme.screenshotToolActionSpacing

        Shared.AppText {
            width: parent.width
            height: action.theme.screenshotToolActionIconSlotSize
            text: action.icon
            color: action.selected ? action.theme.colors.mauve : action.theme.colors.blue
            font.family: action.theme.iconFontFamily
            font.pixelSize: action.theme.screenshotToolActionIconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Shared.AppText {
            width: parent.width
            text: action.title
            color: action.theme.colors.text
            font.pixelSize: action.theme.fontSizeSm
            font.styleName: "Medium"
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
