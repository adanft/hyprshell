import "../theme"
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

Item {
    id: card

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var notificationService
    property var notificationData: null
    property bool allowLiveImage: false
    property bool isHistoryEntry: false
    property string timeText: "now"
    property int cornerRadius: theme.shape.notificationCardRadius
    property bool initialExpanded: false
    property bool expanded: false
    property bool collapsedTextMode: true
    property bool useRenderedHeightForLayout: false
    property bool inlineHeightAnimating: false
    property bool inlineGeometryReady: false
    readonly property bool cardHovered: cardHoverHandler.hovered || closeMouse.containsMouse || expandMouse.containsMouse
    property real renderedLayoutHeight: layoutHeight
    property real allocatedLayoutHeight: layoutHeight
    readonly property string textFont: theme.typography.textFontFamily
    readonly property string iconFont: theme.typography.iconFontFamily
    readonly property int spacing: theme.spacing.notificationCardSpacing
    readonly property int actionSpacing: theme.spacing.notificationCardActionSpacing
    readonly property int cardPadding: theme.spacing.notificationCardPadding
    readonly property int borderWidth: theme.shape.notificationCardBorderWidth
    readonly property int iconSlotSize: theme.sizing.notificationCardIconSlotSize
    readonly property int iconSize: theme.sizing.notificationCardIconSize
    readonly property int closeButtonSize: theme.sizing.notificationCardCloseButtonSize
    readonly property int actionButtonHeight: theme.sizing.notificationCardActionButtonHeight
    readonly property int actionButtonRadius: theme.shape.notificationCardActionButtonRadius
    readonly property int actionButtonMinWidth: theme.sizing.notificationCardActionButtonMinWidth
    readonly property int actionButtonHorizontalPadding: theme.spacing.notificationCardActionButtonHorizontalPadding
    readonly property int labelFontSize: theme.typography.sizeSm
    readonly property int titleFontSize: theme.typography.sizeLg
    readonly property int bodyFontSize: theme.typography.sizeMd
    readonly property int closeIconFontSize: theme.typography.sizeMd
    readonly property int collapsedBodyLines: theme.sizing.notificationCardCollapsedBodyLines
    readonly property real bodyLineHeight: theme.typography.notificationBodyLineHeight
    readonly property int resizeAnimationMs: theme.motion.durationNormal
    readonly property int allocationFinalizeDelayMs: theme.motion.layoutFinalizeDelay
    readonly property real geometryEpsilon: 0.5
    readonly property real contentInset: cardPadding + cardRect.border.width
    readonly property real contentInsetLeft: cardPadding + urgencyBarWidth
    readonly property real contentInsetRight: cardPadding
    readonly property int actionCount: countInvokableActions()
    readonly property bool hasActions: actionCount > 0
    readonly property var defaultAction: findDefaultAction()
    readonly property bool hasDefaultAction: defaultAction !== null
    readonly property real headerHeight: Math.ceil(labelFontSize * bodyLineHeight)
    readonly property real titleHeight: Math.ceil(titleFontSize * bodyLineHeight)
    readonly property string bodyHtml: notificationData ? (notificationData.htmlBody || notificationData.body || "") :
                                                          ""

    readonly property real visibleBodyHeight: expanded ? bodyTargetHeight(true) : bodyTargetHeight(false)
    readonly property real contentLayoutHeight: headerHeight + spacing + titleHeight + (visibleBodyHeight > 0 ? spacing
                                                                                                                + visibleBodyHeight :
                                                                                                                0) + (hasActions
                                                                                                                      ? spacing
                                                                                                                        + actionButtonHeight :
                                                                                                                        0)
    readonly property real layoutHeight: notificationData ? Math.ceil(contentInset * 2 + Math.max(iconSlotSize,
                                                                                                  contentLayoutHeight)) :
                                                            0
    readonly property real viewportHeight: Math.max(0, renderedLayoutHeight - contentInset * 2)
    readonly property real bodyViewportHeight: {
        if (bodyHtml.length === 0)
            return 0

        const actionSpace = hasActions ? spacing + actionButtonHeight : 0
        return Math.max(0, viewportHeight - headerHeight - spacing - titleHeight - spacing - actionSpace)
    }
    readonly property int urgencyBarWidth: theme.spacing.notificationCardUrgencyBarWidth
    readonly property color urgencyBarColor: {
        if (!notificationData)
            return Colors.tertiary

        switch (notificationData.urgency) {
        case NotificationUrgency.Critical:
            return Colors.error
        case NotificationUrgency.Low:
            return Colors.on_surface
        default:
            return Colors.tertiary
        }
    }
    readonly property string fallbackIconName: "application-x-executable"
    readonly property string fallbackIconSource: {
        if (!notificationData)
            return Quickshell.iconPath(fallbackIconName)

        const appIcon = notificationData.appIcon || notificationData.desktopEntry || ""
        if (appIcon.length === 0)
            return Quickshell.iconPath(fallbackIconName)

        if (appIcon.startsWith("file://") || appIcon.startsWith("http://") || appIcon.startsWith("https://"))
            return appIcon

        if (appIcon.startsWith("/"))
            return `file://${appIcon}`

        if (appIcon.includes("/"))
            return appIcon

        return Quickshell.iconPath(appIcon, fallbackIconName)
    }
    readonly property string iconSource: {
        const image = notificationData?.image || ""
        if (image.startsWith("image://qsimage/") && !allowLiveImage)
            return fallbackIconSource
        return image || fallbackIconSource
    }
    readonly property bool iconSourceIsImageFile: iconSource.startsWith("file://") || iconSource.startsWith("http://")
                                                  || iconSource.startsWith("https://") || iconSource.startsWith(
                                                      "image://")
    property string failedImageSource: ""
    readonly property bool iconSourceQuarantined: (notificationService
                                                    && typeof notificationService.isInvalidLiveImageSource
                                                    === "function" && notificationService.isInvalidLiveImageSource(
                                                        iconSource)) || (notificationService
                                                                        && typeof notificationService.isInvalidOwnedImageSource
                                                                        === "function" && notificationService.isInvalidOwnedImageSource(
                                                                            iconSource)) || (failedImageSource.length > 0 && iconSource
                                                                         === failedImageSource)

    signal layoutChanged
    signal slotHeightChanged
    signal closeRequested
    signal actionInvoked(var action)
    signal hoverStarted
    signal hoverEnded

    function toggleExpanded() {
        const nextExpanded = !expanded
        expanded = nextExpanded
        if (nextExpanded)
            collapsedTextMode = false
    }

    function findDefaultAction() {
        const actions = notificationData && notificationData.actions ? notificationData.actions : []
        for (let i = 0; i < actions.length; i++) {
            const action = actions[i]
            if (action && action.invoke && action.identifier === "default")
                return action
        }
        return null
    }

    function countInvokableActions() {
        const actions = notificationData && notificationData.actions ? notificationData.actions : []
        let count = 0
        for (let i = 0; i < actions.length; i++) {
            const action = actions[i]
            if (action && action.invoke && action.identifier !== "default")
                count++
        }
        return count
    }

    function invokableActionAt(invokableIndex) {
        const actions = notificationData && notificationData.actions ? notificationData.actions : []
        let current = 0
        for (let i = 0; i < actions.length; i++) {
            const action = actions[i]
            if (!action || !action.invoke || action.identifier === "default")
                continue
            if (current === invokableIndex)
                return action

            current++
        }
        return null
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
        const allocationChanged = Math.abs(nextAllocation - allocatedLayoutHeight) >= geometryEpsilon
        if (allocationChanged) {
            allocatedLayoutHeight = nextAllocation
            slotHeightChanged()
        }
        if (Math.abs(target - renderedLayoutHeight) < geometryEpsilon) {
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
        if (Math.abs(renderedLayoutHeight - target) >= geometryEpsilon)
            renderedLayoutHeight = target

        allocatedLayoutHeight = target
        collapsedTextMode = !expanded
        slotHeightChanged()
    }

    implicitWidth: width
    implicitHeight: useRenderedHeightForLayout ? renderedLayoutHeight : allocatedLayoutHeight
    height: implicitHeight
    visible: notificationData !== null
    onNotificationDataChanged: {
        expanded = initialExpanded
        collapsedTextMode = true
        renderedHeightAnimation.stop()
        Qt.callLater(() => {
            try {
                renderedLayoutHeight = layoutHeight
                allocatedLayoutHeight = layoutHeight
                inlineGeometryReady = true
                layoutChanged()
            } catch (error) {
                // card was destroyed before this deferred call ran
            }
        })
    }
    onIconSourceChanged: {
        if (failedImageSource.length > 0 && iconSource !== failedImageSource)
            failedImageSource = ""
    }
    onLayoutHeightChanged: syncLayoutHeight()
    onCardHoveredChanged: {
        if (cardHovered)
            hoverStarted()
        else
            hoverEnded()
    }
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

    Timer {
        id: allocationFinalizeTimer

        interval: card.resizeAnimationMs + card.allocationFinalizeDelayMs
        repeat: false
        onTriggered: card.finishLayoutHeightAnimation()
    }

    Rectangle {
        id: cardRect

        width: parent.width
        height: card.renderedLayoutHeight
        radius: card.cornerRadius
        // A card floating over the desktop is the deepest thing on screen, so it
        // sits on shadow. Inside the centre it is the opposite: the panel is the
        // deep surface and each card has to lift off it.
        color: card.isHistoryEntry ? Colors.surface : Colors.shadow
        border.color: Colors.outline
        border.width: card.borderWidth
        clip: true
        layer.enabled: true
        layer.smooth: true

        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: cardRectMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: card.urgencyBarWidth
            color: card.cardHovered ? Colors.hover : card.urgencyBarColor
        }

        HoverHandler {
            id: cardHoverHandler

            cursorShape: Qt.ArrowCursor
        }

        MouseArea {
            id: defaultActionMouse

            anchors.fill: parent
            enabled: card.hasDefaultAction
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Button
            Accessible.name: card.notificationData ? `Open ${card.notificationData.summary || "notification"}` : "Open notification"
            cursorShape: Qt.ArrowCursor
            z: -1
            onClicked: card.actionInvoked(card.defaultAction)
            Keys.onReturnPressed: card.actionInvoked(card.defaultAction)
            Keys.onEnterPressed: card.actionInvoked(card.defaultAction)
            Keys.onSpacePressed: card.actionInvoked(card.defaultAction)
        }

        Item {
            id: contentViewport

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: card.contentInsetLeft
            anchors.rightMargin: card.contentInsetRight
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
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: notificationImage

                        anchors.centerIn: parent
                        width: card.iconSize
                        height: card.iconSize
                        source: card.iconSourceQuarantined ? "" : card.iconSource
                        visible: card.iconSource.length > 0 && card.iconSourceIsImageFile &&
                                 !card.iconSourceQuarantined && status !== Image.Error
                        asynchronous: !card.iconSource.startsWith("image://qsimage/")
                        cache: true
                        readonly property size oversampledSourceSize: Qt.size(card.iconSize * 2, card.iconSize * 2)
                        sourceSize: card.iconSource.startsWith(
                                        "image://qsimage/") ? Qt.size(0, 0) : oversampledSourceSize
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        onStatusChanged: {
                            const failedSource = source.toString()
                            if (status === Image.Error && failedSource.length > 0) {
                                card.failedImageSource = failedSource
                                if (card.allowLiveImage && failedSource.startsWith("image://qsimage/")
                                        && card.notificationService
                                        && typeof card.notificationService.quarantineInvalidLiveImageSource
                                        === "function")
                                    card.notificationService.quarantineInvalidLiveImageSource(failedSource)
                                else if (failedSource.startsWith("file://") && card.notificationService
                                         && typeof card.notificationService.invalidateOwnedNotificationImage
                                         === "function")
                                    card.notificationService.invalidateOwnedNotificationImage(failedSource)
                            }
                        }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        width: card.iconSize
                        height: card.iconSize
                        implicitSize: card.iconSize
                        source: card.iconSourceIsImageFile ? card.fallbackIconSource : card.iconSource
                        visible: card.fallbackIconSource.length > 0 && (!card.iconSourceIsImageFile
                                                                        || card.iconSourceQuarantined
                                                                        || notificationImage.status === Image.Error)
                    }

                    Text {
                        anchors.centerIn: parent
                        width: card.iconSize
                        height: card.iconSize
                        text: card.icons.notificationsEmpty
                        color: Colors.on_surface
                        font.family: card.iconFont
                        font.pixelSize: card.iconSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        visible: card.iconSource.length === 0
                    }
                }

                Column {
                    width: cardContent.width - iconContainer.width - closeButtonSlot.width - cardContent.spacing * 2
                    spacing: card.spacing

                    Row {
                        width: parent.width
                        spacing: card.spacing

                        Text {
                            width: Math.min(implicitWidth, parent.width - timeSeparator.implicitWidth
                                            - timeLabel.implicitWidth - parent.spacing * 2)
                            text: card.notificationData ? (card.notificationData.appName || "App") : "App"
                            color: Colors.on_surface_variant
                            font.family: card.textFont
                            font.pixelSize: card.labelFontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            id: timeSeparator

                            text: timeLabel.text.length > 0 ? card.icons.textSeparatorBullet : ""
                            color: Colors.on_surface_variant
                            font.family: card.textFont
                            font.pixelSize: card.labelFontSize
                        }

                        Text {
                            id: timeLabel

                            text: card.timeText
                            color: Colors.tertiary
                            font.family: card.textFont
                            font.pixelSize: card.labelFontSize
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        width: parent.width
                        text: card.notificationData ? (card.notificationData.summary || "Notification") : "Notification"
                        color: Colors.primary
                        font.family: card.textFont
                        font.pixelSize: card.titleFontSize
                        font.styleName: card.theme.typography.styleSemibold
                        elide: Text.ElideRight
                    }

                    Item {
                        id: bodyContainer

                        readonly property real collapsedHeight: bodyText.font.pixelSize * card.bodyLineHeight
                                                                * card.collapsedBodyLines
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
                            color: Colors.on_surface
                            linkColor: Colors.tertiary
                            font.family: card.textFont
                            font.pixelSize: card.bodyFontSize
                            wrapMode: Text.WordWrap
                            maximumLineCount: card.collapsedTextMode ? card.collapsedBodyLines : -1
                            elide: card.collapsedTextMode ? Text.ElideRight : Text.ElideNone
                            onLinkActivated: link => {
                                return Qt.openUrlExternally(link)
                            }

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
                    }

                    Row {
                        width: parent.width
                        spacing: card.actionSpacing
                        visible: card.hasActions

                        Repeater {
                            model: card.actionCount

                            Rectangle {
                                required property int index
                                readonly property var action: card.invokableActionAt(index)

                                width: Math.max(actionText.implicitWidth + card.actionButtonHorizontalPadding,
                                                card.actionButtonMinWidth)
                                height: card.actionButtonHeight
                                radius: card.actionButtonRadius
                                color: actionMouse.containsMouse || actionMouse.activeFocus ? Colors.hover : Colors.surface
                                border.width: 0

                                Text {
                                    id: actionText

                                    anchors.centerIn: parent
                                    text: parent.action ? (parent.action.text || "Open") : "Open"
                                    color: actionMouse.containsMouse ? Colors.on_hover : Colors.on_surface_variant
                                    font.family: card.textFont
                                    font.pixelSize: card.theme.typography.sizeSm
                                    font.styleName: card.theme.typography.styleMedium
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: actionMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.Button
                                    Accessible.name: parent.action ? (parent.action.text || "Open") : "Open"
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: card.actionInvoked(parent.action)
                                    Keys.onReturnPressed: card.actionInvoked(parent.action)
                                    Keys.onEnterPressed: card.actionInvoked(parent.action)
                                    Keys.onSpacePressed: card.actionInvoked(parent.action)
                                }
                            }
                        }
                    }
                }

                Item {
                    id: closeButtonSlot

                    width: card.closeButtonSize
                    height: card.iconSlotSize
                    anchors.top: parent.top

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        width: card.closeButtonSize
                        height: card.closeButtonSize
                        radius: card.theme.shape.notificationCardCloseButtonRadius
                        color: closeMouse.containsMouse || closeMouse.activeFocus ? Colors.hover : Colors.surface_variant

                        Text {
                            anchors.fill: parent
                            text: card.isHistoryEntry ? card.icons.trash : card.icons.close
                            color: closeMouse.containsMouse ? Colors.on_hover : Colors.on_surface_variant
                            font.family: card.iconFont
                            font.pixelSize: card.closeIconFontSize
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            id: closeMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: card.isHistoryEntry ? "Delete notification" : "Dismiss notification"
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.closeRequested()
                            Keys.onReturnPressed: card.closeRequested()
                            Keys.onEnterPressed: card.closeRequested()
                            Keys.onSpacePressed: card.closeRequested()
                        }
                    }
                }
            }
        }

        Item {
            id: expandToggleSlot

            width: card.closeButtonSize
            height: card.closeButtonSize
            x: parent.width - card.contentInsetRight - card.closeButtonSize
               - card.theme.spacing.notificationCardExpandToggleGap - card.closeButtonSize
            y: card.contentInset
            visible: bodyContainer.canExpand || card.expanded

            Rectangle {
                anchors.fill: parent
                radius: card.theme.shape.notificationCardCloseButtonRadius
                color: expandMouse.containsMouse || expandMouse.activeFocus ? Colors.hover : Colors.surface_variant

                Text {
                    anchors.fill: parent
                    text: card.expanded ? card.icons.chevronUp : card.icons.chevronDown
                    color: expandMouse.containsMouse ? Colors.on_hover : Colors.on_surface_variant
                    font.family: card.iconFont
                    font.pixelSize: card.closeIconFontSize
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    id: expandMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: card.expanded ? "Collapse notification" : "Expand notification"
                    Accessible.pressed: card.expanded
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.toggleExpanded()
                    Keys.onReturnPressed: card.toggleExpanded()
                    Keys.onEnterPressed: card.toggleExpanded()
                    Keys.onSpacePressed: card.toggleExpanded()
                }
            }
        }
    }

    Rectangle {
        id: cardRectMask

        anchors.fill: cardRect
        radius: card.cornerRadius
        // An OpacityMask stencil: only its alpha is read, so this is not a
        // palette decision and does not belong to any role.
        color: "black"
        visible: false
        layer.enabled: true
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
}
