import QtQuick
import "../../../theme"
import "../../../shared/components"
import ".."

// The wired adapter as one list entry: its port glyph, its name with the
// address underneath, and its state trailing. Everything else nmcli knows -
// gateway, DNS, IPv6, MAC, link speed - is deliberately not here.
Rectangle {
    id: card

    required property var theme
    property string interfaceName: ""
    property bool wired: false
    property bool online: false
    property string address: ""

    readonly property var icons: Icons
    readonly property color tone: online ? Colors.primary : Colors.on_surface_variant
    // nmcli reports IP4.ADDRESS in CIDR form; the prefix is not what this card
    // is read for, so only the address itself is shown.
    readonly property string bareAddress: address.split("/")[0]
    readonly property bool present: interfaceName.length > 0
    readonly property string stateText: !present ? "Unavailable" : (online ? "Connected" : (wired ? "Cable in" :
                                                                                                    "No cable"))

    // Fixed so the panel does not jump when the address appears or goes away.
    height: ControlCenterSizing.infoCardHeight
    radius: theme.shape.radius12
    color: Colors.surface
    border.width: 0

    AppText {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: card.theme.spacing.space12
        anchors.verticalCenter: parent.verticalCenter
        // One glyph in every state: the tone, the dot and the label already
        // say three times over whether the link is up.
        text: card.icons.network.ethernetPort
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
            text: card.icons.ui.dot
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
            text: card.interfaceName || "No wired adapter"
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
