import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Row {
    required property var palette
    required property var barWindow

    spacing: 10
    visible: SystemTray.items.values.length > 0
    height: 30

    Repeater {
        model: SystemTray.items

        IconImage {
            required property var modelData

            width: 24
            height: 30
            implicitSize: 24
            source: modelData.icon

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                        const position = mapToItem(null, mouse.x, mouse.y)
                        modelData.display(barWindow, position.x, position.y)
                    } else if (mouse.button === Qt.MiddleButton)
                        modelData.secondaryActivate()
                    else
                        modelData.activate()
                }
            }
        }
    }
}
