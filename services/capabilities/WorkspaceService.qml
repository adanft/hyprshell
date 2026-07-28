import QtQuick
import Quickshell
import Quickshell.Hyprland

Scope {
    readonly property var statusWorkspaceIds: [1, 2, 3, 4, 5, 6, 7, 8, 9]
    readonly property var statusOccupiedWorkspaceIds: {
        const occupied = {}
        for (const workspace of Hyprland.workspaces.values)
            occupied[workspace.id] = workspace.toplevels.values.length > 0
        return occupied
    }
    readonly property var statusUrgentWorkspaceIds: {
        const urgent = {}
        for (const workspace of Hyprland.workspaces.values) {
            if (workspace.urgent)
                urgent[workspace.id] = true
        }
        for (const toplevel of Hyprland.toplevels.values) {
            if (toplevel.urgent && toplevel.workspace)
                urgent[toplevel.workspace.id] = true
        }
        return urgent
    }

    function focusWorkspace(workspaceId) {
        if (Hyprland.usingLua === true) {
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspaceId} })`)
            return
        }
        Hyprland.dispatch(`workspace ${workspaceId}`)
    }

    function statusWorkspaceIdsForMonitor(monitor) {
        if (!monitor)
            return []
        return statusWorkspaceIds.filter(workspaceId => {
            const workspace = Hyprland.workspaces.values.find(candidate => candidate.id === workspaceId)
            const assignedMonitor = workspace?.monitor
            if (!assignedMonitor)
                return false
            return assignedMonitor === monitor || (assignedMonitor.name.length > 0 && assignedMonitor.name
                                                   === monitor.name)
        })
    }
}
