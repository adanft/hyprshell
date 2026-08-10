import QtQuick
import QtTest
import "../components"
import "../../../theme"

TestCase {
    id: testCase
    name: "MicrophoneSourceRow"
    when: windowShown
    width: 400
    height: 120

    Component {
        id: rowComponent

        MicrophoneSourceRow {
            width: 380
            source: ({
                         nickname: "Studio Mic",
                         audio: {
                             muted: false
                         }
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
                            space6: 6,
                            space2: 2
                        },
                        sizing: {
                            statusBarTrayMenuItemHeight: 36,
                            statusBarControlActionHeight: 28,
                            statusBarNetworkDeviceRowHeight: 48,
                            statusBarNetworkQuickControlIconWidth: 22
                        },
                        typography: {
                            textMd: 14,
                            textSm: 11,
                            textBase: 16,
                            textFontFamily: "sans-serif",
                            iconFontFamily: "Symbols Nerd Font",
                            styleRegular: "Regular"
                        }
                    })
            icon: "M"
        }
    }

    SignalSpy {
        id: selectSpy
        signalName: "selectRequested"
    }

    function createRow(properties) {
        const row = createTemporaryObject(rowComponent, testCase, properties || {})
        verify(row !== null)
        selectSpy.target = row
        selectSpy.clear()
        return row
    }

    function test_inactiveSourceRequestsSelection() {
        const row = createRow({
                                  active: false
                              })
        row.requestSelect()
        compare(selectSpy.count, 1)
    }

    function test_activeSourceSuppressesSelection() {
        const row = createRow({
                                  active: true
                              })
        row.requestSelect()
        compare(selectSpy.count, 0)
    }

    function test_keyboardRoutesSelection() {
        const row = createRow({
                                  active: false
                              })
        const input = findChild(row, "microphoneSourceAction")
        verify(input !== null)
        input.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(selectSpy.count, 1)
    }
}
