import QtQuick
import "../../../theme"
import "../../../shared/components"

// The wireless adapter as one list entry, mirroring EthernetInfoCard: the
// interface glyph, its name with the address beneath, and the state trailing.
// The SSID, signal, security, gateway, IPv6 and MAC belong to the network list
// below, not here.
Rectangle {
    id: card

    required property var theme
    property string interfaceName: ""
    property string address: ""
    property bool hardwareEnabled: true
    property bool radioEnabled: true
    property bool activating: false
    property bool online: false

    readonly property var icons: Icons
    readonly property bool present: interfaceName.length > 0
    readonly property color tone: online ? Colors.primary : Colors.on_surface_variant

    // nmcli reports IP4.ADDRESS in CIDR form; the prefix is not what this card
    // is read for, so only the address itself is shown.
    readonly property string bareAddress: address.split("/")[0]

    readonly property string stateText: {
        if (!present || !hardwareEnabled)
            return "Unavailable"
        if (activating)
            return "Enabling…"
        if (!radioEnabled)
            return "Disabled"
        return online ? "Connected" : "Not connected"
    }

    // Fixed so the panel does not jump when the address appears or goes away.
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
        // three times over whether the link is up.
        text: card.icons.wifiInterface
        color: card.tone
        font.family: card.theme.typography.iconFontFamily
        font.pixelSize: card.theme.typography.glyphLg
    }

    Row {
        id: state

        anchors.right: parent.right
        anchors.rightMargin: card.theme.spacing.space12
        anchors.verticalCenter: parent.verticalCenter
        spacing: card.theme.spacing.space6

        AppText {
            anchors.verticalCenter: parent.verticalCenter
            text: card.icons.workspaceDot
            color: card.tone
            font.family: card.theme.typography.iconFontFamily
            font.pixelSize: card.theme.typography.textSm
        }

        AppText {
            anchors.verticalCenter: parent.verticalCenter
            text: card.stateText
            color: card.tone
            font.pixelSize: card.theme.typography.textSm
            font.styleName: card.theme.typography.styleMedium
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
            text: card.interfaceName || "No Wi-Fi adapter"
            color: Colors.on_surface
            font.pixelSize: card.theme.typography.textMd
            font.styleName: card.theme.typography.styleSemibold
            elide: Text.ElideRight
        }

        AppText {
            width: parent.width
            visible: card.bareAddress.length > 0
            text: card.bareAddress
            color: Colors.on_surface_variant
            font.pixelSize: card.theme.typography.textSm
            font.styleName: card.theme.typography.styleRegular
            elide: Text.ElideRight
        }
    }
}
