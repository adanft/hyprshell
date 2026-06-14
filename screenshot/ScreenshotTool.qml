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
    readonly property int contentWidth: theme.screenshotToolActionWidth * 4 + theme.space12 * 3
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

    function moveSelection(direction) {
        selectedActionIndex = Math.max(0, Math.min(3, selectedActionIndex + direction));
    }

    function activateSelection() {
        switch (selectedActionIndex) {
        case 0:
            capture("all");
            break;
        case 1:
            capture("monitor");
            break;
        case 2:
            capture("window");
            break;
        case 3:
            capture("area");
            break;
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
            color: tool.theme.colors.baseScrim
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
                width: Math.min(parent.width - tool.theme.screenshotToolScreenMargin, tool.contentWidth + tool.theme.screenshotToolPadding * 2)
                height: Math.min(parent.height - tool.theme.screenshotToolScreenMargin, content.implicitHeight + tool.theme.screenshotToolPadding * 2)
                radius: tool.theme.screenshotToolRadius
                color: tool.theme.colors.mantlePanel
                border.width: tool.theme.screenshotToolBorderWidth
                border.color: tool.theme.colors.surface1

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Column {
                    id: content

                    anchors.fill: parent
                    anchors.margins: tool.theme.screenshotToolPadding
                    spacing: tool.theme.screenshotToolSectionSpacing

                    Row {
                        id: cursorRow

                        width: parent.width
                        height: tool.theme.screenshotToolCursorRowHeight

                        Shared.AppText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - cursorSwitch.width
                            text: "Cursor"
                            color: tool.theme.colors.text
                            font.pixelSize: tool.theme.fontSizeMd
                            font.styleName: tool.theme.fontStyleSemibold
                        }

                        Rectangle {
                            id: cursorSwitch

                            anchors.verticalCenter: parent.verticalCenter
                            width: tool.theme.notificationCenterDndSwitchWidth
                            height: tool.theme.notificationCenterDndSwitchHeight
                            radius: height / 2
                            color: tool.includeCursor ? tool.theme.colors.mauve : tool.theme.colors.surface0

                            Rectangle {
                                width: tool.theme.notificationCenterDndKnobSize
                                height: tool.theme.notificationCenterDndKnobSize
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: tool.includeCursor ? parent.width - width - tool.theme.notificationCenterDndKnobMargin : tool.theme.notificationCenterDndKnobMargin
                                color: tool.includeCursor ? tool.theme.colors.crust : tool.theme.colors.subtext0

                                Behavior on x {
                                    NumberAnimation {
                                        duration: tool.theme.notificationCenterDndAnimationMs
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

                    Row {
                        id: actionRow

                        width: parent.width
                        height: tool.theme.screenshotToolActionHeight
                        spacing: tool.theme.space12

                        ScreenshotAction {
                            icon: "󰍹"
                            title: "All"
                            selected: tool.selectedActionIndex === 0
                            onHovered: tool.selectedActionIndex = 0
                            onActivated: tool.capture("all")
                        }

                        ScreenshotAction {
                            icon: "󰹑"
                            title: "Monitor"
                            selected: tool.selectedActionIndex === 1
                            onHovered: tool.selectedActionIndex = 1
                            onActivated: tool.capture("monitor")
                        }

                        ScreenshotAction {
                            icon: "󰖲"
                            title: "Window"
                            selected: tool.selectedActionIndex === 2
                            onHovered: tool.selectedActionIndex = 2
                            onActivated: tool.capture("window")
                        }

                        ScreenshotAction {
                            icon: "󰆞"
                            title: "Area"
                            selected: tool.selectedActionIndex === 3
                            onHovered: tool.selectedActionIndex = 3
                            onActivated: tool.capture("area")
                        }

                    }

                }

            }

        }

    }

}
