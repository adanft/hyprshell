import "../../theme"
import QtQuick

Item {
    id: popup

    readonly property var theme: AppTheme

    required property var services
    required property string hoverOwnerId
    property var popupData: null
    property bool active: true
    property bool exiting: false
    property bool animateY: true
    property real enterOffset: width + theme.spacing.space16
    readonly property int enterAnimationMs: theme.motion.durationEntrance
    readonly property int moveAnimationMs: theme.motion.durationNormal
    readonly property real layoutHeight: notificationCard.layoutHeight
    readonly property real renderedLayoutHeight: notificationCard.renderedLayoutHeight
    readonly property real allocatedLayoutHeight: notificationCard.allocatedLayoutHeight

    signal layoutChanged
    signal slotHeightChanged
    signal exitFinished

    function startEnterAnimation() {
        exiting = false
        exitAnimation.stop()
        enterAnimation.stop()
        enterOffset = width + theme.spacing.space16
        enterAnimation.start()
    }

    function startExitAnimation() {
        if (exiting)
            return
        exiting = true
        enterAnimation.stop()
        exitAnimation.stop()
        exitAnimation.start()
    }

    implicitWidth: width
    implicitHeight: allocatedLayoutHeight
    height: allocatedLayoutHeight
    visible: popupData !== null
    Component.onDestruction: {
        if (popupData)
            services.notification.setNotificationPopupHovered(hoverOwnerId, popupData.id, false)
    }

    NumberAnimation {
        id: enterAnimation

        target: popup
        property: "enterOffset"
        to: 0
        duration: popup.enterAnimationMs
        easing.type: popup.theme.motion.easingStandard
    }

    NumberAnimation {
        id: exitAnimation

        target: popup
        property: "enterOffset"
        to: popup.width + popup.theme.spacing.space16
        duration: popup.enterAnimationMs
        // The one curve here that is not the standard one. This is the only
        // movement in the card that ends with nothing on screen, and a card that
        // gathers speed on the way out reads as dismissed, where one that eases to
        // a stop at the edge reads as hesitating.
        easing.type: popup.theme.motion.easingExit
        onFinished: popup.exitFinished()
    }

    NotificationCard {
        id: notificationCard

        x: popup.enterOffset
        width: parent.width
        notificationService: popup.services.notification
        notificationData: popup.popupData
        allowLiveImage: true
        cornerRadius: popup.theme.shape.notificationCardRadius
        timeText: popup.popupData ? popup.services.notification.notificationTimeText(popup.popupData) : ""
        onLayoutChanged: popup.layoutChanged()
        onSlotHeightChanged: popup.slotHeightChanged()
        onCardHoveredChanged: {
            if (popup.popupData)
                popup.services.notification.setNotificationPopupHovered(popup.hoverOwnerId, popup.popupData.id,
                                                                         cardHovered)
        }
        onCloseRequested: {
            if (popup.popupData)
                popup.services.notification.closeNotificationPopup(popup.popupData.id)
        }
        onActionInvoked: action => {
            if (popup.popupData)
                popup.services.notification.invokeNotificationPopupAction(popup.popupData.id, action)
        }
    }

    Behavior on y {
        enabled: popup.animateY

        NumberAnimation {
            duration: popup.moveAnimationMs
            easing.type: popup.theme.motion.easingStandard
        }
    }
}
