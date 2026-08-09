//@ pragma UseQApplication

import QtQuick
import Quickshell
import "notifications" as Notifications
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

    function start() {
        root.require(firstManager !== null && secondManager !== null, "manager creation failed")
        root.publish(1800, 1)
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
            serviceState.notification.setNotificationPopupHovered(firstManager.hoverOwnerId, root.popup.id, false)
            root.stage = 2
            root.advance(350)
        } else if (root.stage === 2) {
            const remaining = serviceState.notification.notificationPopupRemainingMs(root.popup.id)
            if (!root.require(remaining < root.pausedRemaining - 200 && remaining > 0,
                              "countdown restarted instead of resuming remaining time")) return
            serviceState.notification.setNotificationPopupHovered(firstManager.hoverOwnerId, root.popup.id, true)
            firstManagerLoader.active = false
            root.stage = 3
            root.advance(remaining + 250)
        } else if (root.stage === 3) {
            if (!root.require(serviceState.notification.visibleNotifications.length === 0,
                              "destroyed hovered manager left a permanent claim")) return
            if (!root.require(root.closeCount === 1, "expiry did not produce exactly one close")) return
            root.publish(0, 2)
            root.stage = 4
            root.advance(1200)
        } else {
            if (!root.require(serviceState.notification.visibleNotifications.length === 1,
                              "critical timeout 0 auto-closed")) return
            if (!root.require(root.closeCount === 1, "critical popup emitted a close")) return
            console.info("TIMEOUT-HARNESS: two-copy hover/remaining/destruction/critical/single-close passed")
            Qt.quit()
        }
    }
}
