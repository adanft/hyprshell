import "../shared/components" as Shared
import "../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: tool

    readonly property var theme: AppTheme

    property alias visible: panel.visible
    property bool quitOnClose: false
    property bool includeCursor: false
    property int selectedActionIndex: 0
    property int delaySeconds: 0
    readonly property string captureSuccessCommand:
        "wl-copy --type image/png < \"$file\" && notify-send -u low -i image-png \"Screenshot captured\" \"$(basename \"$file\")\\nCopied to clipboard\""

    function open() {
        selectedActionIndex = 0
        delaySeconds = 0
        panel.visible = true
        Qt.callLater(() => {
            return overlay.forceActiveFocus()
        })
    }

    function close() {
        panel.visible = false
        if (quitOnClose)
            Qt.quit()
    }

    function toggle() {
        panel.visible ? close() : open()
    }

    function capture(mode) {
        const grimCursorArg = includeCursor ? "-c " : ""
        const delay = tool.delaySeconds
        const initialDelay = mode === "area" ? 0.2 : delay + 0.2
        const windowGrimCommand = `grim ${grimCursorArg}-T "$id"`
        const areaGrimCommand = `grim ${grimCursorArg}-g "$geometry"`
        let command = ""
        switch (mode) {
        case "monitor":
            command = captureCommand(`grim ${grimCursorArg}-o "${panel.screen.name}"`)
            break
        case "window":
            command = [`id=$(hyprctl activewindow -j | jq -r 'select(.stableId != null) | .stableId') && if [ -n "$id" ]; then sleep 0.5; `,
                       captureCommand(windowGrimCommand), "; fi"].join("")
            break
        case "area":
            command = [`geometry=$(slurp) && if [ -n "$geometry" ]; then sleep ${delay}; `, captureCommand(
                           areaGrimCommand), "; fi"].join("")
            break
        case "all":
        default:
            command = captureCommand(`grim ${grimCursorArg}`)
            break
        }
        close()
        Qt.callLater(() => {
            Quickshell.execDetached(["sh", "-c", ["mkdir -p \"$HOME/Pictures/Screenshots\" && sleep ", initialDelay,
                                                  " && ", command].join("")])
        })
    }

    function captureCommand(grimCommand) {
        return ["file=\"$HOME/Pictures/Screenshots/screenshot_$(date +%Y-%m-%d-%H-%M-%S).png\"; ", grimCommand,
                " \"$file\" && ", captureSuccessCommand].join("")
    }

    function actionIcon(index) {
        switch (index) {
        case 0:
            return "󰍹"
        case 1:
            return "󰹑"
        case 2:
            return "󰖲"
        case 3:
            return "󰆞"
        default:
            return "󰍹"
        }
    }

    function actionTitle(index) {
        switch (index) {
        case 0:
            return "All"
        case 1:
            return "Monitor"
        case 2:
            return "Window"
        case 3:
            return "Area"
        default:
            return "All"
        }
    }

    function actionMode(index) {
        switch (index) {
        case 0:
            return "all"
        case 1:
            return "monitor"
        case 2:
            return "window"
        case 3:
            return "area"
        default:
            return "all"
        }
    }

    function moveSelection(direction) {
        selectedActionIndex = Math.max(0, Math.min(3, selectedActionIndex + direction))
    }

    function activateSelection() {
        capture(actionMode(selectedActionIndex))
    }

    Component {
        id: screenshotContent

        Column {
            id: content

            readonly property int cursorRowHeight: Math.max(cursorLabel.implicitHeight, cursorSwitch.height)
            readonly property int timerRowHeight: Math.max(timerLabel.implicitHeight, timerOptions.height)
            readonly property int actionRowHeight: tool.theme.sizing.screenshotToolActionHeight
            readonly property int minimumVerticalSpacing: tool.theme.spacing.screenshotToolSectionSpacing

            anchors.fill: parent
            anchors.margins: tool.theme.spacing.screenshotToolPadding
            spacing: Math.max(minimumVerticalSpacing, Math.floor((height - cursorRowHeight - timerRowHeight
                                                                  - actionRowHeight) / 2))

            Item {
                id: cursorRow

                width: parent.width
                height: content.cursorRowHeight

                Shared.AppText {
                    id: cursorLabel

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Cursor"
                    color: tool.theme.colors.text
                    font.pixelSize: tool.theme.typography.sizeMd
                    font.styleName: tool.theme.typography.styleSemibold
                }

                Rectangle {
                    id: cursorSwitch

                    anchors.right: parent.right
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
                        x: tool.includeCursor ? parent.width - width
                                                - tool.theme.spacing.screenshotToolCursorSwitchKnobMargin :
                                                tool.theme.spacing.screenshotToolCursorSwitchKnobMargin
                        color: tool.includeCursor ? tool.theme.colors.primaryText : tool.theme.colors.textMuted

                        Behavior on x {
                            NumberAnimation {
                                duration: tool.theme.motion.durationShort
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

            Item {
                id: timerRow

                width: parent.width
                height: content.timerRowHeight

                Shared.AppText {
                    id: timerLabel

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Timer"
                    color: tool.theme.colors.text
                    font.pixelSize: tool.theme.typography.sizeMd
                    font.styleName: tool.theme.typography.styleSemibold
                }

                Row {
                    id: timerOptions

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: tool.theme.spacing.screenshotToolTimerOptionSpacing

                    Repeater {
                        model: [3, 5, 10, 15]

                        ScreenshotTimerOption {
                            required property int modelData

                            value: modelData
                            selected: tool.delaySeconds === modelData
                            onActivated: tool.delaySeconds = tool.delaySeconds === modelData ? 0 : modelData
                        }
                    }
                }
            }

            Row {
                id: actionRow

                anchors.horizontalCenter: parent.horizontalCenter
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
                width: Math.min(parent.width - tool.theme.spacing.screenshotToolScreenMargin,
                                tool.theme.sizing.appLauncherMaxWidth)
                height: Math.min(parent.height - tool.theme.spacing.screenshotToolScreenMargin,
                                 tool.theme.sizing.appLauncherMaxHeight)
                radius: tool.theme.shape.screenshotToolRadius
                color: tool.theme.colors.background

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
