import QtQuick
import QtTest
import ".."

TestCase {
    id: testCase
    name: "BluetoothScanButton"
    when: windowShown
    width: 120
    height: 80

    Component {
        id: buttonComponent
        BluetoothScanButton {
            colors: ({ surface: "#202020", surfaceHover: "#303030", text: "#ffffff" })
            theme: ({
                shape: { radius6: 6 },
                spacing: { space6: 6 },
                sizing: { statusBarTrayMenuItemHeight: 36 },
                typography: { sizeSm: 11, textFontFamily: "sans-serif" }
            })
        }
    }

    SignalSpy { id: toggleSpy; signalName: "scanToggled" }

    function createButton(properties) {
        const button = createTemporaryObject(buttonComponent, testCase, properties || {});
        verify(button !== null);
        toggleSpy.target = button;
        toggleSpy.clear();
        return button;
    }

    function test_toggleRequestsOppositeState() {
        const start = createButton({ discovering: false });
        start.toggleScan();
        compare(toggleSpy.count, 1);
        compare(toggleSpy.signalArguments[0][0], true);

        const stop = createButton({ discovering: true });
        stop.toggleScan();
        compare(toggleSpy.count, 1);
        compare(toggleSpy.signalArguments[0][0], false);
    }

    function test_unavailableSuppressesAction() {
        const button = createButton({ available: false });
        button.toggleScan();
        compare(toggleSpy.count, 0);
    }

    function test_keyboardRoutesToggle() {
        const button = createButton();
        const input = findChild(button, "bluetoothScanInput");
        verify(input !== null);
        input.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(toggleSpy.count, 1);
        compare(toggleSpy.signalArguments[0][0], true);
    }
}
