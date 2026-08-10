import QtQuick
import "../ControlCenter.js" as ControlCenterLogic
import "../../theme"

Rectangle {
    id: root

    required property var profile
    required property var theme
    property bool active: false
    property bool busy: false
    property bool pending: false

    signal toggleRequested(var profile)

    function requestToggle() {
        if (!busy)
            toggleRequested(profile)
    }

    height: theme.sizing.statusBarNetworkDeviceRowHeight
    radius: theme.shape.radius12
    color: Colors.surface
    border.width: 0

    Accessible.role: Accessible.ListItem
    Accessible.name: `${ControlCenterLogic.ethernetProfileLabel(profile)}, ${active ? "Active" : "Available"}`

    Column {
        anchors.left: parent.left
        anchors.right: actionButton.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.theme.spacing.space12
        anchors.rightMargin: root.theme.spacing.space12
        spacing: root.theme.spacing.space2

        Text {
            width: parent.width
            text: ControlCenterLogic.ethernetProfileLabel(root.profile)
            color: root.active ? Colors.primary : Colors.on_surface
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeMd
            font.styleName: root.theme.typography.styleSemibold
            elide: Text.ElideRight
        }

        Text {
            objectName: "ethernetProfileStatus"
            text: root.pending ? "Please wait…" : (root.active ? "Active" : "Available")
            color: root.active ? Colors.primary : Colors.on_surface_variant
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleRegular
        }
    }

    Rectangle {
        id: actionButton
        width: actionLabel.implicitWidth + root.theme.spacing.space16
        height: root.theme.sizing.statusBarControlActionHeight
        anchors.right: parent.right
        anchors.rightMargin: root.theme.spacing.space12
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: actionInput.containsMouse || actionInput.activeFocus ? Colors.hover : "transparent"
        opacity: root.busy ? root.theme.motion.opacityDisabled : 1

        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: root.active ? "Disable" : "Enable"
            color: actionInput.containsMouse || actionInput.activeFocus ? Colors.on_hover : (root.active
                                                                                                    ? Colors.error : Colors.primary)
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleRegular
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
            Accessible.name: [root.active ? "Disable" : "Enable", " ", ControlCenterLogic.ethernetProfileLabel(
                    root.profile)].join("")
            onClicked: root.requestToggle()
            Keys.onSpacePressed: root.requestToggle()
            Keys.onReturnPressed: root.requestToggle()
            Keys.onEnterPressed: root.requestToggle()
        }
    }
}
