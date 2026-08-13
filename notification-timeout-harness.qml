//@ pragma UseQApplication

import QtQuick
import Quickshell
import "features/notifications" as Notifications
import "services" as Services
import "theme" as Theme

ShellRoot {
    id: root

    readonly property var firstManager: firstManagerLoader.item
    readonly property var secondManager: secondManagerLoader.item
    readonly property var harnessBarWindow: barWindow
    property var popup: null
    property int closeCount: 0
    property int pausedRemaining: 0
    property int stage: 0
    // An owner of this script's own, registered like any manager but attached
    // to no card. A claim set through a manager's hoverOwnerId is not the
    // script's to keep: that same id belongs to a live HoverHandler, which
    // clears it the moment the pointer says so. This one nothing else touches.
    property string scriptOwnerId: ""

    function fail(message) {
        console.error(`TIMEOUT-HARNESS: ${message}`)
        Qt.quit()
    }

    function require(condition, message) {
        if (!condition)
            fail(message)
        return condition
    }

    function publish(timeout, urgency) {
        serviceState.notification.notificationTimeoutNormal = timeout
        const notification = {
            summary: "Timeout harness",
            body: "Two visual copies, one timeout owner",
            appName: "Harness",
            appIcon: "",
            desktopEntry: "",
            image: "",
            urgency: urgency,
            actions: [],
            transient: true
        }
        popup = serviceState.notification.createNotificationPopup(notification, { urgency: urgency }, "")
        serviceState.notification.visibleNotifications = [popup]
        serviceState.notification.processNotificationPopupQueue()
    }

    function advance(delay) {
        stageTimer.interval = delay
        stageTimer.restart()
    }

    // Every live manager, not only the one this script hovered. A popup is
    // frozen while *any* owner claims it, and each manager renders a real card
    // with a real HoverHandler, so a claim can appear without the script asking
    // for one. The stage after a release needs every claim gone, or it measures
    // the leftover instead of the release.
    function releaseHoverClaims() {
        const owners = [root.scriptOwnerId, firstManager ? firstManager.hoverOwnerId : "",
                        secondManager ? secondManager.hoverOwnerId : ""]
        for (const owner of owners) {
            if (owner)
                serviceState.notification.setNotificationPopupHovered(owner, root.popup.id, false)
        }
    }

    function start() {
        root.require(firstManager !== null && secondManager !== null, "manager creation failed")
        root.scriptOwnerId = serviceState.notification.registerNotificationPopupManager()
        root.require(root.scriptOwnerId !== "", "script owner registration failed")
        root.publish(2400, 1)
        root.advance(350)
    }

    Services.Services {
        id: serviceState
    }

    PanelWindow {
        id: barWindow

        screen: Quickshell.screens[0]
        implicitWidth: 1
        implicitHeight: 1
        visible: true
        Component.onCompleted: Qt.callLater(function () { root.start() })

        Timer {
            id: stageTimer
            repeat: false
            onTriggered: root.runStage()
        }

    }

    LazyLoader {
        id: firstManagerLoader
        active: true
        component: Notifications.NotificationPopupManager {
            services: serviceState
            barWindow: root.harnessBarWindow
        }
    }

    LazyLoader {
        id: secondManagerLoader
        active: true
        component: Notifications.NotificationPopupManager {
            services: serviceState
            barWindow: root.harnessBarWindow
        }
    }

    Connections {
        target: serviceState.notification
        function onNotificationPopupClosed(popupId) {
            root.closeCount++
        }
    }

    function runStage() {
        if (root.stage === 0) {
            if (!root.require(firstManager.popupItems.length === 1 && secondManager.popupItems.length === 1,
                              "two managers did not render the same popup")) return
            const firstRemaining = serviceState.notification.notificationPopupRemainingMs(root.popup.id)
            const secondRemaining = serviceState.notification.notificationPopupRemainingMs(root.popup.id)
            if (!root.require(Math.abs(firstRemaining - secondRemaining) <= 5,
                              "copies did not observe one countdown")) return
            serviceState.notification.setNotificationPopupHovered(firstManager.hoverOwnerId, root.popup.id, true)
            root.pausedRemaining = serviceState.notification.notificationPopupRemainingMs(root.popup.id)
            root.stage = 1
            root.advance(1200)
        } else if (root.stage === 1) {
            const remaining = serviceState.notification.notificationPopupRemainingMs(root.popup.id)
            if (!root.require(serviceState.notification.visibleNotifications.length === 1,
                              "non-hovered copy closed the popup")) return
            if (!root.require(Math.abs(remaining - root.pausedRemaining) <= 75,
                              "aggregate hover did not freeze countdown")) return
            // A second claim this script owns outright, so the next stage
            // asserts rather than observes. It goes through scriptOwnerId, not
            // through the second manager: a claim on a manager's id is that
            // manager's card to clear. Claimed before the first is released, so
            // the popup is never briefly free.
            serviceState.notification.setNotificationPopupHovered(root.scriptOwnerId, root.popup.id, true)
            serviceState.notification.setNotificationPopupHovered(firstManager.hoverOwnerId, root.popup.id, false)
            root.stage = 2
            root.advance(400)
        } else if (root.stage === 2) {
            const remaining = serviceState.notification.notificationPopupRemainingMs(root.popup.id)
            // One owner letting go must not speak for another. Without this the
            // blanket release below would hide a per-owner release that had
            // started clearing everybody's claims.
            if (!root.require(Math.abs(remaining - root.pausedRemaining) <= 75,
                              "releasing one owner released another owner's claim")) return
            root.releaseHoverClaims()
            root.stage = 3
            // Wide enough that the countdown has to have moved well past the
            // 200ms the next stage asserts. At 350ms the whole check lived
            // inside 150ms of slack, and any scheduling hiccup spent it.
            root.advance(700)
        } else if (root.stage === 3) {
            const remaining = serviceState.notification.notificationPopupRemainingMs(root.popup.id)
            // Two different failures used to share one message, which said the
            // countdown restarted even when the popup had simply run out.
            if (!root.require(remaining > 0, "popup expired before the resume could be observed")) return
            if (!root.require(remaining < root.pausedRemaining - 200,
                              "countdown restarted instead of resuming remaining time")) return
            serviceState.notification.setNotificationPopupHovered(firstManager.hoverOwnerId, root.popup.id, true)
            firstManagerLoader.active = false
            // Everything except the destroyed manager must hold nothing here,
            // or the wait below would pass on someone else's claim rather than
            // on the destroyed manager's being released.
            if (secondManager && secondManager.hoverOwnerId)
                serviceState.notification.setNotificationPopupHovered(secondManager.hoverOwnerId, root.popup.id, false)
            serviceState.notification.setNotificationPopupHovered(root.scriptOwnerId, root.popup.id, false)
            root.stage = 4
            root.advance(remaining + 250)
        } else if (root.stage === 4) {
            if (!root.require(serviceState.notification.visibleNotifications.length === 0,
                              "destroyed hovered manager left a permanent claim")) return
            if (!root.require(root.closeCount === 1, "expiry did not produce exactly one close")) return
            root.publish(0, 2)
            root.stage = 5
            root.advance(1200)
        } else {
            if (!root.require(serviceState.notification.visibleNotifications.length === 1,
                              "critical timeout 0 auto-closed")) return
            if (!root.require(root.closeCount === 1, "critical popup emitted a close")) return

            // A critical popup is on screen here, which is exactly what do not
            // disturb must not take away.
            const anyNotification = { urgency: 1 }
            if (!root.require(!serviceState.notification.notificationSuppressedByDnd({ urgency: 1 }, anyNotification),
                              "dnd suppressed a popup while it was off")) return

            serviceState.notification.toggleNotificationDnd()
            if (!root.require(serviceState.notification.visibleNotifications.length === 1,
                              "turning dnd on cleared a critical popup")) return
            if (!root.require(!serviceState.notification.notificationSuppressedByDnd({ urgency: 2 }, anyNotification),
                              "dnd suppressed a critical notification")) return
            if (!root.require(serviceState.notification.notificationSuppressedByDnd({ urgency: 1 }, anyNotification),
                              "dnd did not suppress a normal notification")) return

            console.info("TIMEOUT-HARNESS: two-copy hover/remaining/destruction/critical/dnd/single-close passed")
            Qt.quit()
        }
    }
}
