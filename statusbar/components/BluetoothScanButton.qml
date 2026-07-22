import QtQuick

Rectangle {
    id: root
    required property var colors
    required property var theme
    property bool discovering: false
    property bool available: true
    signal scanToggled(bool discovering)

    function toggleScan() {
        if (available)
            scanToggled(!discovering);
    }

    width: 58
    height: theme.sizing.statusBarTrayMenuItemHeight - theme.spacing.space6
    radius: theme.shape.radius6
    color: input.containsMouse || input.activeFocus ? colors.surfaceHover : colors.surface
    opacity: available ? 1 : 0

    Accessible.role: Accessible.Button
    Accessible.name: discovering ? "Stop Bluetooth scan" : "Scan for Bluetooth devices"
    Accessible.ignored: !available

    Text {
        anchors.centerIn: parent
        text: root.discovering ? "Stop" : "Scan"
        color: root.colors.text
        font.family: root.theme.typography.textFontFamily
        font.pixelSize: root.theme.typography.sizeSm
    }

    MouseArea {
        id: input
        objectName: "bluetoothScanInput"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.available
        activeFocusOnTab: enabled
        onClicked: root.toggleScan()
        Keys.onSpacePressed: root.toggleScan()
        Keys.onReturnPressed: root.toggleScan()
        Keys.onEnterPressed: root.toggleScan()
    }
}
