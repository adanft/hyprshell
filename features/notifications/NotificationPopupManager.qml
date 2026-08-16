import "../../theme"
import QtQuick
import Quickshell

PopupWindow {
    id: root

    readonly property var theme: AppTheme

    required property var services
    required property var barWindow
    readonly property int popupWidth: NotificationSizing.popupWidth
    readonly property int topMargin: theme.spacing.space52
    readonly property int rightMargin: theme.spacing.space12
    readonly property int bottomMargin: theme.spacing.space12
    readonly property int spacing: theme.spacing.space6
    property var popupItems: []
    // Two heights, because they answer different questions. `stackHeight` is how
    // tall the cards are drawn right now and moves every frame; `allocatedStackHeight`
    // is how much room they have been promised and steps once per gesture. The
    // window takes the second, and is therefore never smaller than the first.
    property real stackHeight: 0
    property real allocatedStackHeight: 0
    property bool popupRepositionScheduled: false
    property bool popupRepositionWithoutYAnimation: false
    property string hoverOwnerId: ""
    readonly property real maxStackHeight: Math.max(0, (barWindow.screen ? barWindow.screen.height :
                                                                          barWindow.height) - topMargin
                                                    - bottomMargin)

    function itemFor(popupData) {
        if (!popupData)
            return null

        return popupItems.find(item => {
            return item && !item.exiting && item.popupData && item.popupData.id === popupData.id
        })
    }

    function createPopupItem(popupData) {
        const item = popupComponent.createObject(popupLayer, {
                                                      "services": root.services,
                                                      "hoverOwnerId": root.hoverOwnerId,
                                                     "active": true,
                                                     "width": root.popupWidth
                                                 })
        if (item)
            item.popupData = popupData

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
                item.destroy()
            }
        }
        popupItems = []
        stackHeight = 0
    }

    function syncPopups() {
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

    function updatePopupCapacity() {
        if (!root.services
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

    function repositionPopups() {
        let y = 0
        let allocated = 0
        for (const item of popupItems) {
            if (!item)
                continue
            item.width = root.popupWidth
            item.z = 0
            if (!item.exiting)
                item.y = y

            y += root.popupSlotHeight(item) + root.spacing
            allocated += root.popupSlotAllocation(item) + root.spacing
        }
        stackHeight = Math.max(0, y - root.spacing)
        allocatedStackHeight = Math.max(0, allocated - root.spacing)
    }

    // Where a card sits, measured by what is actually painted this frame, so the
    // cards below follow one that is growing instead of waiting for it to land.
    // This only writes `y` on sibling items, which costs nothing outside this
    // process — unlike the window, below.
    //
    // Read honestly, with no `||` chain. Zero used to fall through to
    // `layoutHeight`, because zero is falsy, so a card that had not been given
    // its data yet reserved the FULL slot for one frame and then collapsed to a
    // few pixels before growing back. A fallback that cannot tell "not ready
    // yet" from "nothing to show" reports the wrong one confidently.
    function popupSlotHeight(item) {
        if (!item)
            return 0

        const rendered = Number(item.renderedLayoutHeight)
        return Number.isFinite(rendered) && rendered > 0 ? rendered : 0
    }

    // What the WINDOW is sized by, and it must not be the painted height.
    //
    // This object is a PopupWindow — a real xdg_popup surface. Sizing it from a
    // value that moves every frame asks the compositor to reconfigure that
    // surface about thirteen times per expand at 60Hz, and twice that at 144.
    // Nobody wrote "animate the window"; it arrived through the card's height
    // Behavior and came out here.
    //
    // `allocatedLayoutHeight` is already the shape a container wants: the card
    // computes it as the max of where it was and where it is going, and holds it
    // there until the movement settles. So it steps once per gesture rather than
    // once per frame, and it is never below what is painted — which is what lets
    // `popupLayer`'s clip stay honest instead of cutting off the bottom of a
    // card that is still growing.
    function popupSlotAllocation(item) {
        if (!item)
            return 0

        const allocated = Number(item.allocatedLayoutHeight)
        if (Number.isFinite(allocated) && allocated > 0)
            return allocated

        // A card is given its data and measured in the same call stack, one turn
        // before the deferred pass that sets its geometry, so for that turn it
        // reports no allocation while already knowing how tall it will be. Only
        // this reader falls back, and only to the card's own target: this is the
        // one measurement where being too small is the answer that shows, since
        // a window short of the card about to be painted into it clips that card.
        // `popupSlotHeight` is asked a different question — what is on screen —
        // and for that turn the honest answer really is nothing, so it does not
        // fall back. The two used to share one reader, and it could only be right
        // about one of them.
        const target = Number(item.layoutHeight)
        return Number.isFinite(target) && target > 0 ? target : 0
    }

    implicitWidth: popupWidth
    implicitHeight: Math.max(1, Math.min(allocatedStackHeight, maxStackHeight))
    visible: allocatedStackHeight > 0
    color: "transparent"
    anchor.window: barWindow
    anchor.rect.x: Math.max(theme.spacing.space6, barWindow.width - width - rightMargin)
    anchor.rect.y: topMargin
    Component.onCompleted: {
        hoverOwnerId = services.notification.registerNotificationPopupManager()
        updatePopupCapacity()
        syncPopups()
    }
    Component.onDestruction: {
        if (hoverOwnerId)
            services.notification.unregisterNotificationPopupManager(hoverOwnerId)
    }

    Component {
        id: popupComponent

        NotificationPopup {}
    }

    Item {
        id: popupLayer

        anchors.fill: parent
        clip: true
    }

    Connections {
        function onVisibleNotificationsChanged() {
            root.syncPopups()
        }

        target: root.services.notification
    }
}
