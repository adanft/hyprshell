import QtQuick
import Quickshell
import Quickshell.Io
import "../FileViewState.js" as FileViewState

Scope {
    id: root
    readonly property int systemStatsRefreshMs: 1000
    property int cpuUsageSubscriberCount: 0
    property int memoryUsageSubscriberCount: 0
    readonly property bool cpuUsageEnabled: cpuUsageSubscriberCount > 0
    readonly property bool memoryUsageEnabled: memoryUsageSubscriberCount > 0
    property int cpuUsage: 0
    property int memoryUsage: 0
    property var previousCpuStats: null

    FileView {
        id: cpuStatFile
        path: "/proc/stat"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: memoryInfoFile
        path: "/proc/meminfo"
        blockLoading: true
        printErrors: false
    }
    Timer {
        interval: root.systemStatsRefreshMs
        running: root.cpuUsageEnabled || root.memoryUsageEnabled
        repeat: true
        onTriggered: root.refreshSystemStats()
    }
    Component.onCompleted: refreshSystemStats()

    function enableCpuUsage() {
        cpuUsageSubscriberCount++
        refreshSystemStats()
    }
    function disableCpuUsage() {
        cpuUsageSubscriberCount = Math.max(0, cpuUsageSubscriberCount - 1)
        if (!cpuUsageEnabled)
            previousCpuStats = null
    }
    function enableMemoryUsage() {
        memoryUsageSubscriberCount++
        refreshSystemStats()
    }
    function disableMemoryUsage() {
        memoryUsageSubscriberCount = Math.max(0, memoryUsageSubscriberCount - 1)
    }
    function refreshSystemStats() {
        if (cpuUsageEnabled) {
            const text = FileViewState.safeText(cpuStatFile, "CPU stats", true)
            if (text === null) {
                previousCpuStats = null
                cpuUsage = 0
            } else
                updateCpuUsage(text)
        }
        if (memoryUsageEnabled) {
            const text = FileViewState.safeText(memoryInfoFile, "memory stats", true)
            if (text === null)
                memoryUsage = 0
            else
                updateMemoryUsage(text)
        }
    }
    function updateCpuUsage(text) {
        const line = String(text || "").split("\n")[0]
        if (!line.startsWith("cpu ")) {
            previousCpuStats = null
            cpuUsage = 0
            return
        }
        const parts = line.trim().split(/\s+/)
        let total = 0
        for (let i = 1; i < parts.length; i++)
            total += Number(parts[i]) || 0
        const idle = (Number(parts[4]) || 0) + (Number(parts[5]) || 0)
        const previous = previousCpuStats
        previousCpuStats = {
            total: total,
            idle: idle
        }
        if (!previous)
            return
        const totalDelta = total - previous.total
        const idleDelta = idle - previous.idle
        if (totalDelta <= 0)
            return
        cpuUsage = Math.max(0, Math.min(100, Math.round(((totalDelta - idleDelta) * 100) / totalDelta)))
    }
    function updateMemoryUsage(text) {
        const lines = String(text || "").split("\n")
        let total = 0
        let available = 0
        for (const line of lines) {
            if (line.startsWith("MemTotal:"))
                total = Number(line.trim().split(/\s+/)[1]) || 0
            else if (line.startsWith("MemAvailable:"))
                available = Number(line.trim().split(/\s+/)[1]) || 0
        }
        memoryUsage = total > 0 ? Math.max(0, Math.min(100, Math.round(((total - available) * 100) / total))) : 0
    }
}
