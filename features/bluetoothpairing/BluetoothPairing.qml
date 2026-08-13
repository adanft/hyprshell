import "."
import "../../shared/components"
import "../../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland

// The dialog BlueZ is waiting on.
//
// Unlike every other overlay in this shell, this one is not opened by the
// person using it: it appears because a device asked something, and it must
// answer before it can close. Dismissing it — Escape, a click outside — is
// therefore a refusal that gets sent, not a way to make it go away. A dialog
// that vanished without answering would leave the pairing hanging until the
// agent gave up on its own.
Scope {
    id: pairing

    readonly property var theme: AppTheme

    required property var services

    readonly property var request: services.pairingAgent.pairingRequest
    readonly property string kind: request ? request.kind : ""
    readonly property bool active: request !== null

    // Only these two put the answer in a field. The rest are decided with a
    // button, and showing an empty input beside them would suggest otherwise.
    readonly property bool needsInput: kind === "request-pin" || kind === "request-passkey"
    // These are announcements. There is nothing to accept, only to abandon.
    readonly property bool isAnnouncement: kind === "display-pin" || kind === "display-passkey"

    readonly property string headline: {
        switch (kind) {
        case "confirm":
            return "Does this code match?";
        case "authorize":
            return "Allow this device to pair?";
        case "authorize-service":
            return "Allow this service?";
        case "display-pin":
            return "Type this PIN on the device";
        case "display-passkey":
            return "Type this code on the device";
        case "request-pin":
            return "Enter the device's PIN";
        case "request-passkey":
            return "Enter the device's code";
        default:
            return "";
        }
    }

    // The passkey is padded because BlueZ sends it as a number: a code of
    // 042315 arrives as 42315, and a person comparing it against a phone would
    // read five digits where the phone shows six.
    readonly property string codeText: {
        if (kind === "display-pin")
            return request ? request.pin : "";
        if (!request || request.passkey < 0)
            return "";
        return String(request.passkey).padStart(6, "0");
    }

    function accept() {
        if (pairing.needsInput) {
            pairing.submitInput();
            return;
        }
        pairing.services.pairingAgent.answerPairing("accept");
    }

    function reject() {
        if (pairing.active)
            pairing.services.pairingAgent.answerPairing("reject");
    }

    function submitInput() {
        const text = codeInput.text.trim();
        if (text.length === 0)
            return;

        if (pairing.kind === "request-passkey")
            pairing.services.pairingAgent.submitPairingPasskey(text);
        else
            pairing.services.pairingAgent.submitPairingPin(text);
    }

    onActiveChanged: {
        if (active && needsInput)
            Qt.callLater(() => codeInput.forceActiveFocus());
        else
            codeInput.text = "";
    }

    PanelWindow {
        id: panel

        visible: pairing.active
        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        mask: null
        color: "transparent"
        surfaceFormat.opaque: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "qs-bluetooth-pairing"

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colors.shadow, 0.5)
            focus: !pairing.needsInput

            Keys.onEscapePressed: pairing.reject()
            Keys.onReturnPressed: pairing.accept()
            Keys.onEnterPressed: pairing.accept()

            // The same rule as every other overlay: a click outside dismisses.
            // Here dismissing has to travel, so it answers first.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: pairing.reject()
            }

            // The same body the launcher, the screenshot tool, the selectors
            // and the wifi password modal use: opaque shadow, no border, one
            // padding token. Copied rather than invented, so this dialog does
            // not become the one overlay that looks like a stranger.
            Rectangle {
                id: dialog

                width: Math.min(460, parent.width - pairing.theme.spacing.space18 * 2)
                height: dialogContent.implicitHeight + pairing.theme.spacing.space18 * 2
                anchors.centerIn: parent
                radius: pairing.theme.shape.appLauncherRadius
                color: Colors.shadow

                // Swallows clicks so the backdrop's refusal does not fire when
                // someone aims at the card and misses a button.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                // Anchored to the sides with a margin, exactly as the wifi
                // password dialog does it. Giving the column an x and a width
                // instead left it with no height to report, so the card it was
                // meant to fill collapsed and drew nothing — while the children
                // still painted, because QML does not clip by default. That is
                // the floating icon with no box behind it.
                Column {
                    id: dialogContent

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: pairing.theme.spacing.space18
                    spacing: pairing.theme.spacing.space18

                    // Title and subtitle, left aligned: the wifi password
                    // dialog's header minus its close button. Closing here is a
                    // refusal that has to travel back to BlueZ, and a close
                    // glyph reads as "put this away", which is the one thing
                    // this dialog must not let you do by accident.
                    Column {
                        width: parent.width
                        spacing: pairing.theme.spacing.space2

                        AppText {
                            width: parent.width
                            text: pairing.headline
                            color: Colors.on_surface
                            font.pixelSize: pairing.theme.typography.textBase
                            font.styleName: pairing.theme.typography.styleMedium
                            elide: Text.ElideRight
                        }

                        AppText {
                            width: parent.width
                            text: pairing.request ? pairing.request.deviceName : ""
                            color: Colors.on_surface_variant
                            font.pixelSize: pairing.theme.typography.textSm
                            font.styleName: pairing.theme.typography.styleRegular
                            elide: Text.ElideRight
                        }
                    }

                    // One box for the value, whether it is read or typed. This
                    // is the search field's body, which the wifi password
                    // dialog also borrows: a code to compare and a code to
                    // enter are the same thing to a person, so they get the
                    // same frame.
                    Rectangle {
                        visible: pairing.codeText.length > 0 || pairing.needsInput
                        width: parent.width
                        height: pairing.theme.sizing.searchFieldHeight
                        radius: pairing.theme.shape.appLauncherSearchRadius
                        color: Colors.surface

                        AppText {
                            visible: !pairing.needsInput
                            anchors.centerIn: parent
                            text: pairing.codeText
                            color: Colors.on_surface
                            font.pixelSize: pairing.theme.typography.textLg
                            font.styleName: pairing.theme.typography.styleMedium
                        }

                        TextInput {
                            id: codeInput

                            visible: pairing.needsInput
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: pairing.theme.spacing.space12
                            anchors.rightMargin: pairing.theme.spacing.space12
                            color: Colors.on_surface
                            selectionColor: Colors.primary
                            selectedTextColor: Colors.on_primary
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: pairing.theme.typography.textFontFamily
                            font.pixelSize: pairing.theme.typography.textMd
                            font.styleName: pairing.theme.typography.styleRegular
                            // A passkey is a number and a PIN is not, so the
                            // keyboard is constrained where the protocol is.
                            inputMethodHints: pairing.kind === "request-passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
                            Accessible.role: Accessible.EditableText
                            Accessible.name: pairing.headline
                            onAccepted: pairing.accept()
                            Keys.onEscapePressed: pairing.reject()
                        }
                    }

                    // How much of the code has landed on the other device. Only
                    // display-passkey reports this, and it is why that question
                    // arrives again and again for one pairing.
                    AppText {
                        visible: pairing.kind === "display-passkey"
                        width: parent.width
                        text: `${pairing.request ? pairing.request.entered : 0} of 6 entered`
                        color: Colors.on_surface_variant
                        font.pixelSize: pairing.theme.typography.textSm
                        font.styleName: pairing.theme.typography.styleRegular
                    }

                    AppText {
                        visible: pairing.kind === "authorize-service"
                        width: parent.width
                        text: pairing.request ? pairing.request.uuid : ""
                        color: Colors.on_surface_variant
                        font.pixelSize: pairing.theme.typography.textSm
                        font.styleName: pairing.theme.typography.styleRegular
                        wrapMode: Text.WordWrap
                    }

                    // Straight into the column and anchored to its right
                    // edge, the way the wifi password dialog does it.
                    //
                    // A column governs only the y of its children, so a
                    // horizontal anchor was never the conflict I first took it
                    // for. What looped was the buttons declaring an implicit
                    // width that fed the very size deciding it, and what drew
                    // nothing afterwards was wrapping them in an item that had
                    // no width to give. Both went away by copying a dialog that
                    // has worked all along instead of reasoning from scratch.
                    Row {
                        anchors.right: parent.right
                        spacing: pairing.theme.spacing.space8

                        Rectangle {
                            width: rejectLabel.implicitWidth + pairing.theme.spacing.space24
                            height: BluetoothPairingSizing.actionHeight
                            radius: height / 2
                            color: rejectInput.containsMouse
                                || rejectInput.activeFocus ? Colors.hover : Colors.surface

                            AppText {
                                id: rejectLabel

                                anchors.centerIn: parent
                                // An announcement cannot be agreed with, only
                                // abandoned, so this carries the only label.
                                text: pairing.isAnnouncement ? "Cancel" : "Reject"
                                color: rejectInput.containsMouse
                                    || rejectInput.activeFocus ? Colors.on_hover : Colors.on_surface
                            }

                            MouseArea {
                                id: rejectInput

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: "Refuse this pairing"
                                onClicked: pairing.reject()
                                Keys.onSpacePressed: pairing.reject()
                                Keys.onReturnPressed: pairing.reject()
                                Keys.onEnterPressed: pairing.reject()
                            }
                        }

                        Rectangle {
                            visible: !pairing.isAnnouncement
                            width: acceptLabel.implicitWidth + pairing.theme.spacing.space24
                            height: BluetoothPairingSizing.actionHeight
                            radius: height / 2
                            color: acceptInput.containsMouse
                                || acceptInput.activeFocus ? Colors.hover : Colors.primary

                            AppText {
                                id: acceptLabel

                                anchors.centerIn: parent
                                text: "Accept"
                                color: acceptInput.containsMouse
                                    || acceptInput.activeFocus ? Colors.on_hover : Colors.on_primary
                            }

                            MouseArea {
                                id: acceptInput

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: "Accept this pairing"
                                onClicked: pairing.accept()
                                Keys.onSpacePressed: pairing.accept()
                                Keys.onReturnPressed: pairing.accept()
                                Keys.onEnterPressed: pairing.accept()
                            }
                        }
                    }
                }
            }
        }
    }
}
