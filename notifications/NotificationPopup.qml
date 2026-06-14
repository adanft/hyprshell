import "../theme"
import QtQuick

Item {
    id: popup

    readonly property var
    theme: AppTheme {
    }

    required property var palette
    required property var services
    property var popupData: null
    property bool active: true
    property bool exiting: false
    property bool animateY: true
    property real enterOffset: width + theme.spacing.notificationPopupEnterOffsetMargin
    property int autoCloseRemainingMs: 0
    readonly property int enterAnimationMs: 260
    readonly property int moveAnimationMs: 220
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
        if (!popup.popupData || !popup.services || typeof popup.services.notificationPopupTimeout !== "function") {
            autoCloseRemainingMs = 0;
            return ;
        }
        autoCloseRemainingMs = popup.services.notificationPopupTimeout(popup.popupData.urgency);
    }

    implicitWidth: width
    implicitHeight: allocatedLayoutHeight
    height: allocatedLayoutHeight
    visible: popupData !== null
    onPopupDataChanged: {
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
                popup.services.closeNotificationPopup(popup.popupData.id);

        }
    }

    NotificationCard {
        id: notificationCard

        x: popup.enterOffset
        width: parent.width
        palette: popup.palette
        notificationData: popup.popupData
        cornerRadius: popup.theme.shape.notificationCardRadius
        timeText: popup.popupData ? popup.services.notificationTimeText(popup.popupData) : ""
        onLayoutChanged: popup.layoutChanged()
        onSlotHeightChanged: popup.slotHeightChanged()
        onCloseRequested: {
            if (popup.popupData)
                popup.services.closeNotificationPopup(popup.popupData.id);

        }
        onActionInvoked: (action) => {
            if (popup.popupData)
                popup.services.invokeNotificationPopupAction(popup.popupData.id, action);

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
