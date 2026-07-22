import QtQuick
import "NetworkMenu.js" as NetworkMenuLogic

Rectangle {
    id: root

    required property var profile
    required property var colors
    required property var theme
    property bool active: false
    property bool busy: false
    property bool pending: false

    signal toggleRequested(var profile)

    function requestToggle() {
        if (!busy)
            toggleRequested(profile);
    }

    height: 48
    radius: theme.shape.radius12
    color: colors.surface
    border.width: active ? theme.shape.borderMedium : 0
    border.color: colors.primary

    Accessible.role: Accessible.ListItem
    Accessible.name: `${NetworkMenuLogic.ethernetProfileLabel(profile)}, ${active ? "Active" : "Available"}`

    Column {
        anchors.left: parent.left
        anchors.right: actionButton.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.theme.spacing.space12
        anchors.rightMargin: root.theme.spacing.space8
        spacing: root.theme.spacing.space2

        Text {
            width: parent.width
            text: NetworkMenuLogic.ethernetProfileLabel(root.profile)
            color: root.active ? root.colors.primary : root.colors.text
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeMd
            font.weight: Font.Normal
            elide: Text.ElideRight
        }

        Text {
            objectName: "ethernetProfileStatus"
            text: root.pending ? "Please wait…" : (root.active ? "Active" : "Available")
            color: root.active ? root.colors.primary : root.colors.textSubtle
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.weight: Font.Normal
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
        color: actionInput.containsMouse || actionInput.activeFocus ? root.colors.surfaceHover : root.colors.transparent
        opacity: root.busy ? 0.45 : 1

        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: root.active ? "Disable" : "Enable"
            color: root.active ? root.colors.danger : root.colors.primary
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.weight: Font.Normal
        }

        MouseArea {
            id: actionInput
            objectName: "ethernetProfileAction"
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: !root.busy
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Button
            Accessible.name: `${root.active ? "Disable" : "Enable"} ${NetworkMenuLogic.ethernetProfileLabel(root.profile)}`
            onClicked: root.requestToggle()
            Keys.onSpacePressed: root.requestToggle()
            Keys.onReturnPressed: root.requestToggle()
            Keys.onEnterPressed: root.requestToggle()
        }
    }
}
