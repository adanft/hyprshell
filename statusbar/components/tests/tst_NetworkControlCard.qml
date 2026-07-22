import QtQuick
import QtTest
import ".."

TestCase {
    id: testCase
    name: "NetworkControlCard"
    when: windowShown
    width: 320
    height: 160

    Component {
        id: cardComponent

        NetworkControlCard {
            width: 200
            height: 54
            colors: ({
                surface: "#202020",
                surfaceHover: "#303030",
                primary: "#88aaff",
                border: "#555555",
                text: "#ffffff",
                textMuted: "#aaaaaa",
                textSubtle: "#888888",
                background: "#101010"
            })
            theme: ({
                shape: { radius12: 12, borderMedium: 2, borderThin: 1 },
                spacing: { space8: 8, space6: 6, space2: 2 },
                typography: { sizeSm: 11, textFontFamily: "sans-serif" }
            })
            icon: "N"
            title: "Network"
            subtitle: "Disconnected"
        }
    }

    SignalSpy {
        id: bodySpy
        signalName: "bodyClicked"
    }

    SignalSpy {
        id: toggleSpy
        signalName: "toggled"
    }

    function createCard(properties) {
        const card = createTemporaryObject(cardComponent, testCase, properties || {});
        verify(card !== null);
        bodySpy.target = card;
        toggleSpy.target = card;
        bodySpy.clear();
        toggleSpy.clear();
        return card;
    }

    function test_bodyAndToggleActionsAreIndependent() {
        const card = createCard();

        card.requestBodyAction();
        compare(bodySpy.count, 1);
        compare(toggleSpy.count, 0);

        card.requestToggleAction();
        compare(bodySpy.count, 1);
        compare(toggleSpy.count, 1);
    }

    function test_unavailableOrBusyToggleDoesNothing() {
        const unavailable = createCard({ available: false });
        unavailable.requestToggleAction();
        compare(toggleSpy.count, 0);

        const busy = createCard({ busy: true });
        busy.requestToggleAction();
        compare(toggleSpy.count, 0);
    }

    function test_bodyRemainsAvailableWhenToggleIsUnavailable() {
        const card = createCard({ available: false });

        card.requestBodyAction();
        compare(bodySpy.count, 1);
        compare(toggleSpy.count, 0);
    }
}
