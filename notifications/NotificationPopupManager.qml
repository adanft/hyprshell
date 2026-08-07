import "../theme"
import QtQuick
import Quickshell

PopupWindow {
    id: root

    readonly property var theme: AppTheme

    required property var colors
    required property var services
    required property var barWindow
    readonly property int popupWidth: theme.sizing.notificationPopupWidth
    readonly property int topMargin: theme.spacing.notificationPopupTopMargin
    readonly property int rightMargin: theme.spacing.notificationPopupRightMargin
    readonly property int bottomMargin: theme.spacing.notificationPopupBottomMargin
    readonly property int spacing: theme.spacing.notificationPopupSpacing
    property var popupItems: []
    property real stackHeight: 0
    property bool popupRepositionScheduled: false
    property bool popupRepositionWithoutYAnimation: false
    readonly property string screenName: barWindow.screen ? barWindow.screen.name : ""
    readonly property bool isFocusedScreen: screenName === services.notification.focusedNotificationScreenName

    function itemFor(popupData) {
        if (!popupData)
            return null

        return popupItems.find(item => {
            return item && !item.exiting && item.popupData && item.popupData.id === popupData.id
        })
    }

    function createPopupItem(popupData) {
        const item = popupComponent.createObject(popupLayer, {
                                                     "colors": root.colors,
                                                     "services": root.services,
                                                     "popupData": popupData,
                                                     "active": root.isFocusedScreen,
                                                     "width": root.popupWidth
                                                 })
        if (item && item.layoutChanged)
            item.layoutChanged.connect(root.handlePopupLayoutChanged)

        if (item && item.slotHeightChanged)
            item.slotHeightChanged.connect(root.repositionPopupsWithoutYAnimation)

        if (item && item.exitFinished)
            item.exitFinished.connect(() => {
                return root.finishPopupExit(item)
            })

        if (item && item.syncLayoutHeight)
            item.syncLayoutHeight()

        return item
    }

    function clearPopupItems() {
        for (const item of popupItems) {
            if (item) {
                if (item.popupData && item.autoCloseTimerInitialized && typeof item.autoCloseRemainingMs === "number")
                    item.popupData.autoCloseRemainingMs = item.autoCloseRemainingMs

                item.destroy()
            }
        }
        popupItems = []
        stackHeight = 0
    }

    function syncPopups() {
        if (!root.isFocusedScreen) {
            clearPopupItems()
            return
        }

        const visiblePopups = root.services.notification.visibleNotifications || []
        const nextItems = []
        const enteringItems = []
        for (const popupData of visiblePopups) {
            let item = itemFor(popupData)
            if (!item) {
                item = createPopupItem(popupData)
                if (item)
                    enteringItems.push(item)
            }
            if (item)
                nextItems.push(item)
        }
        for (const item of nextItems) {
            if (item)
                item.active = true
        }
        for (const item of popupItems) {
            if (!item || nextItems.indexOf(item) !== -1)
                continue
            if (!item.exiting)
                item.startExitAnimation()

            nextItems.push(item)
        }
        popupItems = nextItems
        if (enteringItems.length > 0) {
            setPopupYAnimationEnabled(true)
            repositionPopups()
            for (const item of enteringItems)
                item.startEnterAnimation()
        } else {
            setPopupYAnimationEnabled(true)
            repositionPopups()
        }
    }

    function updatePopupActivity() {
        for (const item of popupItems) {
            if (item)
                item.active = root.isFocusedScreen
        }
    }

    function updatePopupCapacity() {
        if (!root.isFocusedScreen || !root.services
                || typeof root.services.notification.setNotificationPopupAvailableHeight !== "function")
            return
        const screenHeight = root.barWindow.screen ? root.barWindow.screen.height : root.barWindow.height
        root.services.notification.setNotificationPopupAvailableHeight(screenHeight - root.topMargin
                                                                       - root.bottomMargin)
    }

    function finishPopupExit(item) {
        const index = popupItems.indexOf(item)
        if (index !== -1) {
            const nextItems = popupItems.slice()
            nextItems.splice(index, 1)
            popupItems = nextItems
        }
        if (item)
            item.destroy()

        setPopupYAnimationEnabled(true)
        repositionPopups()
    }

    function handlePopupLayoutChanged() {
        scheduleRepositionPopups(false)
    }

    function repositionPopupsWithoutYAnimation() {
        scheduleRepositionPopups(true)
    }

    function scheduleRepositionPopups(withoutYAnimation) {
        if (withoutYAnimation) {
            popupRepositionWithoutYAnimation = true
            popupYAnimationRestoreTimer.stop()
            setPopupYAnimationEnabled(false)
        }

        if (popupRepositionScheduled)
            return
        popupRepositionScheduled = true
        Qt.callLater(() => {
            const restoreYAnimation = popupRepositionWithoutYAnimation
            popupRepositionScheduled = false
            popupRepositionWithoutYAnimation = false
            if (restoreYAnimation)
                setPopupYAnimationEnabled(false)
            repositionPopups()
            if (restoreYAnimation)
                schedulePopupYAnimationRestore()
        })
    }

    function schedulePopupYAnimationRestore() {
        popupYAnimationRestoreTimer.restart()
    }

    Timer {
        id: popupYAnimationRestoreTimer
        interval: 0
        repeat: false
        onTriggered: root.setPopupYAnimationEnabled(true)
    }

    function setPopupYAnimationEnabled(enabled) {
        for (const item of popupItems) {
            if (item)
                item.animateY = enabled
        }
    }

    function calculateStackHeight() {
        let y = 0
        for (const item of popupItems) {
            if (!item)
                continue
            y += root.popupSlotHeight(item) + root.spacing
        }
        return Math.max(0, y - root.spacing)
    }

    function repositionPopups() {
        let y = 0
        for (const item of popupItems) {
            if (!item)
                continue
            item.width = root.popupWidth
            item.z = 0
            if (!item.exiting)
                item.y = y

            y += root.popupSlotHeight(item) + root.spacing
        }
        stackHeight = Math.max(0, y - root.spacing)
    }

    function popupSlotHeight(item) {
        if (!item)
            return 0

        return item.renderedLayoutHeight || item.layoutHeight || 0
    }

    onIsFocusedScreenChanged: {
        updatePopupCapacity()
        if (isFocusedScreen)
            syncPopups()
        else
            clearPopupItems()
    }
    implicitWidth: popupWidth
    implicitHeight: Math.max(1, stackHeight)
    visible: isFocusedScreen && stackHeight > 0
    color: root.colors.transparent
    anchor.window: barWindow
    anchor.rect.x: Math.max(theme.spacing.notificationCenterScreenMargin, barWindow.width - width - rightMargin)
    anchor.rect.y: topMargin
    Component.onCompleted: {
        updatePopupCapacity()
        syncPopups()
    }

    Component {
        id: popupComponent

        NotificationPopup {}
    }

    Item {
        id: popupLayer

        anchors.fill: parent
    }

    Connections {
        function onVisibleNotificationsChanged() {
            root.syncPopups()
        }

        target: root.services.notification
    }
}
