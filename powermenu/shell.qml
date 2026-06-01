import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: shell

    property bool confirming: false
    property var pendingCommand: []
    property int selectedIndex: 0
    property int confirmSelectedIndex: 0

    readonly property var actions: [
        { icon: "", command: ["loginctl", "lock-session"], accent: "#fab387" },
        { icon: "", command: ["systemctl", "suspend"], accent: "#89b4fa" },
        { icon: "", command: ["hyprctl", "dispatch", "hl.dsp.exit()"], accent: "#cba6f7" },
        { icon: "", command: ["systemctl", "reboot"], accent: "#a6e3a1" },
        { icon: "", command: ["systemctl", "poweroff"], accent: "#f38ba8" }
    ]

    PanelWindow {
        visible: true
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
            color: "#bf1e1e2e"
            focus: true

            Keys.onEscapePressed: Qt.quit()
            Keys.onLeftPressed: shell.moveSelection(-1)
            Keys.onRightPressed: shell.moveSelection(1)
            Keys.onReturnPressed: shell.triggerSelection()
            Keys.onEnterPressed: shell.triggerSelection()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Loader {
                anchors.centerIn: parent
                sourceComponent: shell.confirming ? confirmButtons : powerButtons
            }
        }
    }

    Component {
        id: powerButtons

        Row {
            spacing: 18

            Repeater {
                model: shell.actions

                ActionButton {
                    required property var modelData
                    required property int index

                    icon: modelData.icon
                    accent: modelData.accent
                    selected: shell.selectedIndex === index
                    onHovered: shell.selectedIndex = index
                    onActivated: shell.confirmCommand(modelData.command)
                }
            }
        }
    }

    Component {
        id: confirmButtons

        Row {
            spacing: 18

            ActionButton {
                icon: ""
                accent: "#a6e3a1"
                selected: shell.confirmSelectedIndex === 0
                onHovered: shell.confirmSelectedIndex = 0
                onActivated: shell.runCommand(shell.pendingCommand)
            }

            ActionButton {
                icon: ""
                accent: "#f38ba8"
                selected: shell.confirmSelectedIndex === 1
                onHovered: shell.confirmSelectedIndex = 1
                onActivated: shell.cancelConfirm()
            }
        }
    }

    function confirmCommand(command) {
        shell.pendingCommand = command
        shell.confirming = true
        shell.confirmSelectedIndex = 0
    }

    function runCommand(command) {
        Quickshell.execDetached(command)
        Qt.quit()
    }

    function cancelConfirm() {
        shell.confirming = false
        shell.pendingCommand = []
    }

    function moveSelection(direction) {
        if (shell.confirming) {
            shell.confirmSelectedIndex = (shell.confirmSelectedIndex + direction + 2) % 2
            return
        }

        shell.selectedIndex = (shell.selectedIndex + direction + shell.actions.length) % shell.actions.length
    }

    function triggerSelection() {
        if (shell.confirming) {
            shell.confirmSelectedIndex === 0 ? shell.runCommand(shell.pendingCommand) : shell.cancelConfirm()
            return
        }

        const action = shell.actions[shell.selectedIndex]
        shell.confirmCommand(action.command)
    }
}
