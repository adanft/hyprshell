import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Widgets

Item {
    id: card

    required property var palette
    property var notificationData: null
    property string timeText: "now"
    property int cornerRadius: 16
    property bool expanded: false
    property bool collapsedTextMode: true
    property bool inlineHeightAnimating: false
    property bool inlineGeometryReady: false
    property real renderedLayoutHeight: layoutHeight
    property real allocatedLayoutHeight: layoutHeight
    signal layoutChanged()
    signal slotHeightChanged()
    signal closeRequested()
    signal actionInvoked(var action)

    readonly property string textFont: "SF Pro Display"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int spacing: 8
    readonly property int cardPadding: 8
    readonly property int borderWidth: 2
    readonly property int iconSlotSize: 32
    readonly property int iconSize: 24
    readonly property int closeButtonSize: 24
    readonly property int actionButtonHeight: 24
    readonly property int actionButtonRadius: 999
    readonly property int actionButtonMinWidth: 68
    readonly property int actionButtonHorizontalPadding: 18
    readonly property int labelFontSize: 12
    readonly property int titleFontSize: 15
    readonly property int bodyFontSize: 13
    readonly property int closeIconFontSize: 14
    readonly property int collapsedBodyLines: 2
    readonly property real bodyLineHeight: 1.35
    readonly property int resizeAnimationMs: 1200
    readonly property real contentInset: cardPadding + cardRect.border.width
    readonly property bool hasActions: notificationData && notificationData.actions && notificationData.actions.length > 0
    readonly property real headerHeight: Math.ceil(labelFontSize * bodyLineHeight)
    readonly property real titleHeight: Math.ceil(titleFontSize * bodyLineHeight)
    readonly property string bodyHtml: notificationData ? (notificationData.htmlBody || notificationData.body || "") : ""
    readonly property real visibleBodyHeight: expanded ? bodyTargetHeight(true) : bodyTargetHeight(false)
    readonly property real contentLayoutHeight: headerHeight + spacing + titleHeight + (visibleBodyHeight > 0 ? spacing + visibleBodyHeight : 0) + (hasActions ? spacing + actionButtonHeight : 0)
    readonly property real layoutHeight: notificationData ? Math.ceil(contentInset * 2 + Math.max(iconSlotSize, contentLayoutHeight)) : 0
    readonly property real viewportHeight: Math.max(0, renderedLayoutHeight - contentInset * 2)
    readonly property real bodyViewportHeight: {
        if (bodyHtml.length === 0)
            return 0

        const actionSpace = hasActions ? spacing + actionButtonHeight : 0
        return Math.max(0, viewportHeight - headerHeight - spacing - titleHeight - spacing - actionSpace)
    }
    readonly property color urgencyBorderColor: {
        if (!notificationData)
            return card.palette.mauve

        switch (notificationData.urgency) {
        case NotificationUrgency.Low:
            return card.palette.overlay1
        case NotificationUrgency.Critical:
            return card.palette.red
        default:
            return card.palette.mauve
        }
    }
    readonly property string iconSource: {
        if (!notificationData)
            return ""

        const image = notificationData.image || ""
        if (image.length > 0)
            return image

        const appIcon = notificationData.appIcon || ""
        if (appIcon.length === 0)
            return ""
        if (appIcon.startsWith("file://") || appIcon.startsWith("http://") || appIcon.startsWith("https://") || appIcon.includes("/"))
            return appIcon
        return `image://icon/${appIcon}`
    }

    implicitWidth: width
    implicitHeight: allocatedLayoutHeight
    height: allocatedLayoutHeight
    visible: notificationData !== null

    onNotificationDataChanged: {
        expanded = false
        collapsedTextMode = true
        renderedHeightAnimation.stop()
        Qt.callLater(() => {
            renderedLayoutHeight = layoutHeight
            allocatedLayoutHeight = layoutHeight
            inlineGeometryReady = true
            layoutChanged()
        })
    }

    onLayoutHeightChanged: syncLayoutHeight()
    onRenderedLayoutHeightChanged: {
        if (inlineHeightAnimating)
            slotHeightChanged()
    }

    Component.onCompleted: {
        renderedHeightAnimation.stop()
        renderedLayoutHeight = layoutHeight
        allocatedLayoutHeight = layoutHeight
        inlineGeometryReady = true
    }

    function toggleExpanded() {
        const nextExpanded = !expanded

        expanded = nextExpanded
        if (nextExpanded)
            collapsedTextMode = false
    }

    function bodyTargetHeight(forExpanded) {
        if (bodyHtml.length === 0)
            return 0

        if (forExpanded)
            return bodyMeasure.implicitHeight

        return Math.min(bodyMeasure.implicitHeight, bodyText.font.pixelSize * bodyLineHeight * collapsedBodyLines)
    }

    function syncLayoutHeight() {
        const target = Math.max(0, Number(layoutHeight))
        if (isNaN(target))
            return

        if (!inlineGeometryReady) {
            renderedHeightAnimation.stop()
            renderedLayoutHeight = target
            allocatedLayoutHeight = target
            return
        }

        const currentRendered = Math.max(0, Number(renderedLayoutHeight))
        const nextAllocation = Math.max(target, currentRendered, allocatedLayoutHeight)
        const allocationChanged = Math.abs(nextAllocation - allocatedLayoutHeight) >= 0.5

        if (allocationChanged) {
            allocatedLayoutHeight = nextAllocation
            slotHeightChanged()
        }

        if (Math.abs(target - renderedLayoutHeight) < 0.5) {
            finishLayoutHeightAnimation()
            return
        }

        renderedLayoutHeight = target
        allocationFinalizeTimer.restart()
    }

    function finishLayoutHeightAnimation() {
        const target = Math.max(0, Number(layoutHeight))
        if (isNaN(target))
            return

        if (Math.abs(renderedLayoutHeight - target) >= 0.5)
            renderedLayoutHeight = target
        allocatedLayoutHeight = target
        collapsedTextMode = !expanded
        slotHeightChanged()
    }

    Behavior on renderedLayoutHeight {
        NumberAnimation {
            id: renderedHeightAnimation
            duration: card.resizeAnimationMs
            easing.type: Easing.Linear
            onRunningChanged: card.inlineHeightAnimating = running
            onFinished: {
                allocationFinalizeTimer.stop()
                card.finishLayoutHeightAnimation()
            }
        }
    }

    Timer {
        id: allocationFinalizeTimer

        interval: card.resizeAnimationMs + 32
        repeat: false
        onTriggered: card.finishLayoutHeightAnimation()
    }

    Rectangle {
        id: cardRect

        width: parent.width
        height: card.renderedLayoutHeight
        radius: card.cornerRadius
        color: card.palette.base
        border.color: card.urgencyBorderColor
        border.width: card.borderWidth
        clip: true

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Item {
            id: contentViewport

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: card.contentInset
            anchors.rightMargin: card.contentInset
            anchors.topMargin: card.contentInset
            height: card.viewportHeight
            clip: true

            Row {
                id: cardContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: card.spacing

                Item {
                    id: iconContainer

                    width: card.iconSlotSize
                    height: card.iconSlotSize
                    anchors.top: parent.top

                    IconImage {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: card.iconSize
                        height: card.iconSize
                        implicitSize: card.iconSize
                        source: card.iconSource
                        visible: card.iconSource.length > 0
                    }
                }

                Column {
                    width: cardContent.width - iconContainer.width - closeButtonSlot.width - cardContent.spacing * 2
                    spacing: card.spacing

                    Row {
                        width: parent.width
                        spacing: card.spacing

                        Text {
                            width: Math.min(implicitWidth, parent.width - timeSeparator.implicitWidth - timeLabel.implicitWidth - parent.spacing * 2)
                            text: card.notificationData ? (card.notificationData.appName || "App") : "App"
                            color: card.palette.overlay1
                            font.family: card.textFont
                            font.pixelSize: card.labelFontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            id: timeSeparator

                            text: timeLabel.text.length > 0 ? "•" : ""
                            color: card.palette.overlay1
                            font.family: card.textFont
                            font.pixelSize: card.labelFontSize
                        }

                        Text {
                            id: timeLabel

                            text: card.timeText
                            color: card.palette.overlay1
                            font.family: card.textFont
                            font.pixelSize: card.labelFontSize
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        width: parent.width
                        text: card.notificationData ? (card.notificationData.summary || "Notification") : "Notification"
                        color: card.palette.text
                        font.family: card.textFont
                        font.pixelSize: card.titleFontSize
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Item {
                        id: bodyContainer

                        readonly property real collapsedHeight: bodyText.font.pixelSize * card.bodyLineHeight * card.collapsedBodyLines
                        readonly property bool canExpand: bodyMeasure.implicitHeight > collapsedHeight + 1
                        width: parent.width
                        height: card.bodyViewportHeight
                        visible: height > 0
                        clip: true

                        Text {
                            id: bodyText

                            width: parent.width
                            text: card.bodyHtml
                            textFormat: Text.StyledText
                            color: card.palette.subtext1
                            linkColor: card.palette.blue
                            font.family: card.textFont
                            font.pixelSize: card.bodyFontSize
                            wrapMode: Text.WordWrap
                            maximumLineCount: card.collapsedTextMode ? card.collapsedBodyLines : -1
                            elide: card.collapsedTextMode ? Text.ElideRight : Text.ElideNone
                            onLinkActivated: link => Qt.openUrlExternally(link)

                            HoverHandler {
                                cursorShape: bodyText.hoveredLink.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }

                        Text {
                            id: bodyMeasure

                            visible: false
                            width: parent.width
                            text: bodyText.text
                            textFormat: Text.StyledText
                            font.family: card.textFont
                            font.pixelSize: card.bodyFontSize
                            wrapMode: Text.WordWrap
                            maximumLineCount: -1
                            elide: Text.ElideNone
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: bodyText.hoveredLink.length === 0 && (bodyContainer.canExpand || card.expanded)
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            propagateComposedEvents: true
                            z: -1
                            onClicked: card.toggleExpanded()
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: card.spacing
                        visible: card.hasActions

                        Repeater {
                            model: card.notificationData ? (card.notificationData.actions || []) : []

                            Rectangle {
                                required property var modelData

                                width: Math.max(actionText.implicitWidth + card.actionButtonHorizontalPadding, card.actionButtonMinWidth)
                                height: card.actionButtonHeight
                                radius: card.actionButtonRadius
                                color: "#11111b"
                                border.width: 0

                                Text {
                                    id: actionText

                                    anchors.centerIn: parent
                                    text: modelData.text || "Open"
                                    color: actionMouse.containsMouse ? card.palette.blue : card.palette.subtext1
                                    font.family: card.textFont
                                    font.pixelSize: card.labelFontSize
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: actionMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: card.actionInvoked(modelData)
                                }
                            }
                        }
                    }
                }

                Item {
                    id: closeButtonSlot

                    width: card.iconSlotSize
                    height: card.iconSlotSize
                    anchors.top: parent.top

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        width: card.closeButtonSize
                        height: card.closeButtonSize
                        radius: 999
                        color: closeMouse.containsMouse ? card.palette.surface1 : "transparent"

                        Text {
                            anchors.fill: parent
                            text: "󰅖"
                            color: card.urgencyBorderColor
                            font.family: card.iconFont
                            font.pixelSize: card.closeIconFontSize
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            id: closeMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.closeRequested()
                        }
                    }
                }
            }
        }
    }
}
