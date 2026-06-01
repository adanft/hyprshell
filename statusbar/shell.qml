//@ pragma UseQApplication

import QtQuick
import Quickshell

ShellRoot {
    id: shell

    Theme { id: colors }
    Services { id: serviceState }

    Variants {
        model: Quickshell.screens

        BarWindow {
            required property var modelData

            screen: modelData
            palette: colors
            services: serviceState
        }
    }
}
