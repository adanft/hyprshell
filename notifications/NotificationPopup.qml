import "../theme"
import QtQuick

Item {
    id: popup

    readonly property var
    theme: AppTheme {
    }

    required property var colors
    required property var services
    property var popupData: null
    property bool active: true
    property bool exiting: false
    property bool animateY: true
    property real enterOffset: width + theme.spacing.notificationPopupEnterOffsetMargin
    property int autoCloseRemainingMs: 0
    property bool autoCloseTimerInitialized: false
    readonly property int enterAnimationMs: theme.motion.durationEntrance
    readonly property int moveAnimationMs: theme.motion.durationNormal
    readonly property real layoutHeight: notificationCard.layoutHeight
    readonly property real renderedLayoutHeight: notificationCard.renderedLayoutHeight
    readonly property real allocatedLayoutHeight: notificationCard.allocatedLayoutHeight

    signal layoutChanged()
    signal slotHeightChanged()
    signal exitFinished()

    function startEnterAnimation() {
        exiting = false;
        exitAnimation.stop();
        enterAnimation.stop();
        enterOffset = width + theme.spacing.notificationPopupEnterOffsetMargin;
        enterAnimation.start();
    }

    function startExitAnimation() {
        if (exiting)
            return ;

        exiting = true;
        enterAnimation.stop();
        exitAnimation.stop();
        autoCloseTimer.stop();
        exitAnimation.start();
    }

    function resetAutoCloseTimer() {
        autoCloseTimer.stop();
        autoCloseTimerInitialized = false;
        if (!popup.popupData || !popup.services || typeof popup.services.notification.notificationPopupTimeout !== "function") {
            autoCloseRemainingMs = 0;
            return ;
        }
        if (typeof popup.popupData.autoCloseRemainingMs === "number") {
            autoCloseRemainingMs = Math.max(0, popup.popupData.autoCloseRemainingMs);
            autoCloseTimerInitialized = true;
            return ;
        }

        autoCloseRemainingMs = popup.services.notification.notificationPopupTimeout(popup.popupData.urgency);
        autoCloseTimerInitialized = true;
    }

    implicitWidth: width
    implicitHeight: allocatedLayoutHeight
    height: allocatedLayoutHeight
    visible: popupData !== null
    onPopupDataChanged: {
        autoCloseTimerInitialized = false;
        Qt.callLater(popup.resetAutoCloseTimer);
    }
    Component.onCompleted: {
        Qt.callLater(popup.resetAutoCloseTimer);
    }
    onActiveChanged: {
        if (!active)
            autoCloseTimer.stop();

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

    Timer {
        id: autoCloseTimer

        interval: 250
        repeat: true
        running: popup.active && popup.visible && !popup.exiting && !notificationCard.cardHovered && autoCloseRemainingMs > 0
        onTriggered: {
            popup.autoCloseRemainingMs = Math.max(0, popup.autoCloseRemainingMs - interval);
            if (popup.popupData && popup.autoCloseRemainingMs <= 0)
                popup.services.notification.closeNotificationPopup(popup.popupData.id);

        }
    }

    NotificationCard {
        id: notificationCard

        x: popup.enterOffset
        width: parent.width
        colors: popup.colors
        notificationService: popup.services.notification
        notificationData: popup.popupData
        cornerRadius: popup.theme.shape.notificationCardRadius
        timeText: popup.popupData ? popup.services.notification.notificationTimeText(popup.popupData) : ""
        onLayoutChanged: popup.layoutChanged()
        onSlotHeightChanged: popup.slotHeightChanged()
        onCloseRequested: {
            if (popup.popupData)
                popup.services.notification.closeNotificationPopup(popup.popupData.id);

        }
        onActionInvoked: (action) => {
            if (popup.popupData)
                popup.services.notification.invokeNotificationPopupAction(popup.popupData.id, action);

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
