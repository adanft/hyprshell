import QtQuick
import "NetworkMenu.js" as NetworkMenuLogic
import "../../theme"

Rectangle {
    id: root

    required property var device
    required property var theme
    required property string icon
    property bool active: false
    property bool available: Boolean(root.device?.audio)

    signal selectRequested(var device)

    function requestSelect() {
        if (root.available && !root.active)
            root.selectRequested(root.device)
    }

    height: root.theme.sizing.statusBarNetworkDeviceRowHeight
    radius: root.theme.shape.radius12
    color: Colors.surface
    opacity: root.available ? 1 : root.theme.motion.opacityDisabled

    Accessible.role: Accessible.ListItem
    Accessible.name: [NetworkMenuLogic.audioOutputLabel(root.device), ", ", NetworkMenuLogic.audioOutputStatus(
            root.device, root.active)].join("")

    Text {
        id: deviceIcon

        width: root.theme.sizing.statusBarNetworkQuickControlIconWidth
        anchors.left: parent.left
        anchors.leftMargin: root.theme.spacing.space12
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: root.active ? Colors.primary : Colors.on_surface
        horizontalAlignment: Text.AlignHCenter
        font.family: root.theme.typography.iconFontFamily
        font.pixelSize: root.theme.typography.sizeLg
    }

    Column {
        anchors.left: deviceIcon.right
        anchors.right: actionButton.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.theme.spacing.space8
        anchors.rightMargin: root.theme.spacing.space8
        spacing: root.theme.spacing.space2

        Text {
            width: parent.width
            text: NetworkMenuLogic.audioOutputLabel(root.device)
            color: root.active ? Colors.primary : Colors.on_surface
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeMd
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: NetworkMenuLogic.audioOutputStatus(root.device, root.active)
            color: root.active ? Colors.primary : Colors.on_surface_variant
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
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
        color: actionInput.containsMouse || actionInput.activeFocus ? Colors.hover : "transparent"

        Text {
            id: actionLabel

            anchors.centerIn: parent
            text: root.active ? "Active" : "Use"
            color: actionInput.containsMouse || actionInput.activeFocus ? Colors.on_hover : (root.active
                                                                                                    ? Colors.on_surface_variant : Colors.primary)
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
        }

        MouseArea {
            id: actionInput

            objectName: "audioOutputDeviceAction"
            anchors.fill: parent
            enabled: root.available && !root.active
            hoverEnabled: true
            activeFocusOnTab: enabled
            cursorShape: actionInput.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            Accessible.role: Accessible.Button
            Accessible.name: root.active ? [NetworkMenuLogic.audioOutputLabel(root.device), " is active"].join("") :
                                           ["Use ", NetworkMenuLogic.audioOutputLabel(root.device), " as output"].join(
                                               "")

            onClicked: root.requestSelect()
            Keys.onSpacePressed: root.requestSelect()
            Keys.onReturnPressed: root.requestSelect()
            Keys.onEnterPressed: root.requestSelect()
        }
    }
}
