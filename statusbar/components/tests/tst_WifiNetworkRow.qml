import QtQuick
import QtTest
import ".."

TestCase {
    id: testCase
    name: "WifiNetworkRow"
    when: windowShown
    width: 360
    height: 100

    Component {
        id: rowComponent

        WifiNetworkRow {
            width: 340
            network: ({
                          name: "Test network",
                          connected: false,
                          known: true,
                          stateChanging: false,
                          signalStrength: 0.8,
                          security: 0
                      })
            colors: ({
                         surface: "#202020",
                         surfaceHover: "#303030",
                         transparent: "transparent",
                         primary: "#88aaff",
                         text: "#ffffff",
                         textSubtle: "#bbbbbb",
                         textMuted: "#aaaaaa",
                         danger: "#ff7777"
                     })
            theme: ({
                        shape: {
                            radius12: 12,
                            radius8: 8
                        },
                        spacing: {
                            space16: 16,
                            space12: 12,
                            space8: 8,
                            space4: 4,
                            space2: 2
                        },
                        sizing: {
                            statusBarTrayMenuItemHeight: 36,
                            statusBarNetworkDeviceRowHeight: 48
                        },
                        motion: {
                            opacityDisabled: 0.45
                        },
                        typography: {
                            sizeSm: 11,
                            sizeMd: 14,
                            textFontFamily: "sans-serif",
                            iconFontFamily: "sans-serif",
                            styleRegular: "Regular"
                        }
                    })
        }
    }

    SignalSpy {
        id: primarySpy
        signalName: "primaryActionRequested"
    }

    SignalSpy {
        id: forgetSpy
        signalName: "forgetRequested"
    }

    function createRow(properties) {
        const row = createTemporaryObject(rowComponent, testCase, properties || {})
        verify(row !== null)
        primarySpy.target = row
        forgetSpy.target = row
        primarySpy.clear()
        forgetSpy.clear()
        return row
    }

    function test_compactMetadataAndDefinedRadius() {
        const row = createRow()
        const metadata = findChild(row, "wifiNetworkMeta")
        compare(metadata.text, "Open · 80%")
        compare(row.radius, 12)
    }

    function test_hiddenForgetDoesNotReserveSpace() {
        const row = createRow({
                                  network: {
                                      name: "Open network",
                                      connected: false,
                                      known: false,
                                      stateChanging: false,
                                      signalStrength: 0.5,
                                      security: 0
                                  }
                              })
        const details = findChild(row, "networkDetails")
        const forget = findChild(row, "forgetAction")
        compare(forget.visible, false)
        compare(forget.width, 0)
        verify(details.width > 0, "details should retain space beside Connect")
    }

    function test_nullNetworkRendersSafely() {
        const row = createRow({
                                  network: null
                              })
        const metadata = findChild(row, "wifiNetworkMeta")
        compare(metadata.text, "")
        compare(findChild(row, "primaryAction").enabled, false)
    }

    function test_primaryActionLabelTracksConnectionState() {
        const disconnected = createRow()
        compare(findChild(disconnected, "primaryActionLabel").text, "Connect")

        const connected = createRow({
                                        network: {
                                            name: "Connected",
                                            connected: true,
                                            known: true,
                                            stateChanging: false,
                                            signalStrength: 1,
                                            security: 2
                                        }
                                    })
        compare(findChild(connected, "primaryActionLabel").text, "Disconnect")
        compare(findChild(connected, "forgetAction").visible, false)
    }

    function test_metadataElidesWithinAvailableSpace() {
        const row = createRow({
                                  width: 180
                              })
        const details = findChild(row, "networkDetails")
        const metadata = findChild(row, "wifiNetworkMeta")
        compare(metadata.width, details.width)
        compare(metadata.elide, Text.ElideRight)
    }

    function test_stateChangingDisablesPrimaryAction() {
        const row = createRow({
                                  network: {
                                      name: "Changing",
                                      connected: false,
                                      known: true,
                                      stateChanging: true,
                                      signalStrength: 0.5,
                                      security: 2
                                  }
                              })
        compare(findChild(row, "primaryActionLabel").text, "Please wait…")
        compare(findChild(row, "primaryAction").enabled, false)
    }

    function test_actionsAreIndependent() {
        const row = createRow()

        row.requestPrimaryAction()
        compare(primarySpy.count, 1)
        compare(forgetSpy.count, 0)

        row.requestForget()
        compare(primarySpy.count, 1)
        compare(forgetSpy.count, 1)
    }

    function test_pointerHitAreasAreIndependent() {
        const row = createRow()
        const primary = findChild(row, "primaryAction")
        const forget = findChild(row, "forgetAction")
        const primaryButton = findChild(row, "primaryActionButton")
        const forgetInput = findChild(row, "forgetInput")
        verify(primary !== null)
        verify(primaryButton !== null)
        verify(forget !== null)
        verify(forgetInput !== null)
        tryCompare(primary, "enabled", true)
        verify(primary.width > 0 && primary.height > 0, `primary size ${primary.width}x${primary.height}`)
        verify(forget.width > 0 && forget.height > 0, `forget size ${forget.width}x${forget.height}`)
        verify(primaryButton.x + primaryButton.width <= forget.x, "Connect must stop before Forget")

        primary.clicked(null)
        compare(primarySpy.count, 1)
        compare(forgetSpy.count, 0)

        forgetInput.clicked(null)
        compare(primarySpy.count, 1)
        compare(forgetSpy.count, 1)
    }

    function test_keyboardActionsAreIndependent() {
        const row = createRow()
        const primary = findChild(row, "primaryAction")
        const forget = findChild(row, "forgetInput")

        primary.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(primarySpy.count, 1)
        compare(forgetSpy.count, 0)

        forget.forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(primarySpy.count, 1)
        compare(forgetSpy.count, 1)
    }

    function test_forgetRequiresSavedIdleNetwork() {
        const connected = createRow({
                                        network: {
                                            name: "Connected",
                                            connected: true,
                                            known: true,
                                            stateChanging: false,
                                            signalStrength: 1
                                        }
                                    })
        connected.requestForget()
        compare(forgetSpy.count, 0)

        const changing = createRow({
                                       network: {
                                           name: "Changing",
                                           connected: false,
                                           known: true,
                                           stateChanging: true,
                                           signalStrength: 0.5
                                       }
                                   })
        changing.requestPrimaryAction()
        changing.requestForget()
        compare(primarySpy.count, 0)
        compare(forgetSpy.count, 0)
    }
}
