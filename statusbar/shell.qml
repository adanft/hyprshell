//@ pragma UseQApplication

import "../services" as Services
import "../theme" as Theme
import QtQuick
import Quickshell

ShellRoot {
    id: shell

    Theme.Colors {
        id: themeColors
    }

    Services.Services {
        id: serviceState
    }

    Variants {
        model: Quickshell.screens

        BarWindow {
            required property var modelData

            screen: modelData
            colors: themeColors
            services: serviceState
        }

    }

}
