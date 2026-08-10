pragma Singleton
import QtQuick

// Every glyph the shell paints, grouped by what it depicts.
//
// Not by which feature draws it: sixteen of these are used by more than one, and
// search by four. Owning an icon per feature would mean either copying the glyph
// — and letting the copies drift — or picking a first owner and having the rest
// reach across for it. What a thing looks like is stable; who happens to draw it
// today is not.
QtObject {
    readonly property QtObject network: QtObject {
        readonly property string throughput: ""
        readonly property string ethernetPort: "󰈀"
        readonly property string ethernet: "󰈁"
        readonly property string ethernetDisconnected: "󰈂"
        readonly property string wifiInterface: "󰩩"
        readonly property string wifiConnected: "󰤨"
        readonly property string wifiEnabled: "󰤯"
        readonly property string wifiDisconnected: "󰤭"
    }

    readonly property QtObject bluetooth: QtObject {
        readonly property string on: "󰂯"
        readonly property string off: "󰂲"
        readonly property string connected: "󰂱"
        readonly property string adapter: ""
    }

    readonly property QtObject audio: QtObject {
        readonly property string microphone: ""
        readonly property string microphoneMuted: ""
        readonly property string output: "󰓃"
        readonly property string stream: "󰎆"
        readonly property string volumeUnavailable: "󰖁"
        readonly property string volumeMuted: ""
        readonly property string volumeLow: ""
        readonly property string volumeMedium: ""
        readonly property string volumeHigh: ""
    }

    readonly property QtObject display: QtObject {
        readonly property string brightness: "󰌵"
        // Nine steps, dimmest first. Indexed by level, so the order is the API.
        readonly property var backlightLevels: ["", "", "", "", "", "", "", "", ""]
    }

    readonly property QtObject battery: QtObject {
        // Nine steps, emptiest first, indexed the same way as backlightLevels.
        readonly property var levels: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂"]
        readonly property string full: "󱃌"
        readonly property string warning: "󰂃"
        readonly property string critical: "󱃍"
        readonly property string charging: "󱘖"
        readonly property string unknown: "󰂑"
    }

    readonly property QtObject powerProfile: QtObject {
        readonly property string performance: "󱠇"
        readonly property string balanced: "󰚀"
        readonly property string saver: "󱤆"
    }

    readonly property QtObject session: QtObject {
        readonly property string lock: ""
        readonly property string suspend: ""
        readonly property string logout: ""
        readonly property string reboot: ""
        readonly property string powerOff: ""
    }

    readonly property QtObject notification: QtObject {
        readonly property string bell: "󰂚"
        readonly property string bellEmpty: "󰂜"
        readonly property string doNotDisturb: "󰂛"
        readonly property string clear: " "
    }

    readonly property QtObject system: QtObject {
        readonly property string processor: "󰓅"
        readonly property string memory: "󰍛"
        readonly property string clock: "󱑂"
        readonly property string calendar: "󰨳"
        readonly property string window: "󰰤"
        readonly property string controlCentre: ""
    }

    readonly property QtObject capture: QtObject {
        readonly property string allScreens: "󰍺"
        readonly property string monitor: "󰍹"
        readonly property string window: ""
        readonly property string area: "󰆞"
    }

    readonly property QtObject appearance: QtObject {
        readonly property string dark: ""
        readonly property string light: ""
    }

    readonly property QtObject fileFormat: QtObject {
        readonly property string png: "󰵸"
        readonly property string jpg: "󰈥"
        readonly property string gif: "󰸭"
    }

    // Shape-named rather than named for a caller: a chevron pointing right is
    // the same chevron whether it opens a tray submenu or anything else. The
    // tray's back arrow and the wallpaper grid's tick used to be spelled twice,
    // and the two ticks were the same glyph under two names.
    readonly property QtObject ui: QtObject {
        readonly property string search: ""
        readonly property string close: "󰅖"
        readonly property string trash: ""
        readonly property string confirm: ""
        readonly property string cancel: ""
        readonly property string check: "✓"
        readonly property string chevronUp: "󰅃"
        readonly property string chevronDown: "󰅀"
        readonly property string chevronLeft: "‹"
        readonly property string chevronRight: "›"
        readonly property string passwordHidden: "󰈈"
        readonly property string passwordVisible: "󰈉"
        readonly property string dot: ""
        readonly property string bullet: "•"
        readonly property string timer: ""
        readonly property string cursor: ""
    }
}
