import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../AudioNodeState.js" as AudioNodeState
import "../QuickControlState.js" as QuickControlState

Scope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var allAudioNodes: Pipewire.nodes?.values ?? []
    readonly property var audioSources: root.allAudioNodes.filter(node => node && node.audio && !node.isSink && !node.isStream)
    readonly property var audioOutputs: AudioNodeState.physicalOutputs(root.allAudioNodes, root.sink)
    readonly property var playbackStreams: AudioNodeState.playbackStreams(root.allAudioNodes)
    readonly property int sinkVolume: Math.round((root.sink?.audio?.volume ?? 0) * 100)
    readonly property bool sinkMuted: root.sink?.audio?.muted ?? false
    readonly property bool microphoneAvailable: Boolean(root.source && root.source.audio)
    readonly property int sourceVolume: root.microphoneAvailable ? Math.round(root.source.audio.volume * 100) : -1
    readonly property bool sourceMuted: root.microphoneAvailable ? root.source.audio.muted : false
    property var quickVolume: QuickControlState.unavailableCapability("Volume unavailable")

    PwObjectTracker { objects: root.allAudioNodes }
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.refreshQuickVolume(); }
        function onMutedChanged() { root.refreshQuickVolume(); }
    }
    onSinkChanged: root.resetAndRefreshQuickVolume()
    Timer {
        id: confirmationTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (root.quickVolume.activeRequestId !== null)
                root.quickVolume = QuickControlState.failRequest(root.quickVolume, root.quickVolume.activeRequestId, "reconciliation_timeout", "Volume adjustment failed");
        }
    }
    Component.onCompleted: root.refreshQuickVolume()

    function isCurrentPhysicalSink(node) {
        return node === root.sink
            && AudioNodeState.containsCurrentNode(root.allAudioNodes, node, AudioNodeState.isPhysicalOutput);
    }

    function failMasterWrite(requestId) {
        confirmationTimer.stop();
        if (Number.isSafeInteger(requestId))
            root.quickVolume = QuickControlState.failRequest(root.quickVolume, requestId, "target_unavailable", "Volume adjustment failed");
        else
            root.quickVolume = QuickControlState.unavailableCapability("Volume unavailable");
        return false;
    }

    function toggleMute(isSource) {
        const node = isSource ? root.source : root.sink;
        if (isSource) {
            if (node?.audio) node.audio.muted = !node.audio.muted;
            return;
        }
        try {
            if (!root.isCurrentPhysicalSink(node)) return root.failMasterWrite(null);
            node.audio.muted = !node.audio.muted;
            return true;
        } catch (_) {
            return root.failMasterWrite(null);
        }
    }

    function setSourceVolume(percent) {
        const request = QuickControlState.normalizedVolumeRequest(percent, root.microphoneAvailable);
        if (!request) return;
        root.source.audio.volume = request.volume;
        if (request.unmute) root.source.audio.muted = false;
    }

    function selectAudioSource(node) {
        if (!node || !root.audioSources.includes(node) || node === root.source) return;
        Pipewire.preferredDefaultAudioSource = node;
    }

    function selectAudioSink(node) {
        if (!AudioNodeState.containsCurrentNode(root.allAudioNodes, node, AudioNodeState.isPhysicalOutput)) return false;
        if (node === root.sink) return true;
        try {
            Pipewire.preferredDefaultAudioSink = node;
            return true;
        } catch (_) {
            return false;
        }
    }

    function isWritablePlaybackStream(node) {
        return AudioNodeState.canControlPlaybackStream(root.allAudioNodes, node);
    }

    function togglePlaybackStreamMute(node) {
        try {
            if (!root.isWritablePlaybackStream(node)) return false;
            node.audio.muted = !node.audio.muted;
            return true;
        } catch (_) {
            return false;
        }
    }

    function requestPlaybackStreamVolume(node, percent) {
        const request = QuickControlState.normalizedVolumeRequest(percent, true);
        if (!request) return false;
        try {
            if (!root.isWritablePlaybackStream(node)) return false;
            if (request.unmute) node.audio.muted = false;
            node.audio.volume = request.volume;
            return true;
        } catch (_) {
            return false;
        }
    }

    function changeVolume(isSource, delta) {
        const node = isSource ? root.source : root.sink;
        if (!node?.audio) return;
        try {
            if (!isSource && !root.isCurrentPhysicalSink(node)) return root.failMasterWrite(null);
            const volume = Math.max(0, Math.min(Math.round(node.audio.volume * 100) + delta, 100)) / 100;
            node.audio.volume = volume;
            node.audio.muted = false;
        } catch (_) {
            if (!isSource) return root.failMasterWrite(null);
        }
    }

    function resetAndRefreshQuickVolume() {
        confirmationTimer.stop();
        root.quickVolume = QuickControlState.unavailableCapability("Volume unavailable");
        root.refreshQuickVolume();
    }

    function refreshQuickVolume() {
        if (!root.sink?.audio || !Number.isFinite(Number(root.sink.audio.volume))) {
            root.quickVolume = QuickControlState.unavailableCapability("Volume unavailable");
            return;
        }
        const percent = QuickControlState.clampPercent(Number(root.sink.audio.volume) * 100);
        if (root.quickVolume.activeRequestId !== null && percent !== root.quickVolume.draftPercent) return;
        const reconciled = root.quickVolume.activeRequestId !== null
            ? QuickControlState.confirmRequest(root.quickVolume, root.quickVolume.activeRequestId, percent).state
            : QuickControlState.syncConfirmed(root.quickVolume, percent).state;
        if (root.quickVolume.activeRequestId !== null) confirmationTimer.stop();
        root.quickVolume = Object.assign({}, reconciled, { muted: Boolean(root.sink.audio.muted) });
    }

    function requestSinkVolume(percent, requestId) {
        const node = root.sink;
        const request = QuickControlState.normalizedVolumeRequest(percent, Boolean(node?.audio));
        if (!request || !Number.isSafeInteger(requestId) || requestId < 1) {
            root.quickVolume = QuickControlState.unavailableCapability("Volume unavailable");
            return;
        }
        root.quickVolume = Object.assign({}, root.quickVolume, { availability: "pending_confirmation", draftPercent: request.percent, activeRequestId: requestId, errorCode: null, errorText: null });
        try {
            if (!root.isCurrentPhysicalSink(node)) return root.failMasterWrite(requestId);
            if (request.unmute) node.audio.muted = false;
            node.audio.volume = request.volume;
            confirmationTimer.restart();
            return true;
        } catch (_) {
            return root.failMasterWrite(requestId);
        }
    }
}
