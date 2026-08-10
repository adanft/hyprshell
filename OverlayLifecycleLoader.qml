import QtQuick
import Quickshell

LazyLoader {
    id: root

    property bool requestedVisible: false
    property bool directVisibility: false
    property int _lifecycleGeneration: 0
    property var _observedItem: null
    property bool _itemPresented: false
    property int _scheduledGeneration: -1
    property var _scheduledItem: null
    property int _dispatchedGeneration: -1
    property var _dispatchedItem: null
    property bool _openingPending: false

    active: false

    function open() {
        requestedVisible = true
        _openingPending = true
        active = true
        const generation = ++_lifecycleGeneration
        _scheduleOpen(generation, item)
    }

    function toggle() {
        if (!requestedVisible) {
            open()
            return
        }

        const loadedItem = item
        if (!_openingPending && (!loadedItem || !loadedItem.visible)) {
            open()
            return
        }

        close()
    }

    // Closing has to be callable on its own, not only as the second half of a
    // toggle, so that opening one overlay can dismiss whichever other one is
    // still up. Closing an already closed loader is a no-op.
    function close() {
        if (!requestedVisible)
            return

        const loadedItem = item
        requestedVisible = false
        _openingPending = false
        _lifecycleGeneration++
        if (!loadedItem || !loadedItem.visible) {
            active = false
            return
        }

        if (directVisibility)
            loadedItem.visible = false
        else
            loadedItem.close()
    }

    function _scheduleOpen(generation, loadedItem) {
        if (!loadedItem)
            return
        if ((_scheduledGeneration === generation && _scheduledItem === loadedItem) || (_dispatchedGeneration
                                                                                       === generation
                                                                                       && _dispatchedItem
                                                                                       === loadedItem))
            return
        _scheduledGeneration = generation
        _scheduledItem = loadedItem
        Qt.callLater(() => {
            if (root._scheduledGeneration !== generation || root._scheduledItem !== loadedItem)
                return
            root._scheduledGeneration = -1
            root._scheduledItem = null
            if (generation !== root._lifecycleGeneration || !root.requestedVisible || root.item !== loadedItem)
                return
            root._dispatchedGeneration = generation
            root._dispatchedItem = loadedItem
            root._openingPending = false
            if (root.directVisibility)
                loadedItem.visible = true
            else
                loadedItem.open()
        })
    }

    function _handleItemChanged(loadedItem) {
        const previousItem = _observedItem
        _observedItem = loadedItem
        _itemPresented = loadedItem !== null && loadedItem.visible
        if (loadedItem !== previousItem) {
            _scheduledGeneration = -1
            _scheduledItem = null
            _dispatchedGeneration = -1
            _dispatchedItem = null
        }
        if (loadedItem && requestedVisible)
            _scheduleOpen(_lifecycleGeneration, loadedItem)
    }

    function _handleItemVisibleChanged(loadedItem) {
        if (!loadedItem || loadedItem !== _observedItem)
            return
        if (loadedItem.visible) {
            _itemPresented = true
            _openingPending = false
            return
        }
        if (!_itemPresented)
            return
        requestedVisible = false
        _openingPending = false
        _lifecycleGeneration++
        active = false
    }

    onItemChanged: _handleItemChanged(item)

    Connections {
        target: root._observedItem
        enabled: target !== null

        function onVisibleChanged() {
            root._handleItemVisibleChanged(target)
        }
    }
}
