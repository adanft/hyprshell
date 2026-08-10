import "../../shared/components"
import "../../theme"
import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

PopupWindow {
    id: popup

    readonly property var icons: Icons

    readonly property var theme: AppTheme

    required property var services
    required property var barWindow
    readonly property int contentPadding: theme.spacing.space16
    readonly property int cardWidth: NotificationSizing.centerCardWidth
    readonly property real heightRatio: NotificationSizing.centerHeightRatio
    property var expandedNotificationIds: ({})

    function notificationExpansionKey(notification) {
        return notification && notification.id !== undefined ? `notification:${notification.id}` : ""
    }

    function isNotificationExpanded(notification) {
        const key = notificationExpansionKey(notification)
        return key.length > 0 && expandedNotificationIds[key] === true
    }

    function setNotificationExpanded(notification, expanded) {
        const key = notificationExpansionKey(notification)
        if (key.length === 0)
            return
        const nextExpandedIds = Object.assign({}, expandedNotificationIds)
        if (expanded)
            nextExpandedIds[key] = true
        else
            delete nextExpandedIds[key]
        expandedNotificationIds = nextExpandedIds
    }

    function pruneExpandedNotifications() {
        const activeIds = {}
        const notifications = services.notification.notifications || []
        for (const notification of notifications) {
            const key = notificationExpansionKey(notification)
            if (key.length > 0 && expandedNotificationIds[key] === true)
                activeIds[key] = true
        }
        expandedNotificationIds = activeIds
    }

    implicitWidth: cardWidth + contentPadding * 2
    implicitHeight: Math.min(NotificationSizing.centerMaxHeight,
                             Math.round((barWindow.screen ? barWindow.screen.height :
                                                            NotificationSizing.centerFallbackScreenHeight) * heightRatio))
    visible: false
    grabFocus: true
    color: "transparent"
    anchor.window: barWindow
    anchor.rect.x: Math.max(theme.spacing.space6, barWindow.width - width
                            - theme.spacing.space6)
    anchor.rect.y: theme.sizing.statusBarSurfaceTopOffset
    onVisibleChanged: popup.services.notification.setNotificationCenterOpen(visible)

    Shortcut {
        sequence: "Escape"
        enabled: popup.visible
        onActivated: popup.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: popup.theme.shape.notificationCenterRadius
        // The panel is the deep surface here and the cards lift off it, which is
        // the reverse of a card standing on its own over the desktop.
        color: Colors.shadow
        border.color: Colors.outline
        border.width: popup.theme.shape.notificationCenterBorderWidth

        Column {
            anchors.fill: parent
            anchors.margins: popup.contentPadding
            spacing: popup.theme.spacing.space12

            Row {
                id: headerRow

                width: parent.width
                height: NotificationSizing.centerHeaderHeight
                spacing: popup.theme.spacing.space8

                AppText {
                    id: headerTitle

                    anchors.verticalCenter: parent.verticalCenter
                    text: `Notifications (${popup.services.notification.notificationCount})`
                    color: Colors.on_surface
                    font.family: popup.theme.typography.textFontFamily
                }

                Item {
                    width: Math.max(0, parent.width - headerTitle.implicitWidth - dndButton.width
                                    - clearButton.width - parent.spacing * 3)
                    height: NotificationSizing.centerSpacerHeight
                }

                Rectangle {
                    id: dndButton

                    anchors.verticalCenter: parent.verticalCenter
                    width: NotificationSizing.centerClearButtonHeight
                    height: NotificationSizing.centerClearButtonHeight
                    radius: width / 2
                    color: popup.services.notification.notificationDnd ? Colors.primary :
                                                                         (dndMouse.containsMouse || dndMouse.activeFocus ?
                                                                          Colors.hover :
                                                                          "transparent")

                    AppText {
                        anchors.fill: parent
                        text: popup.icons.notification.doNotDisturb
                        color: popup.services.notification.notificationDnd ? Colors.on_primary :
                                                                             (dndMouse.containsMouse || dndMouse.activeFocus ?
                                                                              Colors.on_hover :
                                                                              Colors.on_surface_variant)
                        font.family: popup.theme.typography.iconFontFamily
                        font.pixelSize: popup.theme.typography.glyphSm
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: dndMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        activeFocusOnTab: true
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: "Do Not Disturb"
                        Accessible.checked: popup.services.notification.notificationDnd
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.services.notification.toggleNotificationDnd()
                        Keys.onReturnPressed: popup.services.notification.toggleNotificationDnd()
                        Keys.onEnterPressed: popup.services.notification.toggleNotificationDnd()
                        Keys.onSpacePressed: popup.services.notification.toggleNotificationDnd()
                    }
                }

                Rectangle {
                    id: clearButton

                    anchors.verticalCenter: parent.verticalCenter
                    width: NotificationSizing.centerClearButtonWidth
                    height: NotificationSizing.centerClearButtonHeight
                    radius: height / 2
                    visible: popup.services.notification.hasNotifications
                    color: clearMouse.containsMouse || clearMouse.activeFocus ? Colors.hover : "transparent"

                    AppText {
                        anchors.fill: parent
                        text: popup.icons.notification.clear
                        color: clearMouse.containsMouse ? Colors.on_hover : Colors.on_surface_variant
                        font.family: popup.theme.typography.iconFontFamily
                        font.pixelSize: popup.theme.typography.glyphSm
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: clearMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Clear all notifications"
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.services.notification.dismissNotifications()
                        Keys.onReturnPressed: popup.services.notification.dismissNotifications()
                        Keys.onEnterPressed: popup.services.notification.dismissNotifications()
                        Keys.onSpacePressed: popup.services.notification.dismissNotifications()
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - headerRow.height - parent.spacing

                AppText {
                    anchors.centerIn: parent
                    visible: !popup.services.notification.hasNotifications
                    text: "No notifications"
                    color: Colors.on_surface_variant
                    font.family: popup.theme.typography.textFontFamily
                    font.pixelSize: popup.theme.typography.textMd
                }

                ListView {
                    id: notificationList

                    anchors.fill: parent
                    visible: popup.services.notification.hasNotifications
                    clip: true
                    orientation: ListView.Vertical
                    spacing: popup.theme.spacing.space12
                    cacheBuffer: Math.max(0, height * 2)
                    reuseItems: false
                    model: popup.visible && popup.services.notification.hasNotifications
                           ? popup.services.notification.notifications : []
                    onModelChanged: popup.pruneExpandedNotifications()
                    boundsBehavior: Flickable.StopAtBounds

                    // The list always scrolled, but said nothing about it: a
                    // clipped column with no indicator gives no reason to think
                    // there is more below. Same rule as the control centre's
                    // detail pane — shown only while the content overflows.
                    Controls.ScrollBar.vertical: Controls.ScrollBar {
                        policy: notificationList.height > 0 && notificationList.contentHeight
                                > notificationList.height ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
                    }

                    delegate: NotificationCard {
                        required property int index

                        readonly property var entryData: popup.services.notification.notifications[index] || null

                        width: notificationList.width
                        notificationService: popup.services.notification
                        isHistoryEntry: true
                        initialExpanded: popup.isNotificationExpanded(entryData)
                        notificationData: entryData
                        useRenderedHeightForLayout: true
                        timeText: popup.services.notification.notificationTimeText(entryData)
                        onExpandedChanged: popup.setNotificationExpanded(entryData, expanded)
                        onCloseRequested: popup.services.notification.dismissNotificationHistoryEntry(entryData)
                        onActionInvoked: action => {
                            if (action && action.invoke)
                                action.invoke()
                        }
                    }
                }
            }
        }
    }
}
