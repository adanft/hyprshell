import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../QuickControlState.js" as QuickControlState

Scope {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var audioSources: (Pipewire.nodes?.values ?? []).filter(node => node && node.audio && !node.isSink && !node.isStream)
    readonly property int sinkVolume: Math.round((root.sink?.audio?.volume ?? 0) * 100)
    readonly property bool sinkMuted: root.sink?.audio?.muted ?? false
    readonly property bool microphoneAvailable: Boolean(root.source && root.source.audio)
    readonly property int sourceVolume: root.microphoneAvailable ? Math.round(root.source.audio.volume * 100) : -1
    readonly property bool sourceMuted: root.microphoneAvailable ? root.source.audio.muted : false
    property var quickVolume: QuickControlState.unavailableCapability("Volume unavailable")

    PwObjectTracker { objects: [root.sink, root.source] }
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.refreshQuickVolume() }
        function onMutedChanged() { root.refreshQuickVolume() }
    }
    onSinkChanged: root.refreshQuickVolume()
    Timer {
        id: confirmationTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (root.quickVolume.activeRequestId !== null)
                root.quickVolume = QuickControlState.failRequest(root.quickVolume, root.quickVolume.activeRequestId, "reconciliation_timeout", "Volume adjustment failed")
        }
    }
    Component.onCompleted: root.refreshQuickVolume()

    function toggleMute(isSource) {
        const node = isSource ? root.source : root.sink
        if (node?.audio) node.audio.muted = !node.audio.muted
    }
    function setSourceVolume(percent) {
        const request = QuickControlState.normalizedVolumeRequest(percent, root.microphoneAvailable)
        if (!request) return
        root.source.audio.volume = request.volume
        if (request.unmute) root.source.audio.muted = false
    }
    function selectAudioSource(node) {
        if (!node || !root.audioSources.includes(node) || node === root.source) return
        Pipewire.preferredDefaultAudioSource = node
    }
    function changeVolume(isSource, delta) {
        const node = isSource ? root.source : root.sink
        if (!node?.audio) return
        const currentVolume = Math.round(node.audio.volume * 100)
        node.audio.volume = Math.max(0, Math.min(currentVolume + delta, 100)) / 100
        node.audio.muted = false
    }
    function refreshQuickVolume() {
        if (!root.sink?.audio || !Number.isFinite(Number(root.sink.audio.volume))) {
            root.quickVolume = QuickControlState.unavailableCapability("Volume unavailable")
            return
        }
        const percent = QuickControlState.clampPercent(Number(root.sink.audio.volume) * 100)
        if (root.quickVolume.activeRequestId !== null && percent !== root.quickVolume.draftPercent) return
        const reconciled = root.quickVolume.activeRequestId !== null
            ? QuickControlState.confirmRequest(root.quickVolume, root.quickVolume.activeRequestId, percent).state
            : QuickControlState.syncConfirmed(root.quickVolume, percent).state
        if (root.quickVolume.activeRequestId !== null) confirmationTimer.stop()
        root.quickVolume = Object.assign({}, reconciled, { muted: Boolean(root.sink.audio.muted) })
    }
    function requestSinkVolume(percent, requestId) {
        const normalized = QuickControlState.clampPercent(percent)
        if (normalized === null || !Number.isSafeInteger(requestId) || requestId < 1 || !root.sink?.audio) {
            root.quickVolume = QuickControlState.unavailableCapability("Volume unavailable")
            return
        }
        root.quickVolume = Object.assign({}, root.quickVolume, { availability: "pending_confirmation", draftPercent: normalized, activeRequestId: requestId, errorCode: null, errorText: null })
        try {
            root.sink.audio.volume = normalized / 100
            confirmationTimer.restart()
        } catch (error) {
            root.quickVolume = QuickControlState.failRequest(root.quickVolume, requestId, "write_failed", "Volume adjustment failed")
        }
    }
}
