//@ pragma UseQApplication

import QtQuick
import Quickshell
import "../services" as Services
import "../theme" as Theme

ShellRoot {
    id: shell

    Theme.Theme { id: colors }
    Services.Services { id: serviceState }

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
