import "../theme"
import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Widgets

Item {
    id: card

    readonly property var
    icons: Icons {
    }

    readonly property var
    theme: AppTheme {
    }

    required property var colors
    property var notificationData: null
    property string timeText: "now"
    property int cornerRadius: theme.shape.notificationCardRadius
    property bool expanded: false
    property bool collapsedTextMode: true
    property bool useRenderedHeightForLayout: false
    property bool inlineHeightAnimating: false
    property bool inlineGeometryReady: false
    readonly property bool cardHovered: cardHoverHandler.hovered
    property real renderedLayoutHeight: layoutHeight
    property real allocatedLayoutHeight: layoutHeight
    readonly property string textFont: theme.typography.textFontFamily
    readonly property string iconFont: theme.typography.iconFontFamily
    readonly property int spacing: theme.spacing.notificationCardSpacing
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
    readonly property int collapsedBodyLines: 2
    readonly property real bodyLineHeight: 1.35
    readonly property int resizeAnimationMs: 220
    readonly property int allocationFinalizeDelayMs: 32
    readonly property real geometryEpsilon: 0.5
    readonly property real contentInset: cardPadding + cardRect.border.width
    readonly property int actionCount: countInvokableActions()
    readonly property bool hasActions: actionCount > 0
    readonly property real headerHeight: Math.ceil(labelFontSize * bodyLineHeight)
    readonly property real titleHeight: Math.ceil(titleFontSize * bodyLineHeight)
    readonly property string bodyHtml: notificationData ? (notificationData.htmlBody || notificationData.body || "") : ""
    readonly property real visibleBodyHeight: expanded ? bodyTargetHeight(true) : bodyTargetHeight(false)
    readonly property real contentLayoutHeight: headerHeight + spacing + titleHeight + (visibleBodyHeight > 0 ? spacing + visibleBodyHeight : 0) + (hasActions ? spacing + actionButtonHeight : 0)
    readonly property real layoutHeight: notificationData ? Math.ceil(contentInset * 2 + Math.max(iconSlotSize, contentLayoutHeight)) : 0
    readonly property real viewportHeight: Math.max(0, renderedLayoutHeight - contentInset * 2)
    readonly property real bodyViewportHeight: {
        if (bodyHtml.length === 0)
            return 0;

        const actionSpace = hasActions ? spacing + actionButtonHeight : 0;
        return Math.max(0, viewportHeight - headerHeight - spacing - titleHeight - spacing - actionSpace);
    }
    readonly property color urgencyTimeColor: {
        if (!notificationData)
            return card.colors.textSubtle;

        switch (notificationData.urgency) {
        case NotificationUrgency.Critical:
            return card.colors.critical;
        case NotificationUrgency.Normal:
            return card.colors.info;
        default:
            return card.colors.textSubtle;
        }
    }
    readonly property string iconSource: {
        if (!notificationData)
            return "";

        const image = notificationData.image || "";
        if (image.length > 0)
            return image;

        const appIcon = notificationData.appIcon || notificationData.desktopEntry || "";
        if (appIcon.length === 0)
            return "";

        if (appIcon.startsWith("file://") || appIcon.startsWith("http://") || appIcon.startsWith("https://"))
            return appIcon;

        if (appIcon.startsWith("/"))
            return `file://${appIcon}`;

        if (appIcon.includes("/"))
            return appIcon;

        return `image://icon/${appIcon}`;
    }
    readonly property bool iconSourceIsImageFile: iconSource.startsWith("file://") || iconSource.startsWith("http://") || iconSource.startsWith("https://")

    signal layoutChanged()
    signal slotHeightChanged()
    signal closeRequested()
    signal actionInvoked(var action)
    signal hoverStarted()
    signal hoverEnded()

    function toggleExpanded() {
        const nextExpanded = !expanded;
        expanded = nextExpanded;
        if (nextExpanded)
            collapsedTextMode = false;

    }

    function countInvokableActions() {
        const actions = notificationData && notificationData.actions ? notificationData.actions : [];
        let count = 0;
        for (let i = 0; i < actions.length; i++) {
            const action = actions[i];
            if (action && action.invoke)
                count++;

        }
        return count;
    }

    function invokableActionAt(invokableIndex) {
        const actions = notificationData && notificationData.actions ? notificationData.actions : [];
        let current = 0;
        for (let i = 0; i < actions.length; i++) {
            const action = actions[i];
            if (!action || !action.invoke)
                continue;

            if (current === invokableIndex)
                return action;

            current++;
        }
        return null;
    }

    function bodyTargetHeight(forExpanded) {
        if (bodyHtml.length === 0)
            return 0;

        if (forExpanded)
            return bodyMeasure.implicitHeight;

        return Math.min(bodyMeasure.implicitHeight, bodyText.font.pixelSize * bodyLineHeight * collapsedBodyLines);
    }

    function syncLayoutHeight() {
        const target = Math.max(0, Number(layoutHeight));
        if (isNaN(target))
            return ;

        if (!inlineGeometryReady) {
            renderedHeightAnimation.stop();
            renderedLayoutHeight = target;
            allocatedLayoutHeight = target;
            return ;
        }
        const currentRendered = Math.max(0, Number(renderedLayoutHeight));
        const nextAllocation = Math.max(target, currentRendered, allocatedLayoutHeight);
        const allocationChanged = Math.abs(nextAllocation - allocatedLayoutHeight) >= geometryEpsilon;
        if (allocationChanged) {
            allocatedLayoutHeight = nextAllocation;
            slotHeightChanged();
        }
        if (Math.abs(target - renderedLayoutHeight) < geometryEpsilon) {
            finishLayoutHeightAnimation();
            return ;
        }
        renderedLayoutHeight = target;
        allocationFinalizeTimer.restart();
    }

    function finishLayoutHeightAnimation() {
        const target = Math.max(0, Number(layoutHeight));
        if (isNaN(target))
            return ;

        if (Math.abs(renderedLayoutHeight - target) >= geometryEpsilon)
            renderedLayoutHeight = target;

        allocatedLayoutHeight = target;
        collapsedTextMode = !expanded;
        slotHeightChanged();
    }

    implicitWidth: width
    implicitHeight: useRenderedHeightForLayout ? renderedLayoutHeight : allocatedLayoutHeight
    height: implicitHeight
    visible: notificationData !== null
    onNotificationDataChanged: {
        expanded = false;
        collapsedTextMode = true;
        renderedHeightAnimation.stop();
        Qt.callLater(() => {
            renderedLayoutHeight = layoutHeight;
            allocatedLayoutHeight = layoutHeight;
            inlineGeometryReady = true;
            layoutChanged();
        });
    }
    onLayoutHeightChanged: syncLayoutHeight()
    onRenderedLayoutHeightChanged: {
        if (inlineHeightAnimating)
            slotHeightChanged();

    }
    Component.onCompleted: {
        renderedHeightAnimation.stop();
        renderedLayoutHeight = layoutHeight;
        allocatedLayoutHeight = layoutHeight;
        inlineGeometryReady = true;
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
        color: card.colors.background
        border.color: card.colors.borderStrong
        border.width: card.borderWidth
        clip: true

        HoverHandler {
            id: cardHoverHandler

            onHoveredChanged: {
                if (hovered)
                    card.hoverStarted();
                else
                    card.hoverEnded();
            }
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
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: card.iconSize
                        height: card.iconSize
                        source: card.iconSource
                        visible: card.iconSource.length > 0 && card.iconSourceIsImageFile
                        asynchronous: true
                        cache: true
                        sourceSize: Qt.size(card.iconSize, card.iconSize)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    IconImage {
                        anchors.centerIn: parent
                        width: card.iconSize
                        height: card.iconSize
                        implicitSize: card.iconSize
                        source: card.iconSource
                        visible: card.iconSource.length > 0 && !card.iconSourceIsImageFile
                    }

                    Text {
                        anchors.centerIn: parent
                        width: card.iconSize
                        height: card.iconSize
                        text: card.icons.notificationsEmpty
                        color: card.colors.notification
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
                            width: Math.min(implicitWidth, parent.width - timeSeparator.implicitWidth - timeLabel.implicitWidth - parent.spacing * 2)
                            text: card.notificationData ? (card.notificationData.appName || "App") : "App"
                            color: card.colors.textSubtle
                            font.family: card.textFont
                            font.pixelSize: card.labelFontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            id: timeSeparator

                            text: timeLabel.text.length > 0 ? "•" : ""
                            color: card.colors.textSubtle
                            font.family: card.textFont
                            font.pixelSize: card.labelFontSize
                        }

                        Text {
                            id: timeLabel

                            text: card.timeText
                            color: card.urgencyTimeColor
                            font.family: card.textFont
                            font.pixelSize: card.labelFontSize
                            elide: Text.ElideRight
                        }

                    }

                    Text {
                        width: parent.width
                        text: card.notificationData ? (card.notificationData.summary || "Notification") : "Notification"
                        color: card.colors.primary
                        font.family: card.textFont
                        font.pixelSize: card.titleFontSize
                        font.styleName: card.theme.typography.styleSemibold
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
                            color: card.colors.textMuted
                            linkColor: card.colors.link
                            font.family: card.textFont
                            font.pixelSize: card.bodyFontSize
                            wrapMode: Text.WordWrap
                            maximumLineCount: card.collapsedTextMode ? card.collapsedBodyLines : -1
                            elide: card.collapsedTextMode ? Text.ElideRight : Text.ElideNone
                            onLinkActivated: (link) => {
                                return Qt.openUrlExternally(link);
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

                        MouseArea {
                            anchors.fill: parent
                            enabled: bodyText.hoveredLink.length === 0 && (bodyContainer.canExpand || card.expanded)
                            cursorShape: Qt.ArrowCursor
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
                            model: card.actionCount

                            Rectangle {
                                required property int index
                                readonly property var action: card.invokableActionAt(index)

                                width: Math.max(actionText.implicitWidth + card.actionButtonHorizontalPadding, card.actionButtonMinWidth)
                                height: card.actionButtonHeight
                                radius: card.actionButtonRadius
                                color: card.colors.surfaceInverse
                                border.width: 0

                                Text {
                                    id: actionText

                                    anchors.centerIn: parent
                                    text: parent.action ? (parent.action.text || "Open") : "Open"
                                    color: actionMouse.containsMouse ? card.colors.link : card.colors.textMuted
                                    font.family: card.textFont
                                    font.pixelSize: card.theme.typography.sizeSm
                                    font.styleName: card.theme.typography.styleMedium
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: actionMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: card.actionInvoked(parent.action)
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
                        radius: card.theme.shape.notificationCardCloseButtonRadius
                        color: closeMouse.containsMouse ? card.colors.surfaceHover : card.colors.transparent

                        Text {
                            anchors.fill: parent
                            text: card.icons.close
                            color: card.colors.textSubtle
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

    Behavior on renderedLayoutHeight {
        NumberAnimation {
            id: renderedHeightAnimation

            duration: card.resizeAnimationMs
            easing.type: Easing.Linear
            onRunningChanged: card.inlineHeightAnimating = running
            onFinished: {
                allocationFinalizeTimer.stop();
                card.finishLayoutHeightAnimation();
            }
        }

    }

}
