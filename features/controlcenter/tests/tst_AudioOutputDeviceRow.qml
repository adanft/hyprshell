import QtQuick
import QtTest
import "../components"
import "../../../theme"

TestCase {
    id: testCase
    name: "AudioOutputDeviceRow"
    when: windowShown
    width: 400
    height: 120
    property var node: ({
                            nickname: "Desk speakers",
                            audio: {
                                muted: false
                            }
                        })
    Component {
        id: component
        AudioOutputDeviceRow {
            width: 380
            device: testCase.node
            icon: "O"
            theme: testCase.theme
        }
    }
    property var theme: ({
                             motion: {
                                 opacityDisabled: 0.5
                             },
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
                                 statusBarNetworkDeviceRowHeight: 48,
                                 statusBarTrayMenuItemHeight: 36,
                                 statusBarControlActionHeight: 28,
                                 statusBarNetworkQuickControlIconWidth: 22
                             },
                             typography: {
                                 textBase: 16,
                                 textMd: 14,
                                 textSm: 11,
                                 textFontFamily: "sans",
                                 iconFontFamily: "sans"
                             }
                         })
    SignalSpy {
        id: spy
        signalName: "selectRequested"
    }
    function row(properties) {
        const value = createTemporaryObject(component, testCase, properties || {})
        verify(value)
        spy.target = value
        spy.clear()
        return value
    }
    function test_selectionUsesIdentity() {
        const value = row()
        value.requestSelect()
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], node)
    }
    function test_activeAndUnavailableAreSafe() {
        let value = row({
                            active: true
                        })
        value.requestSelect()
        compare(spy.count, 0)
        value = row({
                        available: false
                    })
        value.requestSelect()
        compare(spy.count, 0)
    }
    function test_keyboardActivation() {
        const value = row()
        const input = findChild(value, "audioOutputDeviceAction")
        verify(input)
        input.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(spy.count, 1)
    }
}
