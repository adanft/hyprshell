import "../shared/components" as Shared
import "../theme"
import QtQuick

Rectangle {
    id: action

    readonly property var theme: AppTheme

    required property string icon
    required property string title
    property bool selected: false
    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool active: selected || hovered

    signal activated

    width: theme.sizing.screenshotToolActionWidth
    height: theme.sizing.screenshotToolActionHeight
    radius: theme.shape.screenshotToolActionRadius
    opacity: enabled ? 1 : theme.motion.opacityDisabled
    color: hovered ? theme.colors.secondary : (selected ? theme.colors.primary : theme.colors.surfaceTransparent)

    Column {
        anchors.fill: parent
        anchors.margins: action.theme.spacing.screenshotToolActionPadding
        spacing: action.theme.spacing.screenshotToolActionSpacing

        Shared.AppText {
            width: parent.width
            height: action.theme.sizing.screenshotToolActionIconSlotSize
            text: action.icon
            color: action.active ? action.theme.colors.primaryText : action.theme.colors.info
            font.family: action.theme.typography.iconFontFamily
            font.pixelSize: action.theme.sizing.screenshotToolActionIconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Shared.AppText {
            width: parent.width
            text: action.title
            color: action.active ? action.theme.colors.primaryText : action.theme.colors.text
            font.pixelSize: action.theme.typography.sizeLg
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
        onClicked: action.activated()
    }
}
