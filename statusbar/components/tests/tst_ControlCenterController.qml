import QtQuick
import QtTest
import ".."

TestCase {
    id: testCase
    name: "ControlCenterController"
    when: windowShown

    Component {
        id: networkingComponent
        QtObject {
            property bool wifiEnabled: true
            property bool wifiHardwareEnabled: true
        }
    }
    Component {
        id: serviceComponent
        QtObject {
            property var wifiDevice: null
            property var lanDevice: null
            property int detailEnables: 0
            property int detailDisables: 0
            function enableNetworkDetails() {
                detailEnables += 1
            }
            function disableNetworkDetails() {
                detailDisables += 1
            }
        }
    }
    Component {
        id: deviceComponent
        QtObject {
            property bool scannerEnabled: false
            property int scannerWrites: 0
            onScannerEnabledChanged: scannerWrites += 1
        }
    }
    Component {
        id: uptimeComponent
        QtObject {
            property string value: "42.5 0"
            property int reloads: 0
            function reload() {
                reloads += 1
            }
            function text() {
                return value
            }
        }
    }
    Component {
        id: networkComponent
        QtObject {
            property string name: "Network"
            property bool connected: false
            property bool known: false
            property bool stateChanging: false
            property int security: 2
            property int connects: 0
            property int disconnects: 0
            property int pskConnects: 0
            property int forgets: 0
            property string lastPassword: ""
            signal connectionFailed(var reason)
            function connect() {
                connects += 1
            }
            function disconnect() {
                disconnects += 1
            }
            function connectWithPsk(password) {
                pskConnects += 1
                lastPassword = password
            }
            function forget() {
                forgets += 1
            }
        }
    }
    Component {
        id: controllerComponent
        ControlCenterController {}
    }
    SignalSpy {
        id: closeSpy
        signalName: "closeRequested"
    }
    property var fixtures: []

    function fixture(values) {
        const networking = networkingComponent.createObject(testCase, values?.networking || {})
        const service = serviceComponent.createObject(testCase)
        const device = deviceComponent.createObject(testCase, values?.device || {})
        const uptime = uptimeComponent.createObject(testCase, values?.uptime || {})
        verify(networking !== null && service !== null && device !== null && uptime !== null)
        service.wifiDevice = device
        const controller = controllerComponent.createObject(testCase, {
                                                                networkService: service,
                                                                networking,
                                                                menuOpen: values?.menuOpen || false,
                                                                uptimeSource: uptime,
                                                                failureReasonText: reason => String(reason),
                                                                openSecurityValue: 0,
                                                                noSecretsValue: 7
                                                            })
        verify(controller !== null)
        const result = {
            controller,
            networking,
            service,
            device,
            uptime,
            devices: [device],
            networks: []
        }
        fixtures.push(result)
        closeSpy.target = controller
        closeSpy.clear()
        return result
    }

    function destroyController(f) {
        if (!f.controller)
            return
        f.controller.destroy()
        f.controller = null
        wait(0)
    }

    function cleanup() {
        closeSpy.target = null
        for (const f of fixtures)
            destroyController(f)
        for (const f of fixtures) {
            for (const network of f.networks)
                network.destroy()
            for (const device of f.devices)
                device.destroy()
            f.uptime.destroy()
            f.service.destroy()
            f.networking.destroy()
        }
        fixtures = []
        wait(0)
    }

    function network(f, values) {
        const result = networkComponent.createObject(testCase, values || {})
        verify(result !== null)
        f.networks.push(result)
        return result
    }

    function openWifi(f) {
        f.controller.menuOpen = true
        f.controller.toggleNetworkSection("wifi")
    }

    function test_uptimeIsOpenOnlyAndRetainsInvalidValue() {
        const f = fixture({})
        compare(f.controller.uptimeRefreshIntervalMs, 60000)
        compare(f.controller.uptimeRefreshTimer.repeat, true)
        compare(f.controller.uptimeRefreshTimer.running, false)
        compare(f.uptime.reloads, 1)
        compare(f.controller.uptimeSeconds, 42.5)
        f.uptime.value = "invalid"
        f.controller.refreshUptime()
        compare(f.controller.uptimeSeconds, 42.5)
        f.controller.prepareOpen()
        compare(f.uptime.reloads, 3)
        f.controller.menuOpen = true
        compare(f.controller.uptimeRefreshTimer.running, true)
        f.controller.menuOpen = false
        compare(f.controller.uptimeRefreshTimer.running, false)
    }

    function test_timerMetadataAndActivationGeneration() {
        const f = fixture({
                              networking: {
                                  wifiEnabled: false
                              }
                          })
        compare(f.controller.scannerStartDelayMs, 300)
        compare(f.controller.activationSettleDelayMs, 900)
        compare(f.controller.wifiScannerStartTimer.interval, 300)
        compare(f.controller.wifiScannerStartTimer.repeat, false)
        compare(f.controller.wifiActivationSettleTimer.interval, 900)
        compare(f.controller.wifiActivationSettleTimer.repeat, false)
        f.controller.toggleWifiEnabled()
        compare(f.networking.wifiEnabled, true)
        compare(f.controller.wifiActivationGeneration, 1)
        compare(f.controller.wifiActivationPending, true)
        compare(f.controller.activationSettleGeneration, 1)
        f.controller.handleActivationSettleElapsed(0)
        compare(f.controller.wifiActivationPending, true)
        f.controller.handleActivationSettleElapsed(1)
        compare(f.controller.wifiActivationPending, false)
    }

    function test_scannerCaptureAndStaleCallbacks() {
        const f = fixture({})
        openWifi(f)
        compare(f.controller.scannerDelayDevice, f.device)
        compare(f.controller.scannerDelayGeneration, f.controller.wifiActivationGeneration)
        f.controller.handleScannerDelayElapsed({}, f.controller.scannerDelayGeneration)
        compare(f.device.scannerEnabled, false)
        f.controller.handleScannerDelayElapsed(f.device, f.controller.scannerDelayGeneration + 1)
        compare(f.device.scannerEnabled, false)
        f.controller.handleScannerDelayElapsed(f.device, f.controller.scannerDelayGeneration)
        compare(f.device.scannerEnabled, true)
        compare(f.controller.scannerOwnedDevice, f.device)
        compare(f.device.scannerWrites, 1)
    }

    function test_disabledAndClosedCallbacksDoNothing() {
        for (const disabled of ["wifiEnabled", "wifiHardwareEnabled"]) {
            const f = fixture({})
            openWifi(f)
            const device = f.device
            const generation = f.controller.scannerDelayGeneration
            f.networking[disabled] = false
            f.controller.handleScannerDelayElapsed(device, generation)
            compare(device.scannerEnabled, false)
        }
        const closed = fixture({})
        openWifi(closed)
        const generation = closed.controller.scannerDelayGeneration
        closed.controller.menuOpen = false
        closed.controller.handleScannerDelayElapsed(closed.device, generation)
        compare(closed.device.scannerEnabled, false)
        compare(closed.controller.wifiScannerStartTimer.running, false)
        const activation = fixture({
                                       networking: {
                                           wifiEnabled: false
                                       }
                                   })
        activation.controller.toggleWifiEnabled()
        compare(activation.controller.wifiActivationSettleTimer.running, true)
        activation.controller.menuOpen = true
        activation.controller.menuOpen = false
        compare(activation.controller.wifiActivationSettleTimer.running, false)
    }

    function test_replacementReleasesOnlyOwnedScanner() {
        const f = fixture({})
        openWifi(f)
        f.controller.handleScannerDelayElapsed(f.device, f.controller.scannerDelayGeneration)
        const replacement = deviceComponent.createObject(testCase)
        verify(replacement !== null)
        f.devices.push(replacement)
        f.service.wifiDevice = replacement
        compare(f.device.scannerEnabled, false)
        compare(f.controller.scannerDevice, replacement)
        const foreign = fixture({
                                    device: {
                                        scannerEnabled: true
                                    }
                                })
        compare(foreign.controller.scannerOwnedDevice, null)
        destroyController(foreign)
        compare(foreign.device.scannerEnabled, true)
    }

    // Opening the panel on a section is not the same gesture as clicking that
    // section's header: a section survives a close, so toggling it on the way in
    // would collapse the very thing the click asked to see.
    function test_expandingASectionIsIdempotentUnlikeToggling() {
        const f = fixture({})
        f.controller.menuOpen = true

        f.controller.expandNetworkSection("bluetooth")
        compare(f.controller.expandedNetworkSection, "bluetooth")

        f.controller.expandNetworkSection("bluetooth")
        compare(f.controller.expandedNetworkSection, "bluetooth")

        f.controller.expandNetworkSection("output")
        compare(f.controller.expandedNetworkSection, "output")

        // Opening with no section named leaves whatever was there alone.
        f.controller.expandNetworkSection("")
        compare(f.controller.expandedNetworkSection, "output")

        // Toggling is still the header's gesture and still collapses.
        f.controller.toggleNetworkSection("output")
        compare(f.controller.expandedNetworkSection, "")
    }

    function test_outputSectionIsIndependentAndDoesNotOwnScanner() {
        const f = fixture({})
        f.controller.menuOpen = true
        f.controller.toggleNetworkSection("output")
        compare(f.controller.expandedNetworkSection, "output")
        compare(f.device.scannerEnabled, false)
        compare(f.device.scannerWrites, 0)
        f.controller.toggleNetworkSection("output")
        compare(f.controller.expandedNetworkSection, "")
        f.controller.toggleNetworkSection("microphone")
        compare(f.controller.expandedNetworkSection, "microphone")
        f.controller.toggleNetworkSection("output")
        compare(f.controller.expandedNetworkSection, "output")
        f.controller.requestClose()
        f.controller.menuOpen = false
        compare(f.controller.expandedNetworkSection, "")
        compare(f.device.scannerEnabled, false)
    }

    function test_detailSubscriptionAndCleanupAreBalanced() {
        const f = fixture({})
        compare(f.service.detailEnables, 0)
        f.controller.menuOpen = true
        compare(f.service.detailEnables, 1)
        f.controller.menuOpen = false
        compare(f.service.detailDisables, 1)
        f.controller.menuOpen = true
        compare(f.service.detailEnables, 2)
        destroyController(f)
        compare(f.service.detailDisables, 2)
    }

    function test_closeAndDestroyInvalidateOwnedWorkOnce() {
        const f = fixture({})
        openWifi(f)
        f.controller.handleScannerDelayElapsed(f.device, f.controller.scannerDelayGeneration)
        const generation = f.controller.wifiActivationGeneration
        f.controller.requestClose()
        compare(closeSpy.count, 1)
        f.controller.menuOpen = false
        compare(f.device.scannerEnabled, false)
        f.controller.handleActivationSettleElapsed(generation)
        compare(f.controller.wifiActivationPending, false)
        const writes = f.device.scannerWrites
        destroyController(f)
        compare(f.device.scannerWrites, writes)
    }

    function test_connectionCommandsDispatchExactlyOnce() {
        const f = fixture({})
        const connected = network(f, {
                                      connected: true
                                  })
        const known = network(f, {
                                  known: true
                              })
        const open = network(f, {
                                 security: 0
                             })
        const secured = network(f, {
                                    name: "Secured"
                                })
        const saved = network(f, {
                                  known: true
                              })
        f.controller.connectNetwork(connected)
        f.controller.connectNetwork(known)
        f.controller.connectNetwork(open)
        compare(connected.disconnects, 1)
        compare(known.connects, 1)
        compare(open.connects, 1)
        f.controller.connectNetwork(secured)
        compare(f.controller.pendingNetwork, secured)
        f.controller.submitPassword("secret")
        compare(secured.pskConnects, 1)
        compare(secured.lastPassword, "secret")
        secured.stateChanging = true
        f.controller.submitPassword("again")
        compare(secured.pskConnects, 1)
        secured.stateChanging = false
        f.controller.submitPassword("")
        compare(secured.pskConnects, 1)
        f.controller.cancelPasswordEntry()
        f.controller.submitPassword("again")
        compare(secured.pskConnects, 1)
        f.controller.forgetNetwork(saved)
        compare(saved.forgets, 1)
        const invalid = network(f, {
                                    known: false
                                })
        const busyForget = network(f, {
                                       known: true,
                                       stateChanging: true
                                   })
        f.controller.forgetNetwork(invalid)
        f.controller.forgetNetwork(busyForget)
        compare(invalid.forgets, 0)
        compare(busyForget.forgets, 0)
        f.service.lanDevice = {
            network: saved
        }
        saved.stateChanging = true
        f.controller.toggleEthernet()
        compare(saved.connects, 0)
        saved.stateChanging = false
        f.controller.toggleEthernet()
        compare(saved.connects, 1)
        saved.connected = true
        f.controller.toggleEthernet()
        compare(saved.disconnects, 1)
    }

    function test_cancelAndClosePreserveSuppressionOrder() {
        const f = fixture({})
        const target = network(f, {
                                   name: "Same"
                               })
        f.controller.connectNetwork(target)
        target.stateChanging = true
        let observed = null
        f.controller.closeRequested.connect(() => observed = f.controller.suppressedPasswordNetwork)
        f.controller.requestClose()
        compare(observed, target)
        compare(f.controller.pendingNetwork, null)
        compare(f.controller.suppressedPasswordNetwork, target)
        f.controller.connectNetwork(target)
        f.controller.cancelPasswordEntry()
        compare(f.controller.pendingNetwork, null)
        compare(f.controller.suppressedPasswordNetwork, target)
    }

    function test_failuresSuccessAndStrictIdentity() {
        const f = fixture({})
        const pending = network(f, {
                                    name: "Same"
                                })
        const sameName = network(f, {
                                     name: "Same"
                                 })
        f.controller.connectNetwork(pending)
        f.controller.handleWifiNetworkConnectionFailed(pending, 2)
        compare(f.controller.connectionError, "")
        pending.connectionFailed(2)
        compare(f.controller.connectionError, "Same: 2")
        pending.stateChanging = true
        f.controller.cancelPasswordEntry()
        f.controller.handleWifiNetworkConnectionFailed(sameName, 2)
        compare(f.controller.suppressedPasswordNetwork, pending)
        compare(f.controller.connectionError, "Same: 2")
        f.controller.handleWifiNetworkConnectionFailed(pending, 2)
        compare(f.controller.suppressedPasswordNetwork, null)
        f.controller.handleWifiNetworkConnectionFailed(sameName, 7)
        compare(f.controller.pendingNetwork, sameName)
        sameName.stateChanging = true
        f.controller.cancelPasswordEntry()
        compare(f.controller.suppressedPasswordNetwork, sameName)
        sameName.connected = true
        f.controller.handleWifiNetworkConnectedChanged(sameName)
        compare(f.controller.suppressedPasswordNetwork, null)
        f.service.lanDevice = {
            network: sameName
        }
        sameName.connectionFailed(4)
        compare(f.controller.connectionError, "Ethernet: 4")
    }
}
