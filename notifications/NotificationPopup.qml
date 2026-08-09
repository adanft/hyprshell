import "../theme"
import QtQuick

Item {
    id: popup

    readonly property var theme: AppTheme

    required property var colors
    required property var services
    required property string hoverOwnerId
    property var popupData: null
    property bool active: true
    property bool exiting: false
    property bool animateY: true
    property real enterOffset: width + theme.spacing.notificationPopupEnterOffsetMargin
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
        enterOffset = width + theme.spacing.notificationPopupEnterOffsetMargin
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
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: exitAnimation

        target: popup
        property: "enterOffset"
        to: popup.width + popup.theme.spacing.notificationPopupEnterOffsetMargin
        duration: popup.enterAnimationMs
        easing.type: Easing.Linear
        onFinished: popup.exitFinished()
    }

    NotificationCard {
        id: notificationCard

        x: popup.enterOffset
        width: parent.width
        colors: popup.colors
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
            easing.type: Easing.Linear
        }
    }
}
