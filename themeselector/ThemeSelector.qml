import "../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: selector

    readonly property var theme: AppTheme {}
    readonly property var themes: StockThemes.availableThemes
    property alias visible: panel.visible
    property bool quitOnClose: false
    property int selectedIndex: 0
    readonly property var contentItem: contentLoader.item

    function themeCardHeight() {
        const nameLineHeight = theme.typography.sizeMd + theme.spacing.space4
        return theme.spacing.appLauncherCardPadding * 2
            + theme.typography.actionIconFontSize
            + theme.spacing.appLauncherCardSpacing
            + nameLineHeight
    }

    function open() {
        if (selectedIndex !== 0)
            selectedIndex = 0
        panel.visible = true
    }

    function close() {
        panel.visible = false

        if (quitOnClose)
            Qt.quit()
    }

    function toggle() {
        panel.visible ? close() : open()
    }

    function moveSelection(direction) {
        selectIndex(selectedIndex + direction)
    }

    function selectIndex(index) {
        const count = themes.length
        if (count === 0)
            return

        const nextIndex = Math.max(0, Math.min(count - 1, index))
        const selectionChanged = selectedIndex !== nextIndex

        if (selectionChanged)
            selectedIndex = nextIndex
        if (selectionChanged && contentItem && contentItem.themeGridView)
            contentItem.themeGridView.positionViewAtIndex(nextIndex, GridView.Contain)
    }

    function currentThemeData() {
        for (const themeData of themes) {
            if (themeData.name === theme.colors.currentTheme)
                return themeData
        }
        return themes[0]
    }

    function applySelection() {
        const selectedTheme = themes[selectedIndex]
        if (!selectedTheme)
            return

        theme.colors.setTheme(selectedTheme.name)
        close()
    }

    function activateIndex(index) {
        selectIndex(index)
        applySelection()
    }

    function selectTheme(name) {
        theme.colors.setTheme(name)
    }

    function handleNavigationKey(event) {
        if (event.key === Qt.Key_Home) {
            selectIndex(0)
            event.accepted = true
        } else if (event.key === Qt.Key_End) {
            selectIndex(themes.length - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            applySelection()
            event.accepted = true
        } else {
            event.accepted = false
        }
    }

    onThemesChanged: {
        const maxIndex = Math.max(0, themes.length - 1)
        const nextSelectedIndex = Math.max(0, Math.min(selectedIndex, maxIndex))

        if (selectedIndex !== nextSelectedIndex)
            selectedIndex = nextSelectedIndex
    }

    Component {
        id: selectorContent

        Column {
            property alias themeGridView: themeGrid

            anchors.fill: parent
            anchors.margins: selector.theme.spacing.wallpaperSelectorGridMargin
            spacing: selector.theme.spacing.appLauncherSectionSpacing

            Rectangle {
                id: preview

                readonly property var themeData: selector.currentThemeData()
                readonly property var previewColors: themeData && themeData.previewColors ? themeData.previewColors : []
                readonly property int preferredHeight: Math.round(width * 9 / 16)
                readonly property int minimumGridHeight: selector.themeCardHeight() + selector.theme.spacing.space12
                readonly property int semanticBorderWidth: selector.theme.shape.wallpaperSelectorBorderWidth

                width: parent.width
                height: Math.min(preferredHeight, Math.max(0, parent.height - parent.spacing - minimumGridHeight))
                radius: selector.theme.shape.wallpaperCardRadius
                color: themeData && themeData.background ? themeData.background : selector.theme.colors.background
                clip: true

                Item {
                    id: applicationFrame

                    readonly property real scaleFactor: Math.max(0.65, Math.min(1, width / 400, height / 208))
                    readonly property color frameBackground: preview.themeData && preview.themeData.background ? preview.themeData.background : "#181825"
                    readonly property color frameSurface: preview.themeData && preview.themeData.surface ? preview.themeData.surface : frameBackground
                    readonly property color frameText: preview.themeData && preview.themeData.text ? preview.themeData.text : "#cdd6f4"
                    readonly property color accent: preview.themeData && preview.themeData.primary ? preview.themeData.primary : frameText
                    readonly property color secondaryAccent: preview.themeData && preview.themeData.secondary ? preview.themeData.secondary : accent

                    anchors.fill: parent
                    anchors.margins: preview.semanticBorderWidth

                    Rectangle {
                        id: titleBar

                        width: parent.width
                        height: Math.max(24, Math.round(parent.height * 0.16))
                        radius: Math.max(0, preview.radius - preview.semanticBorderWidth)
                        color: applicationFrame.frameSurface

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            height: parent.radius
                            color: parent.color
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(12 * applicationFrame.scaleFactor)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.max(4, Math.round(6 * applicationFrame.scaleFactor))

                            Repeater {
                                model: preview.previewColors.slice(0, 3)

                                Rectangle {
                                    required property color modelData

                                    width: Math.max(9, Math.round(12 * applicationFrame.scaleFactor))
                                    height: width
                                    radius: width / 2
                                    color: modelData
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            width: parent.width * 0.48
                            text: preview.themeData ? preview.themeData.displayName : "Theme"
                            color: applicationFrame.frameText
                            opacity: 0.72
                            font.family: selector.theme.typography.textFontFamily
                            font.pixelSize: selector.theme.typography.sizeMd
                            font.styleName: selector.theme.typography.styleMedium
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        anchors.top: titleBar.bottom
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left

                        Rectangle {
                            id: navigationRail

                            width: Math.max(30, Math.round(parent.width * 0.11))
                            height: parent.height
                            radius: Math.max(0, preview.radius - preview.semanticBorderWidth)
                            color: applicationFrame.frameSurface

                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: parent.radius
                                color: parent.color
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.left: parent.left
                                height: parent.radius
                                color: parent.color
                            }

                            Column {
                                anchors.top: parent.top
                                anchors.topMargin: Math.round(8 * applicationFrame.scaleFactor)
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Math.max(3, Math.round(5 * applicationFrame.scaleFactor))

                                Repeater {
                                    model: ["", "", "", ""]

                                    Rectangle {
                                        required property string modelData
                                        required property int index

                                        width: Math.max(22, Math.round(navigationRail.width * 0.72))
                                        height: width
                                        radius: Math.max(selector.theme.shape.radius3, Math.round(6 * applicationFrame.scaleFactor))
                                        color: index === 0 ? applicationFrame.accent : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: index === 0 ? applicationFrame.frameBackground : applicationFrame.frameText
                                            opacity: index === 0 ? 1 : 0.48
                                            font.family: selector.theme.typography.iconFontFamily
                                            font.pixelSize: Math.max(9, Math.round(selector.theme.typography.sizeMd * applicationFrame.scaleFactor))
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            id: editorPane

                            anchors.top: parent.top
                            anchors.right: sidePanel.left
                            anchors.bottom: parent.bottom
                            anchors.left: navigationRail.right

                            Column {
                                anchors.fill: parent
                                anchors.margins: Math.max(8, Math.round(14 * applicationFrame.scaleFactor))
                                spacing: Math.max(5, Math.round(8 * applicationFrame.scaleFactor))

                                Repeater {
                                    model: [
                                        { indent: 0.00, width: 0.72, color: applicationFrame.accent },
                                        { indent: 0.08, width: 0.86, color: applicationFrame.frameText },
                                        { indent: 0.15, width: 0.58, color: applicationFrame.secondaryAccent },
                                        { indent: 0.15, width: 0.76, color: preview.previewColors[2] || applicationFrame.accent },
                                        { indent: 0.08, width: 0.64, color: applicationFrame.frameText },
                                        { indent: 0.00, width: 0.46, color: preview.previewColors[3] || applicationFrame.secondaryAccent }
                                    ]

                                    Item {
                                        required property var modelData

                                        width: parent.width
                                        height: Math.max(5, Math.round(7 * applicationFrame.scaleFactor))

                                        Rectangle {
                                            x: parent.width * modelData.indent
                                            width: Math.min(parent.width - x, parent.width * modelData.width)
                                            height: parent.height
                                            radius: height / 2
                                            color: modelData.color
                                            opacity: modelData.color === applicationFrame.frameText ? 0.34 : 0.82
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: sidePanel

                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: Math.max(68, parent.width * 0.24)
                            radius: Math.max(0, preview.radius - preview.semanticBorderWidth)
                            color: applicationFrame.frameSurface

                            Rectangle {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                width: parent.radius
                                color: parent.color
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.left: parent.left
                                height: parent.radius
                                color: parent.color
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: Math.max(7, Math.round(11 * applicationFrame.scaleFactor))
                                spacing: Math.max(6, Math.round(9 * applicationFrame.scaleFactor))

                                Repeater {
                                    model: [0.82, 0.58, 0.72, 0.46, 0.66]

                                    Rectangle {
                                        required property real modelData

                                        width: parent.width * modelData
                                        height: Math.max(5, Math.round(7 * applicationFrame.scaleFactor))
                                        radius: height / 2
                                        color: applicationFrame.frameText
                                        opacity: 0.16
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    z: 1
                    radius: preview.radius
                    color: "transparent"
                    border.width: preview.semanticBorderWidth
                    border.color: preview.themeData && preview.themeData.border ? preview.themeData.border : selector.theme.colors.border
                }
            }

            GridView {
                id: themeGrid

                readonly property int columns: 2
                readonly property int cardHeight: selector.themeCardHeight()

                width: parent.width
                height: Math.max(0, parent.height - preview.height - parent.spacing)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flow: GridView.FlowLeftToRight
                cellWidth: width / columns
                cellHeight: cardHeight + selector.theme.spacing.space12
                model: selector.themes
                currentIndex: selector.selectedIndex
                highlightFollowsCurrentItem: false

                Text {
                    anchors.centerIn: parent
                    visible: selector.themes.length === 0
                    width: parent.width - selector.theme.spacing.wallpaperSelectorEmptyTextHorizontalMargin
                    text: "No themes found"
                    color: selector.theme.colors.textMuted
                    font.pixelSize: selector.theme.typography.sizeLg
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: themeGrid.cellWidth
                    height: themeGrid.cellHeight

                    ThemeCard {
                        anchors.centerIn: parent
                        width: parent.width - selector.theme.spacing.space12
                        height: themeGrid.cardHeight
                        themeData: modelData
                        selected: selector.selectedIndex === index
                        onActivated: selector.activateIndex(index)
                    }
                }
            }
        }
    }

    PanelWindow {
        id: panel

        visible: false
        aboveWindows: true
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        mask: null
        color: selector.theme.colors.transparent
        surfaceFormat.opaque: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        Rectangle {
            anchors.fill: parent
            color: selector.theme.colors.scrim
            focus: true

            Keys.onEscapePressed: selector.close()
            Keys.onLeftPressed: selector.moveSelection(-1)
            Keys.onRightPressed: selector.moveSelection(1)
            Keys.onUpPressed: selector.moveSelection(-2)
            Keys.onDownPressed: selector.moveSelection(2)
            Keys.onReturnPressed: selector.applySelection()
            Keys.onEnterPressed: selector.applySelection()
            Keys.onPressed: (event) => selector.handleNavigationKey(event)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: selector.close()
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - selector.theme.spacing.wallpaperSelectorScreenMargin, selector.theme.sizing.appLauncherMaxWidth)
                height: Math.min(parent.height - selector.theme.spacing.wallpaperSelectorScreenMargin, selector.theme.sizing.appLauncherMaxHeight)
                radius: selector.theme.shape.wallpaperSelectorRadius
                color: selector.theme.colors.panel
                border.width: selector.theme.shape.wallpaperSelectorBorderWidth
                border.color: selector.theme.colors.border

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Loader {
                    id: contentLoader

                    anchors.fill: parent
                    active: panel.visible
                    sourceComponent: selectorContent
                }
            }
        }
    }
}
