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

    width: label.implicitWidth + theme.spacing.space16
    height: theme.sizing.statusBarTrayMenuItemHeight - theme.spacing.space8
    radius: theme.shape.radius8
    color: input.containsMouse || input.activeFocus ? colors.surfaceHover : colors.transparent
    opacity: available ? 1 : 0.45

    Accessible.role: Accessible.Button
    Accessible.name: discovering ? "Stop Bluetooth scan" : "Scan for Bluetooth devices"
    Accessible.description: available ? "" : "Bluetooth must be enabled before scanning"

    Text {
        id: label
        anchors.centerIn: parent
        text: root.discovering ? "Stop" : "Scan"
        color: root.available ? root.colors.primary : root.colors.textSubtle
        font.family: root.theme.typography.textFontFamily
        font.styleName: root.theme.typography.styleRegular
        font.pixelSize: root.theme.typography.sizeSm
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.color: root.colors.primary
        border.width: input.activeFocus ? 2 : 0
    }

    MouseArea {
        id: input
        objectName: "bluetoothScanInput"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.available
        activeFocusOnTab: enabled
        onClicked: root.toggleScan()
        Keys.onSpacePressed: root.toggleScan()
        Keys.onReturnPressed: root.toggleScan()
        Keys.onEnterPressed: root.toggleScan()
    }
}
