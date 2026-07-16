import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: cache

    readonly property string cacheRoot: (Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME") || ""}/.cache`) + "/qsrice/wallpapers"
    readonly property int maxJobs: 1
    property bool cacheReady: false
    property var pending: []
    property var requested: ({})
    property var known: ({})
    property var cleaning: ({})
    property int activeJobs: 0
    property string currentPath: ""
    property string currentIdentity: ""
    property string currentDestination: ""
    property string currentTemporary: ""
    property bool jobTerminal: false
    property bool statHandled: false

    signal thumbnailReady(string sourcePath, string thumbnailUrl)

    Component.onCompleted: {
        const mkdir = mkdirComponent.createObject(cache)
        mkdir.onExited.connect(function(exitCode) {
            if (exitCode !== 0) {
                mkdir.destroy()
                return
            }
            cache.cacheReady = true
            const cleanup = cleanupComponent.createObject(cache)
            cleanup.onExited.connect(function() {
                cleanup.destroy()
                cache.pump()
            })
            cleanup.exec(["find", cacheRoot, "-maxdepth", "1", "-type", "f",
                    "(", "-name", "*.tmp-*", "-o", "(", "-name", "*.jpg", "-mtime", "+30", ")", ")",
                    "-delete"])
            mkdir.destroy()
        })
        mkdir.exec(["mkdir", "-p", cacheRoot])
    }

    function hash(value) {
        let result = 2166136261
        for (let i = 0; i < value.length; ++i) {
            result ^= value.charCodeAt(i)
            result = Math.imul(result, 16777619)
        }
        return (result >>> 0).toString(16).padStart(8, "0")
    }

    function destination(path, mtime, size) {
        return `${cacheRoot}/${hash(path)}-${mtime}-${size}.jpg`
    }

    function fileUrl(path) {
        return "file://" + String(path).split('/').map(s => encodeURIComponent(s)).join('/')
    }

    function sourceFor(path) {
        return known[path] ? fileUrl(known[path]) : fileUrl(path)
    }

    function request(path, token) {
        if (!path)
            return
        const identity = token === undefined ? "resident" : String(token)
        if (requested[path] === identity)
            return
        requested[path] = identity
        const queued = pending.findIndex(item => item.path === path)
        if (queued >= 0) {
            pending[queued] = { path: path, token: token }
            return
        }
        pending.push({ path: path, token: token })
        pump()
    }

    function statToken(token) {
        const match = /^(-?\d+):(\d+)$/.exec(String(token))
        if (!match)
            return ""
        const mtime = Number(match[1])
        const size = Number(match[2])
        if (!Number.isSafeInteger(mtime) || !Number.isSafeInteger(size))
            return ""
        return `${Math.floor(mtime / 1000)}:${size}`
    }

    function pump() {
        if (!cacheReady || activeJobs >= maxJobs || pending.length === 0)
            return
        const next = pending.findIndex(item => !cleaning[item.path] && item.path !== currentPath)
        if (next < 0)
            return
        const item = pending.splice(next, 1)[0]
        activeJobs++
        currentPath = item.path
        currentIdentity = item.token === undefined ? "resident" : String(item.token)
        jobTerminal = false
        statHandled = false
        const token = statToken(item.token)
        if (token) {
            statFinished(token)
            return
        }
        const stat = statComponent.createObject(cache, { sourcePath: item.path })
        stat.exec(["stat", "-c", "%Y:%s", "--", item.path])
    }

    function statFinished(text) {
        if (jobTerminal)
            return
        const parts = String(text).trim().split(":")
        if (parts.length !== 2 || !parts[0]) {
            failJob()
            return
        }
        const destinationPath = destination(currentPath, parts[0], parts[1])
        const exists = existsComponent.createObject(cache)
        exists.onExited.connect(function(exitCode) {
            if (!jobTerminal) {
                if (exitCode === 0)
                    publish(currentPath, destinationPath)
                else
                    generate(destinationPath)
            }
            exists.destroy()
        })
        exists.exec(["test", "-s", destinationPath])
    }

    function generate(destinationPath) {
        currentDestination = destinationPath
        currentTemporary = `${destinationPath}.tmp-${hash(currentPath + Date.now())}`
        const process = generationComponent.createObject(cache)
        process.onExited.connect(function(exitCode) {
            if (!jobTerminal) {
                if (exitCode === 0) {
                    const move = moveComponent.createObject(cache)
                    move.onExited.connect(function(moveExitCode) {
                        if (moveExitCode === 0)
                            publish(currentPath, currentDestination)
                        else
                            failJob()
                        move.destroy()
                    })
                    move.exec(["mv", "-f", "--", currentTemporary, currentDestination])
                } else {
                    failJob()
                }
            }
            process.destroy()
        })
        process.exec(["magick", `${currentPath}[0]`, "-auto-orient", "-thumbnail", "512x512", "-quality", "88", "jpeg:" + currentTemporary])
    }

    function publish(path, destinationPath) {
        if (jobTerminal)
            return
        jobTerminal = true
        known[path] = destinationPath
        thumbnailReady(path, fileUrl(destinationPath))
        activeJobs--
        currentPath = ""
        currentIdentity = ""
        currentTemporary = ""
        currentDestination = ""
        cleaning[path] = true
        pump()
        const old = cleanupComponent.createObject(cache)
        old.onExited.connect(function() {
            delete cleaning[path]
            old.destroy()
            cache.pump()
        })
        old.exec(["find", cacheRoot, "-maxdepth", "1", "-type", "f", "-name", `${hash(path)}-*.jpg`, "!", "-name", destinationPath.split('/').pop(), "-delete"])
    }

    function failJob() {
        if (jobTerminal)
            return
        jobTerminal = true
        const failedPath = currentPath
        const failedIdentity = currentIdentity
        const temporary = currentTemporary
        activeJobs--
        currentPath = ""
        currentIdentity = ""
        currentTemporary = ""
        currentDestination = ""
        if (requested[failedPath] === failedIdentity)
            delete requested[failedPath]
        if (!temporary) {
            pump()
            return
        }
        const cleanup = cleanupFileComponent.createObject(cache)
        cleanup.onExited.connect(function() {
            cleanup.destroy()
            cache.pump()
        })
        cleanup.exec(["rm", "-f", "--", temporary])
    }

    Component { id: mkdirComponent; Process {} }
    Component { id: cleanupComponent; Process {} }
    Component { id: cleanupFileComponent; Process {} }
    Component { id: existsComponent; Process {} }
    Component { id: generationComponent; Process {} }
    Component { id: moveComponent; Process {} }

    Component {
        id: statComponent
        Process {
            property string sourcePath: ""
            stdout: StdioCollector {
                onStreamFinished: {
                    if (!cache.statHandled) {
                        cache.statHandled = true
                        cache.statFinished(text)
                    }
                }
            }
            onExited: {
                if (!cache.statHandled) {
                    cache.statHandled = true
                    cache.failJob()
                }
                destroy()
            }
        }
    }
}
