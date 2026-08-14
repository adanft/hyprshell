<div align="center">

# qsrice

**A Wayland desktop shell for Hyprland.**

One process draws your bar, launcher, control centre, notifications, screenshots,
wallpapers and themes — and paints Hyprland, hyprlock and Ghostty to match.

<img alt="Last commit" src="https://img.shields.io/github/last-commit/adanft/qsrice?style=for-the-badge&labelColor=1e1e2e&color=cba6f7">
<img alt="Stars" src="https://img.shields.io/github/stars/adanft/qsrice?style=for-the-badge&labelColor=1e1e2e&color=cba6f7">
<img alt="Repo size" src="https://img.shields.io/github/repo-size/adanft/qsrice?style=for-the-badge&labelColor=1e1e2e&color=cba6f7">
<img alt="Built with QML" src="https://img.shields.io/badge/built%20with-QML-cba6f7?style=for-the-badge&labelColor=1e1e2e">

</div>

<!-- SCREENSHOTS — drop the PNGs into docs/screenshots/ and delete this comment
     wrapper. Suggested set: bar.png, launcher.png, control-centre.png,
     notifications.png, theme-selector.png

<div align="center">
  <img src="docs/screenshots/bar.png" width="90%">
</div>

<details>
<summary><b>More screenshots</b></summary>
<div align="center">
  <img src="docs/screenshots/launcher.png" width="90%">
  <img src="docs/screenshots/control-centre.png" width="90%">
  <img src="docs/screenshots/notifications.png" width="90%">
  <img src="docs/screenshots/theme-selector.png" width="90%">
</div>
</details>
-->

## What this is, and what it isn't

- **It is a shell.** Bar and panels, drawn by Quickshell, in one process.
- **It is not a dotfiles setup.** It does not configure Hyprland for you, install
  drivers, set up your terminal, or take your keybinds. One hook to start it and
  one bind per panel, written by you, is the whole integration.
- **It does not fail when something is missing.** No `brightnessctl`? The
  brightness control reports itself unavailable and disappears. No `awww`? The
  wallpaper selector still browses and still remembers. Every optional piece
  costs exactly one feature, and the table below says which.

## Features

**Status bar.** Workspaces, CPU and RAM, system tray, clock, network throughput,
Wi-Fi, Bluetooth, sound, backlight, battery, microphone, notifications, date.
Four of those modules are shortcuts: clicking Wi-Fi opens the control centre
*already expanded* on Wi-Fi.

**App launcher.** Type to filter desktop entries. The search field never loses
focus, so the arrows move through the grid and the text cursor without you
reaching for anything.

**Control centre.** Wi-Fi, Ethernet, Bluetooth, audio output and microphone, one
section expanded at a time. Connect, forget, switch device, mute a single
application's stream. Wi-Fi scanning is claimed while you are looking and
released when you are not, rather than running forever.

**Notification centre.** History that survives a restart, images included. Do not
disturb, clear all, and per-notification expand.

**Screenshot tool.** All screens, one monitor, the focused window, or a region.
Delay up to fifteen seconds, cursor optional. Lands on disk *and* on the
clipboard, and waits for its own overlay to leave the screen first so it never
appears in the shot.

**Wallpaper selector.** Browses your wallpaper directory with search, format
filters and cached thumbnails.

**Theme selector.** Thirteen palettes, applied live — and not just to the shell.
The same colours reach Hyprland's borders, hyprlock's fields and Ghostty's
terminal through one generated file.

**Power menu.** Lock, suspend, log out, reboot, power off, each behind a
confirmation that a stray click cancels rather than confirms.

**Bluetooth pairing.** A device asking for a PIN or a six-digit confirmation gets
a real dialog, served by a small companion agent — because Quickshell cannot own
a D-Bus object and BlueZ refuses a pairing nobody can answer.

---

## Quick start

```sh
# 1. the two it cannot start without
pacman -S hyprland
paru -S quickshell-git

# 2. the icons — without this the bar is empty boxes, not unstyled
pacman -S ttf-nerd-fonts-symbols

# 3. clone — anywhere you like, this is just the Quickshell convention
git clone https://github.com/adanft/qsrice.git ~/.config/quickshell/qsrice
```

> Clone it somewhere other than `~/.config/qsrice`. That directory is where the
> shell keeps its own `settings.json`, and putting the checkout there leaves
> state sitting inside your working tree.

Then two things in your `hyprland.lua` — start it, and bind it:

```lua
local qsrice = os.getenv("HOME") .. "/.config/quickshell/qsrice"

hl.on("hyprland.start", function()
    hl.exec_cmd("qs -p " .. qsrice)
end)

hl.bind("SUPER + D", hl.dsp.exec_cmd("qs ipc -p " .. qsrice .. " call applauncher toggle"))
hl.bind("SUPER + T", hl.dsp.exec_cmd("qs ipc -p " .. qsrice .. " call themeselector toggle"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("qs ipc -p " .. qsrice .. " call wallpaperselector toggle"))
hl.bind("SUPER + X", hl.dsp.exec_cmd("qs ipc -p " .. qsrice .. " call powermenu toggle"))
hl.bind("Print",     hl.dsp.exec_cmd("qs ipc -p " .. qsrice .. " call screenshot toggle"))
```

That is the whole integration. The control centre and the notification centre
need no binds — they open from the bar, because both anchor themselves to the
module you clicked.

---

## Requirements

Package names are Arch's, because that is where it was built and tested. On
another distribution the binaries are the same; only the package names move.

### The two it cannot start without

| | Tested with | Why |
|---|---|---|
| **Hyprland** | 0.56.2 | The shell talks to it over its IPC, and the launch hook lives in `hyprland.lua`. The Lua config format arrived in 0.55 — an older Hyprland needs `hyprland.conf` instead. |
| **Quickshell** (`qs`) | 0.3.0 (`quickshell-git`) | The runtime. Pulls Qt 6 with it (built here against 6.11.1). |

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

<details>
<summary><b>Desktop services — the daemons behind the control centre</b></summary>

Each is reached through a Quickshell module over D-Bus, so these are daemons to
have running, not commands to install.

| Service | Package | Feeds |
|---|---|---|
| NetworkManager | `networkmanager` | Wi-Fi and Ethernet |
| BlueZ | `bluez` `bluez-utils` | Bluetooth |
| PipeWire + WirePlumber | `pipewire` `wireplumber` | volume, output and input devices, per-app streams |
| UPower | `upower` | battery |
| logind | `systemd` | session actions from the power menu |
| AccountsService | `accountsservice` | the user's avatar, read over `busctl`. Without it the avatar is simply empty. |

</details>

<details>
<summary><b>Optional tools — read this as a menu, not a checklist</b></summary>

The shell degrades one feature at a time rather than failing to start. Install
only what you want to use.

| Missing | What you lose |
|---|---|
| `grim` `slurp` `wl-clipboard` `jq` | The screenshot tool. All four are used in one pipeline: `slurp` picks the region, `hyprctl`+`jq` resolve the focused window, `grim` captures, `wl-copy` puts it on the clipboard. |
| `awww` | Applying a wallpaper. The selector still browses and still remembers your choice. |
| `imagemagick` | Wallpaper thumbnails, so the grid falls back to full images. |
| `brightnessctl` | The brightness control, which reports itself unavailable and disappears. |
| `bluez-utils` | Starting a pairing. Devices already paired keep working. |
| `bagent` | Finishing a pairing that asks a question — a phone confirming six digits, a keyboard wanting a PIN typed. Quickshell cannot serve a D-Bus object, so `org.bluez.Agent1` lives in this separate process; without it BlueZ has nobody to ask and refuses. Devices that pair with no interaction still work. Build and install it with `./install.sh`. |
| `networkmanager` | Connection details — address, profile — while the connection itself is unaffected. |
| `ghostty` and `glib2` | The terminal following the theme. `gapplication` is what tells Ghostty to reload. |
| `hyprlock` | Locking from the power menu. |

```sh
pacman -S grim slurp wl-clipboard jq imagemagick brightnessctl
paru -S awww
```

</details>

---

## Using it

### The bar

| Cluster | Holds | What responds |
|---|---|---|
| **Left** | Workspaces · CPU, RAM · system tray | A workspace pill focuses that workspace. Tray items open their own menus. The tray disappears when nothing is in it. |
| **Centre** | Control centre button · clock · power profile | The button opens the control centre with nothing expanded. |
| **Right** | Network throughput · Wi-Fi · Bluetooth · sound · backlight · battery · microphone · notifications · date | Four are shortcuts — below. |

| Click | Opens |
|---|---|
| Wi-Fi | Control centre, Wi-Fi expanded |
| Bluetooth | Control centre, Bluetooth expanded |
| Sound | Control centre, audio output expanded |
| Microphone | Control centre, microphone expanded |
| Notifications | Notification centre |

The throughput readout is a readout, not a button.

### One panel at a time, and how to close it

The five panels you open yourself — launcher, power menu, wallpaper selector,
theme selector, screenshot tool — are mutually exclusive. Opening one closes
whatever was up, and closes it by *destroying* it rather than hiding it, so a
panel you are not looking at costs nothing while it is away.

The Bluetooth pairing dialog is the exception in both directions: it displaces
those five, and nothing displaces it. Closing it means refusing a pairing BlueZ
is waiting on, which is not a decision another panel should be able to make by
opening.

The control centre and the notification centre sit outside that arrangement —
they belong to the bar, and either can be up alongside anything else.

| Panel | Escape | Click outside |
|---|---|---|
| App launcher, power menu, wallpaper selector, theme selector, screenshot tool | closes | closes |
| Bluetooth pairing | rejects | — |
| Control centre | — | closes |
| Notification centre | — | — |

The notification centre closes the way it opened: by clicking the bar's
notification module again.

### Keys

<details open>
<summary><b>App launcher</b></summary>

| Key | Does |
|---|---|
| Any character | Filters |
| ← → | Moves one app — unless the text cursor has somewhere to go, in which case it moves the cursor |
| ↑ ↓ | Moves one row |
| Enter | Launches and closes |
| Escape | Closes |

</details>

<details>
<summary><b>Screenshot tool</b></summary>

Four modes: **All** (every screen), **Monitor**, **Window** (the focused one,
resolved through `hyprctl`), **Area** (dragged with `slurp`).

| Key | Does |
|---|---|
| ← → | Picks the mode |
| ↑ ↓ | Includes or excludes the cursor |
| Tab / Shift+Tab | Cycles the delay: 0, 3, 5, 10, 15 seconds |
| Enter | Captures |
| Escape | Closes |

Captures land in `~/Pictures/Screenshots` **and** on the clipboard.

</details>

<details>
<summary><b>Wallpaper selector</b></summary>

Browses `~/Wallpapers` — override with `AWWW_WALLPAPERS_DIR`.

| Key | Does |
|---|---|
| Any character | Filters by name |
| ← → ↑ ↓ | Moves through the grid |
| Enter | Applies and closes |
| Escape | Closes |

Three format filters — **png**, **jpg**, **gif** — toggle independently, so
several can be on at once. Thumbnails are cached under
`$XDG_CACHE_HOME/qsrice/wallpapers`.

</details>

<details>
<summary><b>Theme selector</b></summary>

Thirteen palettes ship with it:

`atom-one-light` · `aura` · `aurora-x` · `ayu-dark` · `catppuccin` ·
`catppuccin-latte` · `hack-the-box` · `kanagawa-dragon` · `kanagawa-lotus` ·
`kanagawa-wave` · `one-dark` · `palenight` · `rose-pine`

| Key | Does |
|---|---|
| Any character | Filters by name |
| ← → ↑ ↓ | Moves through the grid |
| Enter or Space | Applies |
| Home / End | Jumps to the first or last |
| Escape | Closes |

Two filters, **dark** and **light**. A theme lands in one or the other by the
brightness of its own `surface` colour, not by what its name claims.

A theme can also be set from a script, which is what the IPC `set` is for:

```sh
qs ipc -p ~/.config/quickshell/qsrice call themeselector set kanagawa-dragon
```

</details>

<details>
<summary><b>Control centre</b></summary>

Five sections, one expanded at a time: **Ethernet**, **Wi-Fi**, **audio output**,
**microphone**, **Bluetooth**. Clicking a section's body expands it; clicking the
expanded one collapses it again. Each card also carries its own toggle, so a
radio can go off without opening anything.

Inside a section, rows respond to a click or to Enter / Space when focused:

- **Wi-Fi** — connect, disconnect, or forget a remembered network.
- **Ethernet** — bring a profile up or down.
- **Audio output** and **microphone** — pick a device, and mute individual
  playback streams per application.
- **Bluetooth** — scan, connect, disconnect. A pairing that needs a human answer
  raises its own dialog with an accept and a reject: **Enter** or **Space**
  triggers whichever is focused, and **Escape** rejects.

</details>

<details>
<summary><b>Power menu</b></summary>

Lock · suspend · log out · reboot · power off.

Nothing fires on the first press. Choosing an action replaces the row with a
confirm and a cancel, so ← → then Enter is always two deliberate steps. Escape
backs out of the confirmation before it closes the menu, and a stray click on the
backdrop cancels rather than confirms.

</details>

### The IPC

Five targets, each taking `open` and `toggle`; the theme selector also takes
`set <name>`:

```sh
qs ipc -p ~/.config/quickshell/qsrice call applauncher       toggle
qs ipc -p ~/.config/quickshell/qsrice call themeselector     toggle
qs ipc -p ~/.config/quickshell/qsrice call wallpaperselector toggle
qs ipc -p ~/.config/quickshell/qsrice call powermenu         toggle
qs ipc -p ~/.config/quickshell/qsrice call screenshot        toggle
```

---

## Theming the rest of the desktop

The shell writes `~/.config/hypr/theme.conf` whenever the theme or the wallpaper
changes. It is the shell's file — it is rewritten whole, so do not edit it — and
it holds colours under role names (`$primary`, `$on_surface`, `$surface`) plus
`$wallpaper` and `$font`.

The names are roles, not pigments. `theme.conf` used to spell Catppuccin's
vocabulary — mauve, peach, crust — and under any other palette those become lies:
there is no mauve in Kanagawa. `$primary` is true whichever palette is loaded.

Two programs read that one file, in the two different ways they each can.

<details>
<summary><b>hyprlock — sources it directly</b></summary>

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

</details>

<details>
<summary><b>Hyprland — cannot source hyprlang from Lua, so it reads it back</b></summary>

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

</details>

The shell runs `hyprctl reload` after writing, but only when a colour actually
changed — Hyprland never reads `$wallpaper` or `$font`, so choosing a background
does not make it re-apply monitors, binds and animations.

The variables available are `$primary` `$primaryAlpha` `$secondary` `$error`
`$outline` `$surface` `$surfaceVeil` `$shadow` `$on_surface` `$on_surfaceAlpha`
`$wallpaper` `$font`. The `…Alpha` pair is the bare hex, for pango markup inside
hyprlock's `placeholder_text`, which is a string and cannot take a colour value.

**Ghostty** needs nothing from you. If it is installed, the shell keeps a marked
block at the end of `~/.config/ghostty/config.ghostty` naming a built-in Ghostty
theme. Everything else in that file is left alone.

---

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

---

## FAQ

<details>
<summary><b>The bar is full of empty boxes.</b></summary>

The Nerd Font is missing. `pacman -S ttf-nerd-fonts-symbols`. Every icon in the
shell is a font codepoint, not an image, so there is nothing to fall back to.

</details>

<details>
<summary><b>Nothing opens when I press my keys.</b></summary>

The panels are not bound by the shell — you bind them yourself over the IPC. See
[Quick start](#quick-start). Check the path in `-p` matches where you cloned it.

</details>

<details>
<summary><b>My first theme change did not stick.</b></summary>

Known. The first change after the shell starts is written as the default instead,
and the second one works. It affects every theme.

</details>

<details>
<summary><b>Hyprland's borders do not follow the theme.</b></summary>

Hyprland cannot `source` a hyprlang file from a Lua config, so it has to read
`theme.conf` back by hand. Copy the `read_theme()` block from
[Theming](#theming-the-rest-of-the-desktop) into your own config.

</details>

<details>
<summary><b>The lock screen's text is invisible on a light theme.</b></summary>

Known. hyprlock's labels sit on the wallpaper, and `on_surface` is a dark colour
in the three light themes, so it disappears over a dark photo. There is no role
for text over a picture because the shell never paints any — the bar sits on
opaque `shadow`.

</details>

<details>
<summary><b>The wallpaper selector seems to keep memory after closing.</b></summary>

It does — about 46 MB. It is not a leak; repeated opens stop adding. Measured, it
is 31 MB of heap and 14 MB of GPU driver, and it is not the images:
`features/wallpaperselector/WallpaperCard.qml` records everything that was ruled
out and how.

</details>

<details>
<summary><b>Can I use it without Hyprland?</b></summary>

Not as it stands. The bar and panels are Wayland layer-shell surfaces and would
port, but workspaces, the window screenshot, the theme reload and the launch hook
all go through Hyprland's IPC.

</details>

---

## Development

Tests, the harnesses, and why the suite runs inside a nested compositor:
**[`docs/development.md`](docs/development.md)**.

```sh
./run-tests.sh             # everything, on the compositor you are using
./run-tests.sh --isolated  # everything, compositor stages nested away
./run-tests.sh --js        # Node and Python only, no compositor needed
```

Layout is vertical: each feature owns its components, sizing and tests under
`features/`, shared pieces live in `shared/`, system access in `services/`, and
the design tokens — colours, typography, spacing, icons, shape, motion — in
`theme/`.

## Credits

- [**Quickshell**](https://quickshell.org) by outfoxxed — the runtime this is
  built on.
- [**Hyprland**](https://hypr.land) — the compositor, and hyprlock alongside it.
- The palettes are the work of their own authors: Catppuccin, Kanagawa,
  Rosé Pine, Ayu, One Dark, Atom One, Palenight, Aura, Aurora X and
  Hack The Box.
