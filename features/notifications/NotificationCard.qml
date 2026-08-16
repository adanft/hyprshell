import "../../theme"
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
    readonly property int spacing: theme.spacing.space12
    readonly property int actionSpacing: theme.spacing.space6
    readonly property int cardPadding: theme.spacing.space12
    readonly property int borderWidth: theme.shape.notificationCardBorderWidth
    readonly property int iconSlotSize: NotificationSizing.cardIconSlotSize
    readonly property int iconSize: NotificationSizing.cardIconSize
    readonly property int closeButtonSize: NotificationSizing.cardCloseButtonSize
    readonly property int actionButtonHeight: NotificationSizing.cardActionButtonHeight
    readonly property int actionButtonRadius: theme.shape.notificationCardActionButtonRadius
    readonly property int actionButtonMinWidth: NotificationSizing.cardActionButtonMinWidth
    readonly property int actionButtonHorizontalPadding: theme.spacing.space16
    readonly property int labelFontSize: theme.typography.textSm
    readonly property int titleFontSize: theme.typography.textBase
    readonly property int bodyFontSize: theme.typography.textMd
    readonly property int closeIconFontSize: theme.typography.textMd
    readonly property int collapsedBodyLines: NotificationSizing.cardCollapsedBodyLines
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
    // The animated height, held to whole pixels, and everything the card's own
    // geometry is built from reads this rather than the raw value.
    //
    // `cardRect` carries a layer, which rasterises its contents into a texture
    // the size of that item. An animation between two integers passes through
    // fractional values, so without this the texture is a fraction of a pixel
    // different on every frame, the mapping back to the screen shifts with it,
    // and every glyph inside is resampled slightly differently. Measured across
    // heights 160.00 to 161.00 in quarter-pixel steps, comparing a band of text
    // that never moves in layout: 5525 of 36480 pixels changed with the raw
    // value and 0 with this one. The text was never moving — it was being
    // redrawn wrong, which is why it read as trembling rather than sliding.
    //
    // Both halves are needed to produce it: a layer over a fractional size. A
    // fractional POSITION was measured too and does not do this; it costs some
    // sharpness with or without a layer, slightly more without, and it is
    // static rather than churning, so the cards being pushed down the stack are
    // simply in motion and are left alone.
    readonly property real renderedHeightPx: Math.round(renderedLayoutHeight)
    readonly property real viewportHeight: Math.max(0, renderedHeightPx - contentInset * 2)
    readonly property real bodyViewportHeight: {
        if (bodyHtml.length === 0)
            return 0

        const actionSpace = hasActions ? spacing + actionButtonHeight : 0
        return Math.max(0, viewportHeight - headerHeight - spacing - titleHeight - spacing - actionSpace)
    }
    readonly property int urgencyBarWidth: NotificationSizing.cardUrgencyBarWidth
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
    // The same grid the card paints on. Rounding only what is drawn and leaving
    // what is reported upward on the raw value put the two half a pixel apart
    // for the length of an expand, in the centre, which is the one place this
    // branch is taken — the painted card and the slot the list gives it would
    // have disagreed where before the change they could not. Both are the same
    // height of the same thing, so they read the same property.
    implicitHeight: useRenderedHeightForLayout ? renderedHeightPx : allocatedLayoutHeight
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
        // The layered one, so whole pixels. See renderedHeightPx.
        height: card.renderedHeightPx
        radius: card.cornerRadius
        // A card floating over the desktop is the deepest thing on screen, so it
        // sits on shadow. Inside the center it is the opposite: the panel is the
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
                    // Pinned to the top, like the close button across the row
                    // (`closeButtonSlot`) and the chevron below it, which both
                    // already were. Centered, it was the one thing in the header
                    // that moved: this Row takes its height from its tallest
                    // child, that child is the column whose body height is
                    // animated, so the center it was anchored to slid down
                    // through the whole expand and the icon slid with it — half
                    // the growth, which on a long notification is further than
                    // the icon is tall, while everything beside it stayed put.
                    // A search for "Animation" never finds this; it is an anchor.
                    anchors.top: parent.top

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
                        text: card.icons.notification.bellEmpty
                        color: Colors.on_surface
                        font.family: card.iconFont
                        font.pixelSize: card.iconSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        visible: card.iconSource.length === 0
                    }
                }

                Column {
                    // Floored, and this is the one that matters most, because
                    // everything below inherits it. The action row takes its
                    // width from here, and the row's own share is floored too —
                    // so a negative arriving from this line would be absorbed
                    // down there and every action button would collapse to
                    // nothing with no error anywhere. A floor that swallows a
                    // fault upstream is worse than none; this one stops the
                    // fault from being produced.
                    width: Math.max(0, cardContent.width - iconContainer.width - closeButtonSlot.width
                                    - cardContent.spacing * 2)
                    spacing: card.spacing

                    Row {
                        width: parent.width
                        spacing: card.spacing

                        Text {
                            // The same shape as the action label, and floored
                            // for the same reason: the timestamp beside it is
                            // whatever the clock made it, so a long one on a
                            // narrow card takes this below zero.
                            width: Math.max(0, Math.min(implicitWidth, parent.width - timeSeparator.implicitWidth
                                                        - timeLabel.implicitWidth - parent.spacing * 2))
                            text: card.notificationData ? (card.notificationData.appName || "App") : "App"
                            color: Colors.on_surface_variant
                            font.family: card.textFont
                            font.pixelSize: card.labelFontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            id: timeSeparator

                            text: timeLabel.text.length > 0 ? card.icons.ui.bullet : ""
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
                        id: actionsRow

                        width: parent.width
                        spacing: card.actionSpacing
                        visible: card.hasActions

                        // The row is shared out rather than left to each button
                        // to size itself. A label is text the sender chose and
                        // of no length anyone promised — a file name off a
                        // hint, or whatever an application put on its own
                        // action — and a Row does not wrap, inside a card that
                        // clips. Sized from the text alone, one long label
                        // pushes the buttons beside it past the card edge,
                        // where they cannot be read and cannot be pressed.
                        //
                        // Below the minimum width the share wins anyway: a
                        // cramped button that is still there beats a
                        // comfortable one that is not.
                        //
                        // Floored at zero because the share is not bounded
                        // below. The sender decides how many actions arrive, so
                        // enough of them makes the spacing alone eat the row and
                        // turn the subtraction negative — and a negative width
                        // reaches the label as a negative width too, which is
                        // not something a text layout is built to take. The
                        // floor is what keeps the many-button case degrading
                        // into cramped rather than into undefined.
                        readonly property real buttonShare: card.actionCount > 0 ? Math.max(0, (width
                                                                                                - card.actionSpacing
                                                                                                * (card.actionCount - 1))
                                                                                               / card.actionCount) : 0

                        Repeater {
                            model: card.actionCount

                            Rectangle {
                                required property int index
                                readonly property var action: card.invokableActionAt(index)

                                width: Math.min(Math.max(actionText.implicitWidth
                                                         + card.actionButtonHorizontalPadding,
                                                         card.actionButtonMinWidth),
                                                actionsRow.buttonShare)
                                height: card.actionButtonHeight
                                radius: card.actionButtonRadius
                                color: actionMouse.containsMouse || actionMouse.activeFocus ? Colors.hover : Colors.surface
                                border.width: 0

                                Text {
                                    id: actionText

                                    anchors.centerIn: parent
                                    // elide has nothing to elide within until
                                    // the text is given a width. Left at its
                                    // implicit one — which is what it was, and
                                    // what the button above is measured from —
                                    // the property was set and could never
                                    // fire, so a long label grew instead of
                                    // shortening. The button's own width is
                                    // derived from implicitWidth rather than
                                    // from this, so reading it back here does
                                    // not feed itself.
                                    // Floored for the same reason the share
                                    // above is, and review had to point out
                                    // that flooring the share alone only moved
                                    // the problem down here: once enough
                                    // actions squeeze a button narrower than
                                    // its own padding, this subtraction is what
                                    // goes negative instead.
                                    width: Math.max(0, Math.min(implicitWidth,
                                                                parent.width
                                                                - card.actionButtonHorizontalPadding))
                                    // Only the elided case can leave slack:
                                    // elision cuts on a character boundary, so
                                    // what is drawn is a little narrower than
                                    // the width it was given. Unelided the
                                    // width is the text's own and there is
                                    // nothing to align. Review asked whether
                                    // this carries weight — it carries that
                                    // sliver, and centring it matches the
                                    // anchors above rather than falling back to
                                    // the left-aligned default.
                                    horizontalAlignment: Text.AlignHCenter
                                    text: parent.action ? (parent.action.text || "Open") : "Open"
                                    color: actionMouse.containsMouse ? Colors.on_hover : Colors.on_surface_variant
                                    font.family: card.textFont
                                    font.pixelSize: card.theme.typography.textSm
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
                            text: card.isHistoryEntry ? card.icons.ui.trash : card.icons.ui.close
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
            // A position rather than a size, so the floor buys something
            // different: unfloored, a card narrow enough puts this off the left
            // edge of a parent that clips, and the control disappears. At zero
            // it overlaps the content instead, which is ugly and reachable —
            // the better of the two, since nobody can press what is not drawn.
            x: Math.max(0, parent.width - card.contentInsetRight - card.closeButtonSize
                        - card.theme.spacing.space6 - card.closeButtonSize)
            y: card.contentInset
            visible: bodyContainer.canExpand || card.expanded

            Rectangle {
                anchors.fill: parent
                radius: card.theme.shape.notificationCardCloseButtonRadius
                color: expandMouse.containsMouse || expandMouse.activeFocus ? Colors.hover : Colors.surface_variant

                Text {
                    anchors.fill: parent
                    text: card.expanded ? card.icons.ui.chevronUp : card.icons.ui.chevronDown
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
            easing.type: card.theme.motion.easingStandard
            onRunningChanged: card.inlineHeightAnimating = running
            onFinished: {
                allocationFinalizeTimer.stop()
                card.finishLayoutHeightAnimation()
            }
        }
    }
}
