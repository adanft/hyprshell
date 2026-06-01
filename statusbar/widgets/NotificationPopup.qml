import QtQuick

Item {
    id: popup

    required property var palette
    required property var services
    property var popupData: null
    property bool exiting: false
    property bool animateY: true
    property real enterOffset: width + 16
    signal layoutChanged()
    signal slotHeightChanged()
    signal exitFinished()

    readonly property int enterAnimationMs: 1200
    readonly property int moveAnimationMs: 1200
    readonly property real layoutHeight: notificationCard.layoutHeight
    readonly property real renderedLayoutHeight: notificationCard.renderedLayoutHeight
    readonly property real allocatedLayoutHeight: notificationCard.allocatedLayoutHeight

    implicitWidth: width
    implicitHeight: allocatedLayoutHeight
    height: allocatedLayoutHeight
    visible: popupData !== null

    Behavior on y {
        enabled: popup.animateY
        NumberAnimation { duration: popup.moveAnimationMs; easing.type: Easing.Linear }
    }

    onPopupDataChanged: {
        if (popupData !== null && autoCloseTimer.interval > 0)
            autoCloseTimer.restart()
        else
            autoCloseTimer.stop()
    }

    function startEnterAnimation() {
        exiting = false
        exitAnimation.stop()
        enterAnimation.stop()
        enterOffset = width + 16
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
        to: popup.width + 16
        duration: popup.enterAnimationMs
        easing.type: Easing.Linear
        onFinished: popup.exitFinished()
    }

    Timer {
        id: autoCloseTimer

        interval: popup.popupData ? popup.services.notificationPopupTimeout(popup.popupData.urgency) : 5000
        running: popup.visible && !popup.exiting && interval > 0
        onTriggered: {
            if (popup.popupData)
                popup.services.closeNotificationPopup(popup.popupData.id)
        }
    }

    NotificationCard {
        id: notificationCard

        x: popup.enterOffset
        width: parent.width
        palette: popup.palette
        notificationData: popup.popupData
        cornerRadius: 16
        timeText: popup.popupData ? popup.services.notificationTimeText(popup.popupData) : ""
        onLayoutChanged: popup.layoutChanged()
        onSlotHeightChanged: popup.slotHeightChanged()
        onCloseRequested: {
            if (popup.popupData)
                popup.services.closeNotificationPopup(popup.popupData.id)
        }
        onActionInvoked: action => {
            if (popup.popupData)
                popup.services.invokeNotificationPopupAction(popup.popupData.id, action)
        }
    }
}
