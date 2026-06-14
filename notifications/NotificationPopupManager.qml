import "../theme"
import QtQuick
import Quickshell

PopupWindow {
    id: root

    readonly property var
    theme: AppTheme {
    }

    required property var palette
    required property var services
    required property var barWindow
    readonly property int popupWidth: theme.sizing.notificationPopupWidth
    readonly property int topMargin: theme.spacing.notificationPopupTopMargin
    readonly property int rightMargin: theme.spacing.notificationPopupRightMargin
    readonly property int bottomMargin: theme.spacing.notificationPopupBottomMargin
    readonly property int spacing: theme.spacing.notificationPopupSpacing
    property var popupItems: []
    property real stackHeight: 0
    readonly property string screenName: barWindow.screen ? barWindow.screen.name : ""
    readonly property bool isFocusedScreen: screenName === services.focusedNotificationScreenName

    function itemFor(popupData) {
        if (!popupData)
            return null;

        return popupItems.find((item) => {
            return item && !item.exiting && item.popupData && item.popupData.id === popupData.id;
        });
    }

    function createPopupItem(popupData) {
        const item = popupComponent.createObject(popupLayer, {
            "palette": root.palette,
            "services": root.services,
            "popupData": popupData,
            "active": root.isFocusedScreen,
            "width": root.popupWidth
        });
        if (item && item.layoutChanged)
            item.layoutChanged.connect(root.handlePopupLayoutChanged);

        if (item && item.slotHeightChanged)
            item.slotHeightChanged.connect(root.repositionPopupsWithoutYAnimation);

        if (item && item.exitFinished)
            item.exitFinished.connect(() => {
            return root.finishPopupExit(item);
        });

        if (item && item.syncLayoutHeight)
            item.syncLayoutHeight();

        return item;
    }

    function syncPopups() {
        const visiblePopups = root.services.visibleNotifications || [];
        const nextItems = [];
        const enteringItems = [];
        for (const popupData of visiblePopups) {
            let item = itemFor(popupData);
            if (!item) {
                item = createPopupItem(popupData);
                if (item && root.isFocusedScreen)
                    enteringItems.push(item);
                else if (item)
                    item.enterOffset = 0;
            }
            if (item)
                nextItems.push(item);

        }
        for (const item of nextItems) {
            if (item)
                item.active = root.isFocusedScreen;

        }
        for (const item of popupItems) {
            if (!item || nextItems.indexOf(item) !== -1)
                continue;

            if (!item.exiting)
                item.startExitAnimation();

            nextItems.push(item);
        }
        popupItems = nextItems;
        if (enteringItems.length > 0) {
            setPopupYAnimationEnabled(true);
            repositionPopups();
            for (const item of enteringItems) item.startEnterAnimation()
        } else {
            setPopupYAnimationEnabled(true);
            repositionPopups();
        }
    }

    function updatePopupActivity() {
        for (const item of popupItems) {
            if (item)
                item.active = root.isFocusedScreen;

        }
    }

    function updatePopupCapacity() {
        if (!root.isFocusedScreen || !root.services || typeof root.services.setNotificationPopupAvailableHeight !== "function")
            return ;

        const screenHeight = root.barWindow.screen ? root.barWindow.screen.height : root.barWindow.height;
        root.services.setNotificationPopupAvailableHeight(screenHeight - root.topMargin - root.bottomMargin);
    }

    function finishPopupExit(item) {
        const index = popupItems.indexOf(item);
        if (index !== -1) {
            const nextItems = popupItems.slice();
            nextItems.splice(index, 1);
            popupItems = nextItems;
        }
        if (item)
            item.destroy();

        setPopupYAnimationEnabled(true);
        repositionPopups();
    }

    function handlePopupLayoutChanged() {
        repositionPopups();
    }

    function repositionPopupsWithoutYAnimation() {
        setPopupYAnimationEnabled(false);
        repositionPopups();
        Qt.callLater(() => {
            return setPopupYAnimationEnabled(true);
        });
    }

    function setPopupYAnimationEnabled(enabled) {
        for (const item of popupItems) {
            if (item)
                item.animateY = enabled;

        }
    }

    function calculateStackHeight() {
        let y = 0;
        for (const item of popupItems) {
            if (!item)
                continue;

            y += root.popupSlotHeight(item) + root.spacing;
        }
        return Math.max(0, y - root.spacing);
    }

    function repositionPopups() {
        let y = 0;
        for (const item of popupItems) {
            if (!item)
                continue;

            item.width = root.popupWidth;
            item.z = 0;
            if (!item.exiting)
                item.y = y;

            y += root.popupSlotHeight(item) + root.spacing;
        }
        stackHeight = Math.max(0, y - root.spacing);
    }

    function popupSlotHeight(item) {
        if (!item)
            return 0;

        return item.renderedLayoutHeight || item.layoutHeight || 0;
    }

    onIsFocusedScreenChanged: {
        updatePopupActivity();
        updatePopupCapacity();
    }
    implicitWidth: popupWidth
    implicitHeight: Math.max(1, stackHeight)
    visible: isFocusedScreen && stackHeight > 0
    color: root.palette.transparent
    anchor.window: barWindow
    anchor.rect.x: Math.max(theme.spacing.notificationCenterScreenMargin, barWindow.width - width - rightMargin)
    anchor.rect.y: topMargin
    Component.onCompleted: {
        updatePopupCapacity();
        syncPopups();
    }

    Component {
        id: popupComponent

        NotificationPopup {
        }

    }

    Item {
        id: popupLayer

        anchors.fill: parent
    }

    Connections {
        function onVisibleNotificationsChanged() {
            root.syncPopups();
        }

        target: root.services
    }

}
