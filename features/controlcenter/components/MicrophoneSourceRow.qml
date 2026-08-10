import QtQuick
import "../ControlCenter.js" as ControlCenterLogic
import "../../../theme"
import ".."

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

    height: ControlCenterSizing.deviceRowHeight
    radius: root.theme.shape.radius12
    color: Colors.surface

    Accessible.role: Accessible.ListItem
    Accessible.name: [ControlCenterLogic.audioSourceLabel(root.source), ", ", ControlCenterLogic.audioSourceStatus(
            root.source, root.active ? root.source : null)].join("")

    Text {
        id: sourceIcon

        width: ControlCenterSizing.quickControlIconWidth
        anchors.left: parent.left
        anchors.leftMargin: root.theme.spacing.space12
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: root.active ? Colors.primary : Colors.on_surface
        horizontalAlignment: Text.AlignHCenter
        font.family: root.theme.typography.iconFontFamily
        font.pixelSize: root.theme.typography.textBase
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
            text: ControlCenterLogic.audioSourceLabel(root.source)
            color: root.active ? Colors.primary : Colors.on_surface
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.textMd
            font.styleName: root.theme.typography.styleSemibold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: ControlCenterLogic.audioSourceStatus(root.source, root.active ? root.source : null)
            color: root.active ? Colors.primary : Colors.on_surface_variant
            font.family: root.theme.typography.textFontFamily
            font.pixelSize: root.theme.typography.textSm
            font.styleName: root.theme.typography.styleRegular
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: actionButton

        width: actionLabel.implicitWidth + root.theme.spacing.space16
        height: ControlCenterSizing.actionHeight
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
            font.pixelSize: root.theme.typography.textSm
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
            Accessible.name: root.active ? [ControlCenterLogic.audioSourceLabel(root.source), " is active"].join("") :
                                           ["Use ", ControlCenterLogic.audioSourceLabel(root.source),
                                            " as microphone"].join("")

            onClicked: root.requestSelect()
            Keys.onSpacePressed: root.requestSelect()
            Keys.onReturnPressed: root.requestSelect()
            Keys.onEnterPressed: root.requestSelect()
        }
    }
}
