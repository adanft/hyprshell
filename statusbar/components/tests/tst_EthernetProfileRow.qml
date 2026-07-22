import QtQuick
import QtTest
import ".."

TestCase {
    id: testCase
    name: "EthernetProfileRow"
    when: windowShown
    width: 360
    height: 100

    Component {
        id: rowComponent

        EthernetProfileRow {
            width: 340
            profile: ({ id: "Office LAN", uuid: "profile-1" })
            colors: ({
                transparent: "transparent",
                surface: "#202020",
                surfaceHover: "#303030",
                text: "#ffffff",
                textSubtle: "#aaaaaa",
                primary: "#88aaff",
                danger: "#ff7777"
            })
            theme: ({
                shape: { radius12: 12, radius8: 8, radius6: 6, borderMedium: 2 },
                spacing: { space16: 16, space12: 12, space8: 8, space2: 2 },
                sizing: { statusBarTrayMenuItemHeight: 36 },
                typography: { sizeSm: 11, sizeMd: 14, textFontFamily: "sans-serif" }
            })
        }
    }

    SignalSpy { id: toggleSpy; signalName: "toggleRequested" }

    function createRow(properties) {
        const row = createTemporaryObject(rowComponent, testCase, properties || {});
        verify(row !== null);
        toggleSpy.target = row;
        toggleSpy.clear();
        return row;
    }

    function test_activeProfileRequestsDisable() {
        const row = createRow({ active: true });
        compare(row.border.width, 2);
        compare(row.active, true);
        row.requestToggle();
        compare(toggleSpy.count, 1);
        compare(toggleSpy.signalArguments[0][0].id, "Office LAN");
    }

    function test_inactiveProfileRequestsEnable() {
        const row = createRow({ active: false });
        compare(row.border.width, 0);
        row.requestToggle();
        compare(toggleSpy.count, 1);
    }

    function test_busySuppressesToggleWithoutChangingUnaffectedStatus() {
        const row = createRow({ busy: true });
        const status = findChild(row, "ethernetProfileStatus");
        compare(status.text, "Available");
        row.requestToggle();
        compare(toggleSpy.count, 0);
    }

    function test_pendingProfileShowsWaitingStatus() {
        const row = createRow({ busy: true, pending: true });
        const status = findChild(row, "ethernetProfileStatus");
        compare(status.text, "Please wait…");
    }

    function test_keyboardRoutesToggle() {
        const row = createRow();
        const action = findChild(row, "ethernetProfileAction");
        verify(action !== null);
        action.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(toggleSpy.count, 1);
    }
}
