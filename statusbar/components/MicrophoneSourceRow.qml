import QtQuick
import "NetworkMenu.js" as NetworkMenuLogic
import "../../theme"

Rectangle {
    id: root

    required property var source
    required property var theme
    required property string icon
    property bool active: false

    signal selectRequested(var source)

    function requestSelect() {
        if (!root.active)
            root.selectRequested(root.source)
    }

    height: root.theme.sizing.statusBarNetworkDeviceRowHeight
    radius: root.theme.shape.radius12
    color: Colors.surface

    Accessible.role: Accessible.ListItem
    Accessible.name: [NetworkMenuLogic.audioSourceLabel(root.source), ", ", NetworkMenuLogic.audioSourceStatus(
            root.source, root.active ? root.source : null)].join("")

    Text {
        id: sourceIcon

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
        anchors.left: sourceIcon.right
        anchors.right: actionButton.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.theme.spacing.space12
        anchors.rightMargin: root.theme.spacing.space12
        spacing: root.theme.spacing.space2

        Text {
            width: parent.width
            text: NetworkMenuLogic.audioSourceLabel(root.source)
            color: root.active ? Colors.primary : Colors.on_surface
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeMd
            font.styleName: root.theme.typography.styleSemibold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: NetworkMenuLogic.audioSourceStatus(root.source, root.active ? root.source : null)
            color: root.active ? Colors.primary : Colors.on_surface_variant
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
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

        Text {
            id: actionLabel

            anchors.centerIn: parent
            text: root.active ? "Active" : "Use"
            color: actionInput.containsMouse || actionInput.activeFocus ? Colors.on_hover : (root.active
                                                                                                    ? Colors.on_surface_variant : Colors.primary)
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.sizeSm
            font.styleName: root.theme.typography.styleMedium
        }

        MouseArea {
            id: actionInput

            objectName: "microphoneSourceAction"
            anchors.fill: parent
            enabled: !root.active
            hoverEnabled: true
            activeFocusOnTab: enabled
            cursorShape: actionInput.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            Accessible.role: Accessible.Button
            Accessible.name: root.active ? [NetworkMenuLogic.audioSourceLabel(root.source), " is active"].join("") :
                                           ["Use ", NetworkMenuLogic.audioSourceLabel(root.source),
                                            " as microphone"].join("")

            onClicked: root.requestSelect()
            Keys.onSpacePressed: root.requestSelect()
            Keys.onReturnPressed: root.requestSelect()
            Keys.onEnterPressed: root.requestSelect()
        }
    }
}
