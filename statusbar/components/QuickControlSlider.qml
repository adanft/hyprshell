import QtQuick
import QtQuick.Controls as Controls

Item {
    id: control

    property real value: 0
    property bool available: true
    property int liveUpdateInterval: 75
    property color trackColor: "transparent"
    property color fillColor: "white"
    property color handleColor: "white"
    property color handleBorderColor: "transparent"
    property string unavailableText: "Unavailable"

    readonly property bool interactionActive: draftActive
    readonly property real displayedValue: draftActive ? draftValue : value
    readonly property real visualPosition: Math.max(0, Math.min(1, displayedValue / 100))

    property bool draftActive: false
    property real draftValue: 0

    signal liveValueRequested(int value)
    signal interactionCanceled()

    enabled: available
    opacity: enabled ? 1 : 0.45

    function updateFromPointer(pointerX) {
        const travel = Math.max(1, width - sliderHandle.width);
        const ratio = Math.max(0, Math.min(1, (pointerX - sliderHandle.width / 2) / travel));
        draftValue = Math.round(ratio * 100);
    }

    function beginInteraction(pointerX) {
        draftActive = true;
        updateFromPointer(pointerX);
    }

    function moveInteraction(pointerX) {
        if (draftActive)
            updateFromPointer(pointerX);
    }

    function finishInteraction(pointerX) {
        if (!draftActive)
            return;
        updateFromPointer(pointerX);
        flushDraft();
        draftActive = false;
    }

    function cancelInteraction() {
        if (!draftActive)
            return;
        draftActive = false;
        interactionCanceled();
    }

    function flushDraft() {
        if (draftActive)
            liveValueRequested(Math.round(draftValue));
    }

    Timer {
        interval: control.liveUpdateInterval
        running: control.interactionActive
        repeat: true
        onTriggered: control.flushDraft()
    }

    Controls.ToolTip.visible: pointerArea.containsMouse && !control.enabled
    Controls.ToolTip.text: control.unavailableText

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 5
        radius: height / 2
        color: control.trackColor

        Rectangle {
            width: control.visualPosition <= 0 ? 0 : sliderHandle.x + sliderHandle.width / 2
            height: parent.height
            radius: parent.radius
            color: control.fillColor
        }
    }

    Rectangle {
        id: sliderHandle
        x: control.visualPosition * (control.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: width / 2
        color: control.handleColor
        border.color: control.handleBorderColor
    }

    MouseArea {
        id: pointerArea
        objectName: "pointerArea"
        anchors.fill: parent
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        enabled: control.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: mouse => control.beginInteraction(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                control.moveInteraction(mouse.x);
        }
        onReleased: mouse => control.finishInteraction(mouse.x)
        onCanceled: control.cancelInteraction()
    }
}
