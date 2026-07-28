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
    property bool detailAvailable: true
    property bool expanded: false
    readonly property int iconSize: theme.sizing.statusBarNetworkControlIconSize
    property string actionAccessibleName: "Toggle " + title
    property string detailAccessibleName: (expanded ? "Hide " : "Show ") + title + " details"
    property string stateDescription: subtitle

    signal bodyClicked
    signal toggled

    radius: theme.shape.radius12
    color: bodyArea.containsMouse ? colors.surfaceHover : colors.surface
    border.width: 0

    function requestBodyAction() {
        if (detailAvailable)
            bodyClicked()
    }

    function requestToggleAction() {
        if (available && !busy)
            toggled()
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
            opacity: card.available ? 1 : card.theme.motion.opacityDisabled
            activeFocusOnTab: card.available && !card.busy
            Accessible.role: Accessible.Button
            Accessible.name: card.actionAccessibleName
            Accessible.description: card.stateDescription
            Accessible.checkable: true
            Accessible.checked: card.active
            Keys.onReturnPressed: card.requestToggleAction()
            Keys.onEnterPressed: card.requestToggleAction()
            Keys.onSpacePressed: card.requestToggleAction()

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: card.colors.transparent
                border.color: card.colors.primary
                border.width: parent.activeFocus ? card.theme.shape.focusBorderWidth : 0
            }

            Text {
                anchors.centerIn: parent
                text: card.icon
                color: card.active ? card.colors.background : card.colors.textMuted
                font.family: card.theme.typography.iconFontFamily
                font.pixelSize: card.theme.typography.sizeXl
                font.styleName: card.theme.typography.styleRegular
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
                font.pixelSize: card.theme.typography.sizeMd
                font.styleName: card.theme.typography.styleSemibold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: card.subtitle
                color: card.active ? card.colors.primary : card.colors.textSubtle
                font.family: card.theme.typography.textFontFamily
                font.styleName: card.theme.typography.styleRegular
                font.pixelSize: card.theme.typography.sizeSm
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: card.colors.transparent
        border.color: card.colors.primary
        border.width: bodyArea.activeFocus ? card.theme.shape.focusBorderWidth : 0
    }

    MouseArea {
        id: bodyArea
        objectName: "bodyArea"
        anchors.fill: parent
        anchors.leftMargin: card.theme.spacing.space8 * 2 + card.iconSize
        enabled: card.detailAvailable
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        activeFocusOnTab: card.detailAvailable
        Accessible.role: Accessible.Button
        Accessible.name: card.detailAccessibleName
        Accessible.description: card.stateDescription
        Keys.onReturnPressed: card.requestBodyAction()
        Keys.onEnterPressed: card.requestBodyAction()
        Keys.onSpacePressed: card.requestBodyAction()
        onClicked: card.requestBodyAction()
    }
}
