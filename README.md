# qsrice

A Wayland desktop shell for Hyprland, written in QML on top of
[Quickshell](https://quickshell.org): status bar, app launcher, control centre,
notification centre, screenshot tool, wallpaper and theme selectors, and a power
menu — plus a theme that follows through to Hyprland, hyprlock and Ghostty.

Everything below was read out of this repository rather than remembered. Package
names are Arch's, because that is where it was built and tested; the binaries are
the same everywhere.

## What it needs

### The two it cannot start without

| | Tested with | Why |
|---|---|---|
| **Hyprland** | 0.56.2 | The shell talks to it over its IPC, and the launch hook lives in `hyprland.lua`. The Lua config format arrived in 0.55 — an older Hyprland needs `hyprland.conf` instead. |
| **Quickshell** (`qs`) | 0.3.0 (`quickshell-git`) | The runtime. Pulls Qt 6 with it (built here against 6.11.1). |

```sh
pacman -S hyprland
# quickshell-git is in the AUR
paru -S quickshell-git
```

### Fonts

The icons are not an image set — every glyph in `theme/Icons.qml` is a Nerd Font
codepoint. Without the font they render as empty boxes, and the bar looks broken
rather than unstyled.

```sh
pacman -S ttf-nerd-fonts-symbols   # "Symbols Nerd Font"
```

Body text is set in **SF Pro Display**, named in `theme/Typography.qml`. It is not
in the repositories — install it yourself, or change that one line to a face you
have. Qt will substitute silently if it is missing, so nothing breaks; it just
stops looking the way it was drawn.

### Desktop services

These back the control centre. Each is reached through a Quickshell module over
D-Bus, so they are daemons to have running, not commands to install.

| Service | Package | Feeds |
|---|---|---|
| NetworkManager | `networkmanager` | Wi-Fi and Ethernet |
| BlueZ | `bluez` `bluez-utils` | Bluetooth |
| PipeWire + WirePlumber | `pipewire` `wireplumber` | volume, output and input devices, per-app streams |
| UPower | `upower` | battery |
| logind | `systemd` | session actions from the power menu |
| AccountsService | `accountsservice` | the user's avatar, read over `busctl`. Without it the avatar is simply empty. |

### Command-line tools, by what stops working

The shell degrades one feature at a time rather than failing to start, so this
table reads as a menu. Only install what you want to use.

| Missing | What you lose |
|---|---|
| `grim` `slurp` `wl-clipboard` `jq` | The screenshot tool. All four are used in one pipeline: `slurp` picks the region, `hyprctl`+`jq` resolve the focused window, `grim` captures, `wl-copy` puts it on the clipboard. |
| `awww` | Applying a wallpaper. The selector still browses and still remembers your choice. |
| `imagemagick` | Wallpaper thumbnails, so the grid falls back to full images. |
| `brightnessctl` | The brightness control, which reports itself unavailable and disappears. |
| `bluez-utils` | Pairing a new device. Devices already paired keep working. |
| `networkmanager` | Connection details — address, profile — while the connection itself is unaffected. |
| `ghostty` and `glib2` | The terminal following the theme. `gapplication` is what tells Ghostty to reload. |
| `hyprlock` | Locking from the power menu. |

```sh
pacman -S grim slurp wl-clipboard jq imagemagick brightnessctl
paru -S awww
```

## Setting it up

### 1. Launch it

The shell is started by the compositor. In `hyprland.lua`:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -p /path/to/qsrice")
end)
```

### 2. Bind the overlays

Nothing opens on its own — each surface is reached over Quickshell's IPC:

```lua
local qsrice = "/path/to/qsrice"
hl.bind("SUPER + D", hl.dsp.exec_cmd("qs ipc -p " .. qsrice .. " call applauncher toggle"))
hl.bind("SUPER + T", hl.dsp.exec_cmd("qs ipc -p " .. qsrice .. " call themeselector toggle"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("qs ipc -p " .. qsrice .. " call wallpaperselector toggle"))
hl.bind("SUPER + X", hl.dsp.exec_cmd("qs ipc -p " .. qsrice .. " call powermenu toggle"))
hl.bind("Print",     hl.dsp.exec_cmd("qs ipc -p " .. qsrice .. " call screenshot toggle"))
```

Every target takes `toggle` and `open`; the theme selector also takes
`set <name>`, which is how a theme can be changed from a script.

### 3. Let Hyprland and hyprlock follow the theme

The shell writes `~/.config/hypr/theme.conf` whenever the theme or the wallpaper
changes. It is the shell's file — it is rewritten whole, so do not edit it — and
it holds colours under role names (`$primary`, `$on_surface`, `$surface`) plus
`$wallpaper` and `$font`.

Both programs read that one file, in the two different ways they each can.

**hyprlock** sources it:

```conf
source = $HOME/.config/hypr/theme.conf

background {
  path  = $wallpaper
  color = $surface
}
label {
  color       = $on_surface
  font_family = $font
}
input-field {
  outer_color = $primary
  inner_color = $surfaceVeil
  fail_color  = $error
}
```

**Hyprland** cannot source hyprlang from Lua, so `hyprland.lua` reads it back:

```lua
local function read_theme()
    local theme = {}
    local file = io.open(os.getenv("HOME") .. "/.config/hypr/theme.conf", "r")
    if not file then return theme end
    for line in file:lines() do
        local name, value = line:match("^%s*%$([%w_]+)%s*=%s*(.-)%s*$")
        if name then theme[name] = value end
    end
    file:close()
    return theme
end

local theme = read_theme()
-- An empty string is truthy in Lua, so `theme[name] or fallback` is not enough.
local function color(name, fallback)
    local value = theme[name]
    if value == nil or value == "" then return fallback end
    return value
end

hl.config({
    general = { col = {
        active_border   = color("primary", "rgb(cba6f7)"),
        inactive_border = color("outline", "rgb(6c7086)"),
    } },
    misc = { background_color = color("shadow", "rgb(1e1e2e)") },
})
```

The shell runs `hyprctl reload` after writing, but only when a colour actually
changed — Hyprland never reads `$wallpaper` or `$font`, so choosing a background
does not make it re-apply monitors, binds and animations.

The variables available are `$primary` `$primaryAlpha` `$secondary` `$error`
`$outline` `$surface` `$surfaceVeil` `$shadow` `$on_surface` `$on_surfaceAlpha`
`$wallpaper` `$font`. The `…Alpha` pair is the bare hex, for pango markup inside
hyprlock's `placeholder_text`, which is a string and cannot take a colour value.

### 4. Ghostty (optional)

If Ghostty is installed, the shell keeps a marked block at the end of
`~/.config/ghostty/config.ghostty` naming a built-in Ghostty theme. Everything
else in that file is left alone.

## Where it keeps things

| Path | What |
|---|---|
| `~/.config/qsrice/settings.json` | Current theme and wallpaper. Migrated from `~/.config/qscomponents/` on first run. |
| `~/.config/hypr/theme.conf` | Generated. Owned by the shell. |
| `~/.config/ghostty/config.ghostty` | A marked block inside your own config. |
| `~/Wallpapers` | Where the selector looks. Override with `AWWW_WALLPAPERS_DIR`. |
| `~/Pictures/Screenshots` | Where captures land. |
| `$XDG_CACHE_HOME/qsrice/wallpapers` | Thumbnails. |
| `$XDG_CACHE_HOME/qsrice/notification-images` | Notification images, so history survives a restart. |

## Working on it

```sh
./run-tests.sh          # everything
./run-tests.sh --js     # Node and Python only, no compositor needed
```

Four stages: Node contract tests, the Python benchmark tests, QML component
tests, then a smoke test that launches the shell and checks every window
instantiated with no warnings. The QML stages need a running compositor and say
so rather than passing quietly when there is none.

Node and Python come from your system; `qmltestrunner` ships with
`qt6-declarative` and is located by `scripts/find-qmltestrunner.sh`, which also
honours `QMLTESTRUNNER` if you want to point it somewhere else.

Layout is vertical: each feature owns its components, sizing and tests under
`features/`, shared pieces live in `shared/`, system access in `services/`, and
the design tokens — colours, typography, spacing, icons, shape, motion — in
`theme/`.

## Known rough edges

- **The first theme change after the shell starts does not persist.** It is
  written as the default instead, and the second change works. Affects every
  theme, including the ones that predate the recent additions.
- **Light themes and the lock screen.** Its labels sit on the wallpaper, and
  `on_surface` is a dark colour in the three light themes, so it disappears over
  a dark photo. There is no role for text over a picture because the shell never
  paints any — the bar sits on opaque `shadow`.
