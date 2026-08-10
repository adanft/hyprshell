import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"

Scope {
    id: root

    required property var screen
    required property var theme
    property var network: null
    property string errorText: ""

    readonly property var icons: Icons
    readonly property bool busy: Boolean(network?.stateChanging)

    signal submitted(string password)
    signal cancelled

    function focusPassword(selectExisting) {
        passwordInput.forceActiveFocus()
        if (selectExisting)
            passwordInput.selectAll()
    }

    function togglePasswordVisibility() {
        passwordInput.echoMode = passwordInput.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password
        focusPassword(false)
    }

    function submitCurrentPassword() {
        if (passwordInput.text.length > 0 && !busy)
            submitted(passwordInput.text)
    }

    onErrorTextChanged: {
        if (errorText.length > 0 && panel.visible)
            Qt.callLater(() => root.focusPassword(true))
    }

    PanelWindow {
        id: panel

        visible: root.network !== null
        screen: root.screen
        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        mask: null
        color: "transparent"
        surfaceFormat.opaque: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "qs-statusbar-wifi-password-modal"

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        Shortcut {
            sequence: "Escape"
            onActivated: root.cancelled()
        }

        onVisibleChanged: {
            if (visible) {
                passwordInput.text = ""
                passwordInput.echoMode = TextInput.Password
                Qt.callLater(() => root.focusPassword(false))
            } else {
                passwordInput.text = ""
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colors.shadow, 0.5)
            focus: true

            Keys.onEscapePressed: root.cancelled()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.cancelled()
            }

            Rectangle {
                id: dialog

                width: Math.min(root.theme.sizing.statusBarWifiPasswordModalMaxWidth,
                                parent.width - root.theme.spacing.appLauncherPadding * 2)
                height: dialogContent.implicitHeight + root.theme.spacing.appLauncherPadding * 2
                anchors.centerIn: parent
                radius: root.theme.shape.appLauncherRadius
                // Same body the launcher, screenshot tool and selectors use:
                // opaque shadow, no border, one padding token.
                color: Colors.shadow

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Column {
                    id: dialogContent

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: root.theme.spacing.appLauncherPadding
                    spacing: root.theme.spacing.appLauncherSectionSpacing

                    Item {
                        width: parent.width
                        height: Math.max(titleColumn.implicitHeight, closeButton.height)

                        Column {
                            id: titleColumn
                            anchors.left: parent.left
                            anchors.right: closeButton.left
                            anchors.rightMargin: root.theme.spacing.space12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.theme.spacing.space2

                            Text {
                                width: parent.width
                                text: "Connect to Wi-Fi"
                                color: Colors.on_surface
                                font.family: root.theme.typography.textFontFamily
                                font.pixelSize: root.theme.typography.sizeLg
                                font.styleName: root.theme.typography.styleMedium
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: root.network ? `Enter password for ${root.network.name}` : "Enter password"
                                color: Colors.on_surface_variant
                                font.family: root.theme.typography.textFontFamily
                                font.pixelSize: root.theme.typography.sizeSm
                                font.styleName: root.theme.typography.styleRegular
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            id: closeButton
                            width: root.theme.sizing.statusBarWifiPasswordCloseButtonSize
                            height: root.theme.sizing.statusBarWifiPasswordCloseButtonSize
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            radius: height / 2
                            color: closeInput.containsMouse || closeInput.activeFocus ? Colors.hover :
                                                                                        "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: root.icons.close
                                color: closeInput.containsMouse || closeInput.activeFocus ? Colors.on_hover :
                                                                                            Colors.on_surface_variant
                                font.family: root.theme.typography.iconFontFamily
                                font.pixelSize: root.theme.typography.sizeLg
                                font.styleName: root.theme.typography.styleRegular
                            }

                            MouseArea {
                                id: closeInput
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: "Close Wi-Fi password dialog"
                                onClicked: root.cancelled()
                                Keys.onSpacePressed: root.cancelled()
                                Keys.onReturnPressed: root.cancelled()
                                Keys.onEnterPressed: root.cancelled()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: root.theme.sizing.appLauncherSearchHeight
                        radius: root.theme.shape.appLauncherSearchRadius
                        color: Colors.surface
                        // No focus ring. The dialog puts the caret in this field
                        // the moment it opens, so a ring that paints on focus was
                        // painted from the first frame - a 2px border by another
                        // name, and the one thing that did not match the search
                        // field this is otherwise a copy of. The caret is the
                        // focus indicator here.

                        TextInput {
                            id: passwordInput
                            anchors.left: parent.left
                            anchors.right: visibilityButton.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: root.theme.spacing.space12
                            anchors.rightMargin: root.theme.spacing.space8
                            color: Colors.on_surface
                            selectionColor: Colors.primary
                            selectedTextColor: Colors.on_primary
                            echoMode: TextInput.Password
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: root.theme.typography.textFontFamily
                            font.pixelSize: root.theme.typography.sizeMd
                            font.styleName: root.theme.typography.styleRegular
                            enabled: !root.busy
                            Accessible.role: Accessible.EditableText
                            Accessible.name: root.network ? `Password for ${root.network.name}` : "Wi-Fi password"
                            onAccepted: root.submitCurrentPassword()
                        }

                        Item {
                            id: visibilityButton
                            width: root.theme.sizing.statusBarWifiPasswordVisibilityButtonWidth
                            height: parent.height
                            anchors.right: parent.right

                            Text {
                                anchors.centerIn: parent
                                text: passwordInput.echoMode === TextInput.Password ? root.icons.passwordHidden :
                                                                                      root.icons.passwordVisible
                                color: Colors.on_surface_variant
                                font.family: root.theme.typography.iconFontFamily
                                font.pixelSize: root.theme.typography.sizeMd
                                font.styleName: root.theme.typography.styleRegular
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: passwordInput.echoMode === TextInput.Password ? "Show password" :
                                                                                                 "Hide password"
                                onClicked: root.togglePasswordVisibility()
                                Keys.onSpacePressed: root.togglePasswordVisibility()
                                Keys.onReturnPressed: root.togglePasswordVisibility()
                                Keys.onEnterPressed: root.togglePasswordVisibility()
                            }
                        }
                    }

                    Text {
                        visible: root.errorText.length > 0
                        width: parent.width
                        text: root.errorText
                        color: Colors.error
                        font.family: root.theme.typography.textFontFamily
                        font.pixelSize: root.theme.typography.sizeSm
                        font.styleName: root.theme.typography.styleRegular
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: root.theme.spacing.space8

                        Rectangle {
                            width: cancelLabel.implicitWidth + root.theme.spacing.space24
                            height: root.theme.sizing.statusBarWifiPasswordActionHeight
                            radius: height / 2
                            color: cancelInput.containsMouse || cancelInput.activeFocus ? Colors.hover :
                                                                                          Colors.surface

                            Text {
                                id: cancelLabel
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: cancelInput.containsMouse || cancelInput.activeFocus ? Colors.on_hover :
                                                                                              Colors.on_surface
                                font.family: root.theme.typography.textFontFamily
                                font.pixelSize: root.theme.typography.sizeMd
                                font.styleName: root.theme.typography.styleMedium
                            }

                            MouseArea {
                                id: cancelInput
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: "Cancel Wi-Fi connection"
                                onClicked: root.cancelled()
                                Keys.onSpacePressed: root.cancelled()
                                Keys.onReturnPressed: root.cancelled()
                                Keys.onEnterPressed: root.cancelled()
                            }
                        }

                        Rectangle {
                            width: connectLabel.implicitWidth + root.theme.spacing.space24
                            height: root.theme.sizing.statusBarWifiPasswordActionHeight
                            radius: height / 2
                            color: Colors.primary
                            opacity: passwordInput.text.length > 0 && !root.busy ? 1 : root.theme.motion.opacityDisabled

                            Text {
                                id: connectLabel
                                anchors.centerIn: parent
                                text: root.busy ? "Please wait…" : "Connect"
                                color: Colors.on_primary
                                font.family: root.theme.typography.textFontFamily
                                font.pixelSize: root.theme.typography.sizeMd
                                font.styleName: root.theme.typography.styleMedium
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: passwordInput.text.length > 0 && !root.busy
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                activeFocusOnTab: enabled
                                Accessible.role: Accessible.Button
                                Accessible.name: root.network ? `Connect to ${root.network.name}` : "Connect to Wi-Fi"
                                onClicked: root.submitCurrentPassword()
                                Keys.onSpacePressed: root.submitCurrentPassword()
                                Keys.onReturnPressed: root.submitCurrentPassword()
                                Keys.onEnterPressed: root.submitCurrentPassword()
                            }
                        }
                    }
                }
            }
        }
    }
}
