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
    property var _visibleConnection: null

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

    // LazyLoader's default property is its component, so a Connections block
    // written in here becomes that component — and every use site declares its
    // own overlay into the same property, which silently wins. The block never
    // instantiated, so nothing ever observed the item and active was never
    // cleared: overlays were kept alive for the life of the shell. LazyLoader
    // takes no sibling objects either, being a QObject, so the connection is
    // made by hand and the handler is kept so it can be undone.
    function _observeItem(loadedItem) {
        if (_observedItem && _visibleConnection)
            _observedItem.visibleChanged.disconnect(_visibleConnection)
        _visibleConnection = null
        _observedItem = loadedItem
        if (!loadedItem)
            return

        // Closes over its own item, so a late signal from a replaced item can
        // never be mistaken for one from the current item.
        _visibleConnection = function () {
            root._handleItemVisibleChanged(loadedItem)
        }
        loadedItem.visibleChanged.connect(_visibleConnection)
    }

    function _handleItemChanged(loadedItem) {
        const previousItem = _observedItem
        _observeItem(loadedItem)
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
}
