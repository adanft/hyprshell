import QtQuick
import QtTest
import ".."
TestCase {
    id: testCase
    name: "BluetoothDeviceRow"
    when: windowShown
    width: 400
    height: 120
    Component {
        id: rowComponent
        BluetoothDeviceRow {
            width: 380
            device: ({
                name: "Headphones",
                deviceName: "Headphones",
                paired: true,
                pairing: false,
                connected: false,
                batteryAvailable: false,
                battery: 0
            })
            colors: ({
                transparent: "transparent",
                primary: "#88aaff",
                surface: "#202020",
                surfaceHover: "#303030",
                text: "#ffffff",
                textSubtle: "#aaaaaa",
                danger: "#ff7777"
            })
            theme: ({
                shape: { radius8: 8, radius6: 6 },
                spacing: { space8: 8, space6: 6, space2: 2 },
                sizing: { statusBarTrayMenuItemHeight: 36 },
                typography: { sizeSm: 11, textFontFamily: "sans-serif" }
            })
        }
    }
    SignalSpy { id: primarySpy; signalName: "primaryActionRequested" }
    SignalSpy { id: forgetSpy; signalName: "forgetRequested" }

    function createRow(device) {
        const row = createTemporaryObject(rowComponent, testCase, device ? { device } : {});
        verify(row !== null);
        primarySpy.target = row;
        forgetSpy.target = row;
        primarySpy.clear();
        forgetSpy.clear();
        return row;
    }

    function test_pairedDeviceRoutesConnectAndForgetIndependently() {
        const row = createRow();
        row.requestPrimaryAction();
        compare(primarySpy.count, 1);
        compare(primarySpy.signalArguments[0][0], "connect");
        compare(forgetSpy.count, 0);

        row.requestForget();
        compare(primarySpy.count, 1);
        compare(forgetSpy.count, 1);
    }

    function test_actionTracksDeviceState() {
        const unpaired = createRow({
            name: "Keyboard", paired: false, pairing: false, connected: false,
            batteryAvailable: false, battery: 0
        });
        unpaired.requestPrimaryAction();
        compare(primarySpy.signalArguments[0][0], "pair");
        unpaired.requestForget();
        compare(forgetSpy.count, 0);

        const pairing = createRow({
            name: "Keyboard", paired: false, pairing: true, connected: false,
            batteryAvailable: false, battery: 0
        });
        pairing.requestPrimaryAction();
        compare(primarySpy.signalArguments[0][0], "cancelPair");

        const connected = createRow({
            name: "Keyboard", paired: true, pairing: false, connected: true,
            batteryAvailable: true, battery: 0.5
        });
        connected.requestPrimaryAction();
        compare(primarySpy.signalArguments[0][0], "disconnect");
        connected.requestForget();
        compare(forgetSpy.count, 0);
    }

    function test_keyboardInputsUseSeparateSignals() {
        const row = createRow();
        const primary = findChild(row, "bluetoothPrimaryInput");
        const forget = findChild(row, "bluetoothForgetInput");
        verify(primary !== null);
        verify(forget !== null);

        primary.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(primarySpy.count, 1);
        compare(forgetSpy.count, 0);

        forget.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(primarySpy.count, 1);
        compare(forgetSpy.count, 1);
    }
}
