import "../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: powerMenu

    readonly property var theme: AppTheme
    readonly property var icons: Icons

    property alias visible: panel.visible
    property bool quitOnClose: false
    property bool confirming: false
    property var pendingCommand: []
    property int selectedIndex: 0
    property int confirmSelectedIndex: 0
    readonly property var actions: [
        {
            "icon": icons.lockSession,
            "command": ["loginctl", "lock-session"],
            "primary": Colors.secondary
        },
        {
            "icon": icons.suspendSession,
            "command": ["systemctl", "suspend"],
            "primary": Colors.tertiary
        },
        {
            "icon": icons.logoutSession,
            "command": ["hyprctl", "dispatch", "hl.dsp.exit()"],
            "primary": Colors.primary
        },
        {
            "icon": icons.rebootSession,
            "command": ["systemctl", "reboot"],
            "primary": Colors.hover
        },
        {
            "icon": icons.powerOffSession,
            "command": ["systemctl", "poweroff"],
            "primary": Colors.error
        }
    ]

    function open() {
        confirming = false
        pendingCommand = []
        selectedIndex = 0
        confirmSelectedIndex = 0
        panel.visible = true
    }

    function close() {
        panel.visible = false
        confirming = false
        pendingCommand = []
        if (quitOnClose)
            Qt.quit()
    }

    function toggle() {
        panel.visible ? close() : open()
    }

    function confirmCommand(command) {
        powerMenu.pendingCommand = command
        powerMenu.confirming = true
        powerMenu.confirmSelectedIndex = 0
    }

    function runCommand(command) {
        Quickshell.execDetached(command)
        powerMenu.close()
    }

    function cancelConfirm() {
        powerMenu.confirming = false
        powerMenu.pendingCommand = []
    }

    function moveSelection(direction) {
        if (powerMenu.confirming) {
            powerMenu.confirmSelectedIndex = (powerMenu.confirmSelectedIndex + direction + 2) % 2
            return
        }
        powerMenu.selectedIndex = (powerMenu.selectedIndex + direction + powerMenu.actions.length)
                % powerMenu.actions.length
    }

    function triggerSelection() {
        if (powerMenu.confirming) {
            powerMenu.confirmSelectedIndex === 0 ? powerMenu.runCommand(powerMenu.pendingCommand) :
                                                   powerMenu.cancelConfirm()
            return
        }
        const action = powerMenu.actions[powerMenu.selectedIndex]
        powerMenu.confirmCommand(action.command)
    }

    PanelWindow {
        id: panel

        visible: false
        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        mask: null
        color: "transparent"
        surfaceFormat.opaque: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colors.shadow, 0.25)
            focus: true
            Keys.onEscapePressed: powerMenu.confirming ? powerMenu.cancelConfirm() : powerMenu.close()
            Keys.onLeftPressed: powerMenu.moveSelection(-1)
            Keys.onRightPressed: powerMenu.moveSelection(1)
            Keys.onReturnPressed: powerMenu.triggerSelection()
            Keys.onEnterPressed: powerMenu.triggerSelection()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Loader {
                anchors.centerIn: parent
                active: panel.visible
                sourceComponent: powerMenu.confirming ? confirmButtons : powerButtons
            }
        }
    }

    Component {
        id: powerButtons

        Row {
            spacing: powerMenu.theme.spacing.powerMenuActionSpacing

            Repeater {
                model: powerMenu.actions

                ActionButton {
                    required property var modelData
                    required property int index

                    icon: modelData.icon
                    primary: modelData.primary
                    selected: powerMenu.selectedIndex === index
                    onHovered: powerMenu.selectedIndex = index
                    onActivated: powerMenu.confirmCommand(modelData.command)
                }
            }
        }
    }

    Component {
        id: confirmButtons

        Row {
            spacing: powerMenu.theme.spacing.powerMenuActionSpacing

            ActionButton {
                icon: powerMenu.icons.confirm
                primary: Colors.hover
                selected: powerMenu.confirmSelectedIndex === 0
                onHovered: powerMenu.confirmSelectedIndex = 0
                onActivated: powerMenu.runCommand(powerMenu.pendingCommand)
            }

            ActionButton {
                icon: powerMenu.icons.cancel
                primary: Colors.error
                selected: powerMenu.confirmSelectedIndex === 1
                onHovered: powerMenu.confirmSelectedIndex = 1
                onActivated: powerMenu.cancelConfirm()
            }
        }
    }
}
