import QtQuick
import Quickshell
import Quickshell.Io
import "ActiveUserAvatar.js" as AvatarLogic

Item {
    id: root

    readonly property alias source: internal.source
    readonly property alias state: internal.state

    QtObject {
        id: internal
        property string source: ""
        property string state: "idle"
        property int generation: 0
        property int accountGeneration: 0
        property int iconGeneration: 0
    }

    function fail(state) {
        internal.source = ""
        internal.state = state
    }

    function refresh() {
        if (accountProcess.running || iconProcess.running)
            return
        internal.generation++
        internal.source = ""

        const username = String(Quickshell.env("USER") || Quickshell.env("LOGNAME") || "").trim()
        if (username.length === 0) {
            internal.state = "unavailable"
            return
        }

        internal.state = "finding_account"
        internal.accountGeneration = internal.generation
        accountProcess.exec(["busctl", "--system", "--json=short", "--timeout=2", "call", "org.freedesktop.Accounts",
                             "/org/freedesktop/Accounts", "org.freedesktop.Accounts", "FindUserByName", "s", username])
    }

    Process {
        id: accountProcess

        stdout: StdioCollector {
            id: accountOutput
        }
        onExited: (exitCode, exitStatus) => {
            if (internal.accountGeneration !== internal.generation)
                return
            if (exitCode !== 0) {
                root.fail("unavailable")
                return
            }

            const objectPath = AvatarLogic.parseUserObjectPath(accountOutput.text)
            if (objectPath.length === 0) {
                root.fail("rejected")
                return
            }

            internal.state = "reading_icon"
            internal.iconGeneration = internal.generation
            iconProcess.exec(["busctl", "--system", "--json=short", "--timeout=2", "get-property",
                              "org.freedesktop.Accounts", objectPath, "org.freedesktop.Accounts.User", "IconFile"])
        }
    }

    Process {
        id: iconProcess

        stdout: StdioCollector {
            id: iconOutput
        }
        onExited: (exitCode, exitStatus) => {
            if (internal.iconGeneration !== internal.generation)
                return
            if (exitCode !== 0) {
                root.fail("unavailable")
                return
            }

            const candidate = AvatarLogic.parseIconFile(iconOutput.text)
            if (candidate.length === 0) {
                root.fail("rejected")
                return
            }

            internal.source = candidate
            internal.state = "candidate_ready"
        }
    }

    Component.onCompleted: refresh()
}
