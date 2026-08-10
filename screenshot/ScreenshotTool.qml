import "../shared/components" as Shared
import "../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland
import "ScreenshotCommand.js" as ScreenshotCommand

Scope {
    id: tool

    // Set by OverlayLifecycleLoader just before this maps, so the
    // overlay opens on the monitor the user is actually working on.
    property var targetScreen: null

    readonly property var theme: AppTheme
    readonly property var icons: Icons
    readonly property var delayOptions: [0, 3, 5, 10, 15]

    property alias visible: panel.visible
    property bool quitOnClose: false
    property bool includeCursor: false
    property int selectedActionIndex: 0
    property int delaySeconds: 0
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
        const monitorName = panel.screen ? panel.screen.name : ""
        const processArgs = ScreenshotCommand.processArguments(mode, includeCursor, monitorName, tool.delaySeconds)
        close()
        Qt.callLater(() => {
            Quickshell.execDetached(processArgs)
        })
    }

    function actionIcon(index) {
        switch (index) {
        case 0:
            return "󰍺"
        case 1:
            return "󰍹"
        case 2:
            return ""
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

    function moveDelaySelection(direction) {
        const currentIndex = Math.max(0, delayOptions.indexOf(delaySeconds))
        const nextIndex = (currentIndex + direction + delayOptions.length) % delayOptions.length
        delaySeconds = delayOptions[nextIndex]
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

            spacing: tool.theme.spacing.screenshotToolSectionSpacing

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

            Item {
                id: timerRow

                width: actionRow.width
                height: content.timerRowHeight

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: tool.theme.spacing.space6

                    Shared.AppText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: Colors.tertiary
                        font.family: tool.theme.typography.iconFontFamily
                        font.pixelSize: tool.theme.sizing.size24
                    }

                    Shared.AppText {
                        id: timerLabel

                        anchors.verticalCenter: parent.verticalCenter
                        text: "Timer"
                        color: Colors.on_surface
                        font.pixelSize: tool.theme.typography.sizeMd
                        font.styleName: tool.theme.typography.styleSemibold
                    }
                }

                Row {
                    id: timerOptions

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: tool.theme.spacing.screenshotToolTimerOptionSpacing

                    Repeater {
                        model: tool.delayOptions

                        ScreenshotTimerOption {
                            required property int modelData

                            value: modelData
                            selected: tool.delaySeconds === modelData
                            onActivated: tool.delaySeconds = modelData
                        }
                    }
                }
            }

            Item {
                id: cursorRow

                width: actionRow.width
                height: content.cursorRowHeight

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: tool.theme.spacing.space6

                    Shared.AppText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: Colors.tertiary
                        font.family: tool.theme.typography.iconFontFamily
                        font.pixelSize: tool.theme.sizing.size24
                    }

                    Shared.AppText {
                        id: cursorLabel

                        anchors.verticalCenter: parent.verticalCenter
                        text: "Cursor"
                        color: Colors.on_surface
                        font.pixelSize: tool.theme.typography.sizeMd
                        font.styleName: tool.theme.typography.styleSemibold
                    }
                }

                Rectangle {
                    id: cursorSwitch

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: tool.theme.sizing.screenshotToolCursorSwitchWidth
                    height: tool.theme.sizing.screenshotToolCursorSwitchHeight
                    radius: height / 2
                    color: tool.includeCursor ? Colors.primary : Colors.surface_variant

                    Rectangle {
                        width: tool.theme.sizing.screenshotToolCursorSwitchKnobSize
                        height: tool.theme.sizing.screenshotToolCursorSwitchKnobSize
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: tool.includeCursor ? parent.width - width
                                                - tool.theme.spacing.screenshotToolCursorSwitchKnobMargin :
                                                tool.theme.spacing.screenshotToolCursorSwitchKnobMargin
                        color: Colors.on_primary

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
        }
    }

    PanelWindow {
        id: panel

        visible: false
        screen: tool.targetScreen
        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        mask: null
        color: "transparent"
        surfaceFormat.opaque: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "qs-screenshot"

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        Rectangle {
            id: overlay

            anchors.fill: parent
            color: Qt.alpha(Colors.shadow, 0.25)
            focus: true
            Keys.onEscapePressed: tool.close()
            Keys.onLeftPressed: tool.moveSelection(-1)
            Keys.onRightPressed: tool.moveSelection(1)
            Keys.onUpPressed: tool.includeCursor = !tool.includeCursor
            Keys.onDownPressed: tool.includeCursor = !tool.includeCursor
            Keys.onTabPressed: tool.moveDelaySelection(1)
            Keys.onBacktabPressed: tool.moveDelaySelection(-1)
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
                width: Math.min(contentLoader.width + tool.theme.spacing.screenshotToolPadding * 2,
                                parent.width - tool.theme.spacing.screenshotToolScreenMargin)
                height: Math.min(contentLoader.height + tool.theme.spacing.screenshotToolPadding * 2,
                                 parent.height - tool.theme.spacing.screenshotToolScreenMargin)
                radius: tool.theme.shape.screenshotToolRadius
                color: Colors.shadow

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Loader {
                    id: contentLoader

                    anchors.centerIn: parent
                    active: panel.visible
                    sourceComponent: screenshotContent
                }
            }
        }
    }
}
