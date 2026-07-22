import QtQuick

Rectangle {
    id: card

    required property var colors
    required property var theme
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool available: true
    property bool busy: false
    property bool expanded: false
    property int iconSize: 38

    signal bodyClicked()
    signal toggled()

    radius: theme.shape.radius12
    color: bodyArea.containsMouse ? colors.surfaceHover : colors.surface
    border.color: expanded ? colors.primary : colors.border
    border.width: expanded ? theme.shape.borderMedium : theme.shape.borderThin

    function requestBodyAction() {
        bodyClicked();
    }

    function requestToggleAction() {
        if (available && !busy)
            toggled();
    }

    Row {
        anchors.fill: parent
        anchors.margins: card.theme.spacing.space8
        spacing: card.theme.spacing.space8

        Rectangle {
            id: iconButton
            objectName: "iconButton"
            width: card.iconSize
            height: card.iconSize
            anchors.verticalCenter: parent.verticalCenter
            radius: card.theme.shape.radius12
            color: card.active ? card.colors.primary : card.colors.surfaceHover
            border.color: card.active ? card.colors.primary : card.colors.border
            opacity: card.available ? 1 : 0.45

            Text {
                anchors.centerIn: parent
                text: card.icon
                color: card.active ? card.colors.background : card.colors.textMuted
                font.family: card.theme.typography.textFontFamily
                font.pixelSize: 20
            }

            MouseArea {
                objectName: "toggleArea"
                anchors.fill: parent
                enabled: card.available && !card.busy
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: card.requestToggleAction()
            }
        }

        Column {
            width: parent.width - iconButton.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: card.theme.spacing.space2

            Text {
                width: parent.width
                text: card.title
                color: card.colors.text
                font.family: card.theme.typography.textFontFamily
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: card.subtitle
                color: card.active ? card.colors.primary : card.colors.textSubtle
                font.family: card.theme.typography.textFontFamily
                font.pixelSize: card.theme.typography.sizeSm
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: bodyArea
        objectName: "bodyArea"
        anchors.fill: parent
        anchors.leftMargin: card.theme.spacing.space8 * 2 + card.iconSize
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.requestBodyAction()
    }
}
