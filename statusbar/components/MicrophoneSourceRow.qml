import QtQuick
import "NetworkMenu.js" as NetworkMenuLogic

Rectangle {
    id: root

    required property var source
    required property var colors
    required property var theme
    property bool active: false

    signal selectRequested(var source)

    function requestSelect() {
        if (!active)
            selectRequested(source);
    }

    height: 48
    radius: theme.shape.radius12
    color: colors.surface
    border.width: 0

    Accessible.role: Accessible.ListItem
    Accessible.name: `${NetworkMenuLogic.audioSourceLabel(source)}, ${active ? "Active input" : "Available"}`

    Column {
        anchors.left: parent.left
        anchors.right: actionButton.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.theme.spacing.space12
        anchors.rightMargin: root.theme.spacing.space8
        spacing: root.theme.spacing.space2

        Text {
            width: parent.width
            text: NetworkMenuLogic.audioSourceLabel(root.source)
            color: root.active ? root.colors.primary : root.colors.text
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeMd
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: NetworkMenuLogic.audioSourceStatus(root.source, root.active ? root.source : null)
            color: root.active ? root.colors.primary : root.colors.textSubtle
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: actionButton
        width: actionLabel.implicitWidth + root.theme.spacing.space16
        height: root.theme.sizing.statusBarTrayMenuItemHeight - root.theme.spacing.space8
        anchors.right: parent.right
        anchors.rightMargin: root.theme.spacing.space8
        anchors.verticalCenter: parent.verticalCenter
        radius: root.theme.shape.radius8
        color: actionInput.containsMouse || actionInput.activeFocus
            ? root.colors.surfaceHover
            : root.colors.transparent
        opacity: root.active ? 0.6 : 1

        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: root.active ? "Active" : "Use"
            color: root.active ? root.colors.textSubtle : root.colors.primary
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleRegular
        }

        MouseArea {
            id: actionInput
            objectName: "microphoneSourceAction"
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: !root.active
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Button
            Accessible.name: `Use ${NetworkMenuLogic.audioSourceLabel(root.source)} as microphone`
            onClicked: root.requestSelect()
            Keys.onSpacePressed: root.requestSelect()
            Keys.onReturnPressed: root.requestSelect()
            Keys.onEnterPressed: root.requestSelect()
        }
    }
}
