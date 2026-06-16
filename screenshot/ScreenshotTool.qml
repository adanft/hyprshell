import "../shared/components" as Shared
import "../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: tool

    readonly property var
    theme: AppTheme {
    }

    property alias visible: panel.visible
    property bool quitOnClose: false
    property bool includeCursor: false
    property int selectedActionIndex: 0
    readonly property string captureSuccessCommand: "wl-copy --type image/png < \"$file\" && notify-send -u low -i image-png \"Screenshot captured\" \"$(basename \"$file\")\\nCopied to clipboard\""

    function open() {
        panel.visible = true;
        Qt.callLater(() => {
            return overlay.forceActiveFocus();
        });
    }

    function close() {
        panel.visible = false;
        if (quitOnClose)
            Qt.quit();

    }

    function toggle() {
        panel.visible ? close() : open();
    }

    function capture(mode) {
        const grimCursorArg = includeCursor ? "-c " : "";
        let command = "";
        switch (mode) {
        case "monitor":
            command = captureCommand(`grim ${grimCursorArg}-o "${panel.screen.name}"`);
            break;
        case "window":
            command = `id=$(hyprctl activewindow -j | jq -r 'select(.stableId != null) | .stableId') && if [ -n "$id" ]; then sleep 0.5; ${captureCommand(`grim ${grimCursorArg}-T "$id"`)}; fi`;
            break;
        case "area":
            command = `geometry=$(slurp) && if [ -n "$geometry" ]; then ${captureCommand(`grim ${grimCursorArg}-g "$geometry"`)}; fi`;
            break;
        case "all":
        default:
            command = captureCommand(`grim ${grimCursorArg}`);
            break;
        }
        close();
        Qt.callLater(() => {
            Quickshell.execDetached(["sh", "-c", `mkdir -p "$HOME/Pictures/Screenshots" && sleep 0.2 && ${command}`]);
        });
    }

    function captureCommand(grimCommand) {
        return `file="$HOME/Pictures/Screenshots/screenshot_$(date +%Y-%m-%d-%H-%M-%S).png"; ${grimCommand} "$file" && ${captureSuccessCommand}`;
    }

    function actionIcon(index) {
        switch (index) {
        case 0:
            return "󰍹";
        case 1:
            return "󰹑";
        case 2:
            return "󰖲";
        case 3:
            return "󰆞";
        default:
            return "󰍹";
        }
    }

    function actionTitle(index) {
        switch (index) {
        case 0:
            return "All";
        case 1:
            return "Monitor";
        case 2:
            return "Window";
        case 3:
            return "Area";
        default:
            return "All";
        }
    }

    function actionDescription(index) {
        switch (index) {
        case 0:
            return "Capture the full desktop";
        case 1:
            return "Capture the current monitor";
        case 2:
            return "Capture the active window";
        case 3:
            return "Select an area to capture";
        default:
            return "Capture the full desktop";
        }
    }

    function actionMode(index) {
        switch (index) {
        case 0:
            return "all";
        case 1:
            return "monitor";
        case 2:
            return "window";
        case 3:
            return "area";
        default:
            return "all";
        }
    }

    function moveSelection(direction) {
        selectedActionIndex = Math.max(0, Math.min(3, selectedActionIndex + direction));
    }

    function activateSelection() {
        capture(actionMode(selectedActionIndex));
    }

    Component {
        id: screenshotContent

        Column {
            anchors.fill: parent
            anchors.margins: tool.theme.spacing.screenshotToolPadding
            spacing: tool.theme.spacing.screenshotToolSectionSpacing

            Rectangle {
                width: parent.width
                height: (parent.height - parent.spacing) / 2
                radius: tool.theme.shape.screenshotToolActionRadius
                color: tool.theme.colors.background

                Column {
                    anchors.centerIn: parent
                    width: parent.width - tool.theme.spacing.screenshotToolPadding * 2
                    spacing: tool.theme.spacing.space8

                    Shared.AppText {
                        width: parent.width
                        text: tool.actionIcon(tool.selectedActionIndex)
                        color: tool.theme.colors.primary
                        font.family: tool.theme.typography.iconFontFamily
                        font.pixelSize: tool.theme.typography.actionIconFontSize * 2
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Shared.AppText {
                        width: parent.width
                        text: tool.actionTitle(tool.selectedActionIndex)
                        color: tool.theme.colors.text
                        font.pixelSize: tool.theme.typography.sizeXl
                        font.styleName: tool.theme.typography.styleSemibold
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Shared.AppText {
                        width: parent.width
                        text: tool.actionDescription(tool.selectedActionIndex)
                        color: tool.theme.colors.textMuted
                        font.pixelSize: tool.theme.typography.sizeMd
                        font.styleName: tool.theme.typography.styleMedium
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }

                Row {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: tool.theme.spacing.screenshotToolPadding
                    spacing: tool.theme.spacing.space8

                    Shared.AppText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Cursor"
                        color: tool.theme.colors.text
                        font.pixelSize: tool.theme.typography.sizeMd
                        font.styleName: tool.theme.typography.styleSemibold
                    }

                    Rectangle {
                        id: cursorSwitch

                        anchors.verticalCenter: parent.verticalCenter
                        width: tool.theme.sizing.screenshotToolCursorSwitchWidth
                        height: tool.theme.sizing.screenshotToolCursorSwitchHeight
                        radius: height / 2
                        color: tool.includeCursor ? tool.theme.colors.primary : tool.theme.colors.surfaceActive

                        Rectangle {
                            width: tool.theme.sizing.screenshotToolCursorSwitchKnobSize
                            height: tool.theme.sizing.screenshotToolCursorSwitchKnobSize
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: tool.includeCursor ? parent.width - width - tool.theme.spacing.screenshotToolCursorSwitchKnobMargin : tool.theme.spacing.screenshotToolCursorSwitchKnobMargin
                            color: tool.includeCursor ? tool.theme.colors.primaryText : tool.theme.colors.textMuted

                            Behavior on x {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tool.includeCursor = !tool.includeCursor
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: (parent.height - parent.spacing) / 2

                Row {
                    anchors.centerIn: parent
                    spacing: tool.theme.spacing.screenshotToolActionRowSpacing

                    Repeater {
                        model: 4

                        ScreenshotAction {
                            required property int index

                            icon: tool.actionIcon(index)
                            title: tool.actionTitle(index)
                            selected: tool.selectedActionIndex === index
                            onActivated: tool.capture(tool.actionMode(index))
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: panel

        visible: false
        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        mask: null
        color: tool.theme.colors.transparent
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
            id: overlay

            anchors.fill: parent
            color: tool.theme.colors.scrim
            focus: true
            Keys.onEscapePressed: tool.close()
            Keys.onLeftPressed: tool.moveSelection(-1)
            Keys.onRightPressed: tool.moveSelection(1)
            Keys.onUpPressed: tool.includeCursor = !tool.includeCursor
            Keys.onDownPressed: tool.includeCursor = !tool.includeCursor
            Keys.onReturnPressed: tool.activateSelection()
            Keys.onEnterPressed: tool.activateSelection()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: tool.close()
            }

            Rectangle {
                id: container

                anchors.centerIn: parent
                width: Math.min(parent.width - tool.theme.spacing.screenshotToolScreenMargin, tool.theme.sizing.appLauncherMaxWidth)
                height: Math.min(parent.height - tool.theme.spacing.screenshotToolScreenMargin, tool.theme.sizing.appLauncherMaxHeight)
                radius: tool.theme.shape.screenshotToolRadius
                color: tool.theme.colors.panel
                border.width: tool.theme.shape.screenshotToolBorderWidth
                border.color: tool.theme.colors.border

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Loader {
                    id: contentLoader

                    anchors.fill: parent
                    active: panel.visible
                    sourceComponent: screenshotContent
                }

            }

        }

    }

}
