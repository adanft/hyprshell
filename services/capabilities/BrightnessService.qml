import QtQuick
import Quickshell
import Quickshell.Io
import "../QuickControlState.js" as QuickControlState
import "../FileViewState.js" as FileViewState

Scope {
    id: root
    property string brightnessDevice: ""
    property bool brightnessAvailable: false
    property int brightnessLevel: 0
    property int pendingBrightnessLevel: -1
    readonly property int brightnessWriteDebounceMs: 100
    readonly property string brightnessPath: brightnessDevice.length > 0 ? `/sys/class/backlight/${brightnessDevice}/brightness` : ""
    readonly property string maxBrightnessPath: brightnessDevice.length > 0 ? `/sys/class/backlight/${brightnessDevice}/max_brightness` : ""
    property string brightnessDevicePath: ""
    readonly property bool quickBrightnessPathValid: QuickControlState.validBrightnessDevicePath(brightnessDevicePath)
    readonly property string quickBrightnessPath: quickBrightnessPathValid ? `${brightnessDevicePath}/brightness` : ""
    readonly property string quickMaxBrightnessPath: quickBrightnessPathValid ? `${brightnessDevicePath}/max_brightness` : ""
    property var quickBrightness: QuickControlState.unavailableCapability("Brightness unavailable")
    property int quickBrightnessMaximum: 0
    property int quickBrightnessRequestId: 0

    FileView {
        id: brightnessValueFile; path: root.brightnessPath; blockLoading: true; watchChanges: true; printErrors: false
        onLoaded: root.updateBrightnessFromFiles(false); onLoadFailed: root.clearBrightnessState(); onFileChanged: root.updateBrightnessFromFiles(true)
    }
    FileView {
        id: maxBrightnessValueFile; path: root.maxBrightnessPath; blockLoading: true; watchChanges: true; printErrors: false
        onLoaded: root.updateBrightnessFromFiles(false); onLoadFailed: root.clearBrightnessState(); onFileChanged: root.updateBrightnessFromFiles(true)
    }
    FileView {
        id: quickBrightnessValueFile; path: root.quickBrightnessPath; blockLoading: true; watchChanges: true; printErrors: false; atomicWrites: false
        onLoaded: root.refreshQuickBrightness(false); onLoadFailed: root.failQuickBrightnessRead("Brightness unavailable")
        onFileChanged: root.refreshQuickBrightness(true); onSaved: root.refreshQuickBrightness(true)
        onSaveFailed: root.failQuickBrightnessRequest("write_failed", "Brightness adjustment failed")
    }
    FileView {
        id: quickMaxBrightnessValueFile; path: root.quickMaxBrightnessPath; blockLoading: true; watchChanges: true; printErrors: false
        onLoaded: root.refreshQuickBrightness(false); onLoadFailed: root.failQuickBrightnessRead("Brightness unavailable"); onFileChanged: root.refreshQuickBrightness(true)
    }
    Process { id: brightnessDetectProcess; stdout: StdioCollector { onStreamFinished: root.detectBrightnessDevice(this.text) } }
    Process { id: brightnessWriteProcess; onExited: root.scheduleBrightnessWrite() }
    Timer { id: brightnessWriteDebounceTimer; interval: root.brightnessWriteDebounceMs; repeat: false; onTriggered: root.flushBrightnessWrite() }
    Timer { id: quickBrightnessConfirmationTimer; interval: 1500; repeat: false; onTriggered: root.failQuickBrightnessRequest("reconciliation_timeout", "Brightness adjustment failed") }
    onBrightnessDevicePathChanged: {
        quickBrightness = QuickControlState.unavailableCapability("Brightness unavailable")
        quickBrightnessMaximum = 0
        if (quickBrightnessPathValid) Qt.callLater(refreshQuickBrightness, true)
    }
    Component.onCompleted: {
        detectBrightness()
        if (quickBrightnessPathValid) refreshQuickBrightness(true)
    }

    function detectBrightness() {
        if (brightnessDevice.length > 0) { updateBrightnessFromFiles(); return }
        brightnessDetectProcess.exec(["sh", "-c", "brightnessctl -m 2>/dev/null || true"])
    }
    function detectBrightnessDevice(output) {
        const fields = String(output || "").trim().split(",")
        if (fields.length === 0 || fields[0].length === 0) { clearBrightnessState(); return }
        brightnessDevice = fields[0]
        const match = String(output || "").match(/(\d+)%/)
        if (match) brightnessLevel = Math.max(0, Math.min(100, parseInt(match[1], 10)))
        Qt.callLater(updateBrightnessFromFiles)
    }
    function clearBrightnessState() { brightnessWriteDebounceTimer.stop(); pendingBrightnessLevel = -1; brightnessAvailable = false; brightnessLevel = 0 }
    function updateBrightnessFromFiles(reloadFiles) {
        if (brightnessDevice.length === 0) { clearBrightnessState(); return }
        if (!brightnessValueFile.loaded || !maxBrightnessValueFile.loaded) return
        const currentText = FileViewState.safeText(brightnessValueFile, "brightness", reloadFiles)
        const maximumText = FileViewState.safeText(maxBrightnessValueFile, "max brightness", reloadFiles)
        if (currentText === null || maximumText === null) { clearBrightnessState(); return }
        const current = Number(currentText.trim()); const maximum = Number(maximumText.trim())
        if (!Number.isFinite(current) || !Number.isFinite(maximum) || maximum <= 0) { clearBrightnessState(); return }
        brightnessAvailable = true
        brightnessLevel = Math.max(0, Math.min(100, Math.round((current * 100) / maximum)))
    }
    function setBrightness(percent) {
        const next = Math.max(0, Math.min(100, Math.round(percent)))
        if (next === brightnessLevel && (pendingBrightnessLevel < 0 || pendingBrightnessLevel === next)) return
        brightnessLevel = next; pendingBrightnessLevel = next; scheduleBrightnessWrite()
    }
    function scheduleBrightnessWrite() { if (pendingBrightnessLevel >= 0) brightnessWriteDebounceTimer.restart() }
    function flushBrightnessWrite() {
        if (pendingBrightnessLevel < 0 || brightnessWriteProcess.running) return
        const next = pendingBrightnessLevel; pendingBrightnessLevel = -1
        brightnessWriteProcess.exec(["brightnessctl", "set", `${next}%`])
    }
    function changeBrightness(delta) { setBrightness(brightnessLevel + delta) }
    function refreshQuickBrightness(reloadFiles) {
        if (!quickBrightnessPathValid) { quickBrightness = QuickControlState.unavailableCapability("Brightness unavailable"); quickBrightnessMaximum = 0; return }
        if (!quickBrightnessValueFile.loaded || !quickMaxBrightnessValueFile.loaded) return
        const currentText = FileViewState.safeText(quickBrightnessValueFile, "quick brightness", reloadFiles)
        const maximumText = FileViewState.safeText(quickMaxBrightnessValueFile, "quick max brightness", reloadFiles)
        const readback = currentText === null || maximumText === null ? null : QuickControlState.normalizedReadback(currentText, maximumText)
        if (!readback) { failQuickBrightnessRead("Brightness unavailable"); return }
        quickBrightnessMaximum = readback.rawMaximum
        if (quickBrightness.activeRequestId !== null && readback.percent !== quickBrightness.draftPercent) return
        quickBrightness = quickBrightness.activeRequestId !== null
            ? QuickControlState.confirmRequest(quickBrightness, quickBrightness.activeRequestId, readback.percent).state
            : QuickControlState.syncConfirmed(quickBrightness, readback.percent).state
        quickBrightnessConfirmationTimer.stop()
    }
    function failQuickBrightnessRead(message) {
        quickBrightness = quickBrightness.lastKnownPercent !== null
            ? Object.assign({}, quickBrightness, { availability: "failed", authoritativePercent: quickBrightness.lastKnownPercent, errorCode: "invalid_native_value", errorText: message })
            : QuickControlState.unavailableCapability(message)
    }
    function requestBrightness(percent, requestId) {
        const raw = QuickControlState.rawForPercent(percent, quickBrightnessMaximum)
        if (!quickBrightnessPathValid || raw === null || !Number.isSafeInteger(requestId) || requestId < 1 || quickBrightness.availability === "unavailable") return
        const expectedPercent = Math.round((raw * 100) / quickBrightnessMaximum)
        quickBrightnessRequestId = requestId
        quickBrightness = Object.assign({}, quickBrightness, { availability: "pending_confirmation", draftPercent: expectedPercent, activeRequestId: requestId, errorCode: null, errorText: null })
        try { quickBrightnessValueFile.setText(String(raw)); quickBrightnessConfirmationTimer.restart() }
        catch (error) { failQuickBrightnessRequest("write_failed", "Brightness adjustment failed") }
    }
    function failQuickBrightnessRequest(code, message) {
        quickBrightnessConfirmationTimer.stop()
        quickBrightness = QuickControlState.failRequest(quickBrightness, quickBrightnessRequestId, code, message)
    }
}
