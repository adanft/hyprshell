import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property var palette
    required property var services
    required property var barWindow

    readonly property int popupWidth: 380
    readonly property int topMargin: 52
    readonly property int rightMargin: 12
    readonly property int spacing: 6
    property var popupItems: []
    property real stackHeight: 0

    implicitWidth: popupWidth
    implicitHeight: Math.max(1, stackHeight)
    visible: stackHeight > 0
    color: "transparent"

    anchor.window: barWindow
    anchor.rect.x: Math.max(6, barWindow.width - width - rightMargin)
    anchor.rect.y: topMargin

    Component {
        id: popupComponent

        NotificationPopup {}
    }

    Item {
        id: popupLayer

        anchors.fill: parent
    }

    Connections {
        target: root.services

        function onVisibleNotificationsChanged() {
            root.syncPopups()
        }
    }

    Component.onCompleted: syncPopups()

    function itemFor(popupData) {
        if (!popupData)
            return null

        return popupItems.find(item => item && !item.exiting && item.popupData && item.popupData.id === popupData.id)
    }

    function createPopupItem(popupData) {
        const item = popupComponent.createObject(popupLayer, {
            palette: root.palette,
            services: root.services,
            popupData: popupData,
            width: root.popupWidth
        })

        if (item && item.layoutChanged)
            item.layoutChanged.connect(root.handlePopupLayoutChanged)
        if (item && item.slotHeightChanged)
            item.slotHeightChanged.connect(root.repositionPopupsWithoutYAnimation)
        if (item && item.exitFinished)
            item.exitFinished.connect(() => root.finishPopupExit(item))
        if (item && item.syncLayoutHeight)
            item.syncLayoutHeight()

        return item
    }

    function syncPopups() {
        const visiblePopups = root.services.visibleNotifications || []
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
        repositionPopups()
    }

    function repositionPopupsWithoutYAnimation() {
        setPopupYAnimationEnabled(false)
        repositionPopups()
        Qt.callLater(() => setPopupYAnimationEnabled(true))
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
}
