import "../../theme"
import QtQuick

Rectangle {
    id: button

    readonly property var theme: AppTheme

    property string icon: ""
    property bool selected: false
    property color primary: Colors.primary
    readonly property bool active: selected || mouseArea.containsMouse

    signal activated
    signal hovered

    width: PowerMenuSizing.actionSize
    height: PowerMenuSizing.actionSize
    radius: theme.shape.powerMenuActionRadius
    // The resting state had this the other way round: a surface-coloured body
    // with a shadow-coloured border and glyph. Swapping them leaves the body the
    // same deep shadow in both states, so the button no longer changes mass when
    // it lights up — only the border and glyph move from muted to accent.
    color: Colors.shadow
    border.width: theme.shape.powerMenuActionBorderWidth
    border.color: active ? primary : Colors.surface

    Text {
        anchors.centerIn: parent
        text: icon
        color: active ? primary : Colors.surface
        font.family: theme.typography.iconFontFamily
        font.pixelSize: theme.typography.glyphHero
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: button.hovered()
        onClicked: button.activated()
    }
}
