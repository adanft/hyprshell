import QtQuick
import "../../../theme"
import "../../../shared/components"

// The adapter as one list entry, structured like its network siblings. What it
// answers is different, though: Bluetooth exposes no address, and the adapter
// id (hci0) tells nobody anything. What is not visible anywhere else in this
// panel is whether other devices can see you, so that is the state it reports.
Rectangle {
    id: card

    required property var theme
    property string adapterName: ""
    property bool available: false
    property bool powered: false
    property bool discoverable: false
    property int connectedCount: 0

    signal visibilityToggleRequested

    readonly property var icons: Icons
    readonly property color tone: powered ? Colors.primary : Colors.on_surface_variant

    readonly property string stateText: {
        if (!available)
            return "Unavailable"
        if (!powered)
            return "Off"
        return discoverable ? "Visible" : "Hidden"
    }

    readonly property string connectedText: {
        if (!powered || connectedCount <= 0)
            return ""
        return connectedCount === 1 ? "1 device connected" : `${connectedCount} devices connected`
    }

    // Fixed so the panel does not jump as devices connect and disconnect.
    height: theme.sizing.statusBarNetworkInfoCardHeight
    radius: theme.shape.radius12
    color: Colors.surface
    border.width: 0

    AppText {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: card.theme.spacing.space12
        anchors.verticalCenter: parent.verticalCenter
        // One glyph in every state: the tone, the dot and the label already say
        // three times over whether the adapter is up.
        text: card.icons.bluetoothAdapter
        color: card.tone
        font.family: card.theme.typography.iconFontFamily
        font.pixelSize: card.theme.typography.actionIconFontSize
    }

    // Visibility is the one thing here you act on, and BluetoothAdapter exposes
    // `discoverable` as writable, so the state doubles as its own switch while
    // the adapter is powered. Off and Unavailable stay inert.
    Rectangle {
        id: state

        anchors.right: parent.right
        anchors.rightMargin: card.theme.spacing.space12
        anchors.verticalCenter: parent.verticalCenter
        width: stateContent.implicitWidth + card.theme.spacing.space12
        height: stateContent.implicitHeight + card.theme.spacing.space4
        radius: height / 2
        color: stateInput.containsMouse || stateInput.activeFocus ? Colors.hover : "transparent"

        Row {
            id: stateContent

            anchors.centerIn: parent
            spacing: card.theme.spacing.space6

            AppText {
                anchors.verticalCenter: parent.verticalCenter
                text: card.icons.workspaceDot
                color: stateInput.containsMouse ? Colors.on_hover : card.tone
                font.family: card.theme.typography.iconFontFamily
                font.pixelSize: card.theme.typography.sizeSm
            }

            AppText {
                anchors.verticalCenter: parent.verticalCenter
                text: card.stateText
                color: stateInput.containsMouse ? Colors.on_hover : card.tone
                font.pixelSize: card.theme.typography.sizeSm
                font.styleName: card.theme.typography.styleMedium
            }
        }

        MouseArea {
            id: stateInput

            anchors.fill: parent
            enabled: card.powered
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Button
            Accessible.name: card.discoverable ? "Hide from other devices" : "Make visible to other devices"
            onClicked: card.visibilityToggleRequested()
            Keys.onSpacePressed: card.visibilityToggleRequested()
            Keys.onReturnPressed: card.visibilityToggleRequested()
            Keys.onEnterPressed: card.visibilityToggleRequested()
        }
    }

    Column {
        id: identity

        anchors.left: glyph.right
        anchors.leftMargin: card.theme.spacing.space12
        anchors.right: state.left
        anchors.rightMargin: card.theme.spacing.space12
        anchors.verticalCenter: parent.verticalCenter
        spacing: card.theme.spacing.space2

        AppText {
            width: parent.width
            text: card.adapterName || "No Bluetooth adapter"
            color: Colors.on_surface
            font.pixelSize: card.theme.typography.sizeMd
            font.styleName: card.theme.typography.styleSemibold
            elide: Text.ElideRight
        }

        AppText {
            width: parent.width
            visible: card.connectedText.length > 0
            text: card.connectedText
            color: Colors.on_surface_variant
            font.pixelSize: card.theme.typography.sizeSm
            font.styleName: card.theme.typography.styleRegular
            elide: Text.ElideRight
        }
    }
}
