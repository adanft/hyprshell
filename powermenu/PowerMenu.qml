import "../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: powerMenu

    readonly property var
    theme: AppTheme {
    }

    property alias visible: panel.visible
    property bool quitOnClose: false
    property bool confirming: false
    property var pendingCommand: []
    property int selectedIndex: 0
    property int confirmSelectedIndex: 0
    readonly property var actions: [{
        "icon": "",
        "command": ["loginctl", "lock-session"],
        "primary": theme.colors.powerLock
    }, {
        "icon": "",
        "command": ["systemctl", "suspend"],
        "primary": theme.colors.info
    }, {
        "icon": "",
        "command": ["hyprctl", "dispatch", "hl.dsp.exit()"],
        "primary": theme.colors.primary
    }, {
        "icon": "",
        "command": ["systemctl", "reboot"],
        "primary": theme.colors.success
    }, {
        "icon": "",
        "command": ["systemctl", "poweroff"],
        "primary": theme.colors.danger
    }]

    function open() {
        confirming = false;
        pendingCommand = [];
        selectedIndex = 0;
        confirmSelectedIndex = 0;
        panel.visible = true;
    }

    function close() {
        panel.visible = false;
        confirming = false;
        pendingCommand = [];
        if (quitOnClose)
            Qt.quit();

    }

    function toggle() {
        panel.visible ? close() : open();
    }

    function confirmCommand(command) {
        powerMenu.pendingCommand = command;
        powerMenu.confirming = true;
        powerMenu.confirmSelectedIndex = 0;
    }

    function runCommand(command) {
        Quickshell.execDetached(command);
        powerMenu.close();
    }

    function cancelConfirm() {
        powerMenu.confirming = false;
        powerMenu.pendingCommand = [];
    }

    function moveSelection(direction) {
        if (powerMenu.confirming) {
            powerMenu.confirmSelectedIndex = (powerMenu.confirmSelectedIndex + direction + 2) % 2;
            return ;
        }
        powerMenu.selectedIndex = (powerMenu.selectedIndex + direction + powerMenu.actions.length) % powerMenu.actions.length;
    }

    function triggerSelection() {
        if (powerMenu.confirming) {
            powerMenu.confirmSelectedIndex === 0 ? powerMenu.runCommand(powerMenu.pendingCommand) : powerMenu.cancelConfirm();
            return ;
        }
        const action = powerMenu.actions[powerMenu.selectedIndex];
        powerMenu.confirmCommand(action.command);
    }

    PanelWindow {
        id: panel

        visible: false
        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        mask: null
        color: powerMenu.theme.colors.transparent
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
            color: powerMenu.theme.colors.scrim
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
                icon: ""
                primary: powerMenu.theme.colors.success
                selected: powerMenu.confirmSelectedIndex === 0
                onHovered: powerMenu.confirmSelectedIndex = 0
                onActivated: powerMenu.runCommand(powerMenu.pendingCommand)
            }

            ActionButton {
                icon: ""
                primary: powerMenu.theme.colors.danger
                selected: powerMenu.confirmSelectedIndex === 1
                onHovered: powerMenu.confirmSelectedIndex = 1
                onActivated: powerMenu.cancelConfirm()
            }

        }

    }

}
