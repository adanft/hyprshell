//@ pragma UseQApplication

import "../services" as Services
import "../theme" as Theme
import QtQuick
import Quickshell

ShellRoot {
    id: shell

    Theme.Theme {
        id: colors
    }

    Services.Services {
        id: serviceState
    }

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
