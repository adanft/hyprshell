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
                signalStrength: 0.8
            })
            colors: ({
                surfaceHover: "#303030",
                transparent: "transparent",
                primary: "#88aaff",
                text: "#ffffff",
                textMuted: "#aaaaaa",
                danger: "#ff7777"
            })
            theme: ({
                shape: { radius6: 6 },
                spacing: { space12: 12, space8: 8, space2: 2 },
                sizing: { statusBarTrayMenuItemHeight: 36 },
                typography: { sizeSm: 11, textFontFamily: "sans-serif", iconFontFamily: "sans-serif" }
            })
            icons: ({ wifiConnected: "C", wifiDisconnected: "D" })
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
        const row = createTemporaryObject(rowComponent, testCase, properties || {});
        verify(row !== null);
        primarySpy.target = row;
        forgetSpy.target = row;
        primarySpy.clear();
        forgetSpy.clear();
        return row;
    }

    function test_actionsAreIndependent() {
        const row = createRow();

        row.requestPrimaryAction();
        compare(primarySpy.count, 1);
        compare(forgetSpy.count, 0);

        row.requestForget();
        compare(primarySpy.count, 1);
        compare(forgetSpy.count, 1);
    }

    function test_pointerHitAreasAreIndependent() {
        const row = createRow();
        const primary = findChild(row, "primaryAction");
        const forget = findChild(row, "forgetAction");
        const forgetInput = findChild(row, "forgetInput");
        verify(primary !== null);
        verify(forget !== null);
        verify(forgetInput !== null);
        tryCompare(primary, "enabled", true);
        verify(primary.width > 0 && primary.height > 0, `primary size ${primary.width}x${primary.height}`);
        verify(forget.width > 0 && forget.height > 0, `forget size ${forget.width}x${forget.height}`);
        verify(primary.width <= row.width - forget.width, "primary hit area must stop before Forget");

        primary.clicked(null);
        compare(primarySpy.count, 1);
        compare(forgetSpy.count, 0);

        forgetInput.clicked(null);
        compare(primarySpy.count, 1);
        compare(forgetSpy.count, 1);
    }

    function test_keyboardActionsAreIndependent() {
        const row = createRow();
        const primary = findChild(row, "primaryAction");
        const forget = findChild(row, "forgetInput");

        primary.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(primarySpy.count, 1);
        compare(forgetSpy.count, 0);

        forget.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(primarySpy.count, 1);
        compare(forgetSpy.count, 1);
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
        });
        connected.requestForget();
        compare(forgetSpy.count, 0);

        const changing = createRow({
            network: {
                name: "Changing",
                connected: false,
                known: true,
                stateChanging: true,
                signalStrength: 0.5
            }
        });
        changing.requestPrimaryAction();
        changing.requestForget();
        compare(primarySpy.count, 0);
        compare(forgetSpy.count, 0);
    }
}
