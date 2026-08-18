<div align="center">

# hyprshell

**A Wayland desktop shell for Hyprland.**

One process draws your bar, launcher, control center, notifications, screenshots,
wallpapers and themes — and paints Hyprshell, Hyprland and Ghostty to match.

</div>

<div align="center">
  <img src="docs/screenshots/bar.webp" width="100%" alt="The shell on an empty desktop: the status bar across the top, with workspaces, CPU and RAM and the tray on the left, the clock in the middle, and the radios, sound, battery and date on the right">
</div>

<details>
<summary><b>The panels — click to open</b></summary>
<br>

| App launcher | Control center |
|:---:|:---:|
| <img src="docs/screenshots/launcher.webp" alt="The app launcher, filtering desktop entries into a grid"> | <img src="docs/screenshots/control-center.webp" alt="The control center, with Ethernet, Wi-Fi, sound, microphone and Bluetooth"> |
| **Notification center** | **Power menu** |
| <img src="docs/screenshots/notifications.webp" alt="The notification center, showing history"> | <img src="docs/screenshots/powermenu.webp" alt="The power menu: lock, suspend, log out, reboot, power off"> |
| **Theme selector** | **Wallpaper selector** |
| <img src="docs/screenshots/theme-selector.webp" alt="The theme selector, showing the thirteen palettes"> | <img src="docs/screenshots/wallpaper-selector.webp" alt="The wallpaper selector, browsing a directory as a thumbnail grid"> |

<div align="center">
  <b>Screenshot tool</b><br>
  <img src="docs/screenshots/screenshot.webp" width="70%" alt="The screenshot tool, with its four modes, the delay and the cursor toggle">
</div>

</details>

## Quick start

From a fresh Arch install to the desktop in the screenshots above. Package names
are Arch's; on another distribution the binaries are the same and only the names
move.

### 1. Install everything

```sh
# the three it cannot start without: the compositor, the runtime, and the font
# every icon in the shell is a codepoint from
sudo pacman -S hyprland ttf-nerd-fonts-symbols

# the desktop services it reads over D-Bus
sudo pacman -S networkmanager bluez bluez-utils pipewire wireplumber \
               upower power-profiles-daemon accountsservice

# the commands it shells out to
sudo pacman -S grim slurp wl-clipboard jq imagemagick libnotify glib2 ghostty
```

```sh
# the runtime and the wallpaper daemon are not in the official repositories
paru -S quickshell-git awww
```

Nothing above is strictly required past the first line. Each piece buys exactly
one feature and the shell starts without it — no `imagemagick` means the
wallpaper grid falls back to full images, no `libnotify` means a capture lands
on disk without telling you.

<details>
<summary><b>Laptops — one more package</b></summary>

```sh
sudo pacman -S brightnessctl
```

The brightness control needs it, and reports itself unavailable and disappears
without it. The battery readout needs nothing extra: `upower` is already above,
and both modules hide themselves on hardware that has no backlight and no
battery, which is why a desktop shows neither.

</details>

### 2. Turn on the two services that need it

```sh
sudo systemctl enable --now NetworkManager bluetooth
```

That is the whole list. `upower`, `power-profiles-daemon` and `accountsservice`
are D-Bus activated and `pipewire` and `wireplumber` are socket activated, so
they start the moment something asks for them — enabling them changes nothing.

### 3. Install the shell

```sh
curl -fsSL https://raw.githubusercontent.com/adanft/hyprshell/main/install.sh | sh
```

That puts the shell in `~/.config/hyprshell` and the `bagent` Bluetooth pairing
agent on your PATH. Nothing is compiled and nothing is cloned. Run the same line
again to upgrade: it replaces what it installed last time and leaves your
`settings.json` alone.

### 4. Configure Hyprland

Everything the shell needs from your `hyprland.lua`, and nothing else — it does
not take your keybinds, set window rules, or touch anything you have not written
here yourself.

```lua
local hyprshell = os.getenv("HOME") .. "/.config/hyprshell"

hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")            -- the wallpaper daemon
    hl.exec_cmd("qs -p " .. hyprshell)    -- the shell
end)

hl.bind("SUPER + D", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call applauncher toggle"))
hl.bind("SUPER + T", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call themeselector toggle"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call wallpaperselector toggle"))
hl.bind("SUPER + X", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call powermenu toggle"))
hl.bind("Print",     hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call screenshot toggle"))
```

The control center and the notification center need no binds — they open from
the bar, because both anchor themselves to the module you clicked.

`awww-daemon` has to be started here because the shell never starts it: it only
ever runs `awww img` to apply a picture. With the daemon down, choosing a
wallpaper looks like it worked and the screen does not change. You do not need
`awww restore` — the daemon reads its own cache on start and puts the last
wallpaper back.

### 5. Locking, if you want it

The power menu's Lock runs `loginctl lock-session`. It asks logind to lock the
session rather than launching a locker itself, so what appears is whatever is
registered to answer — and nothing is, until you install one. `hyprlock` with
`hypridle` running `lock_cmd` is the usual pair on Hyprland. Every other action
in that menu goes straight to `systemctl` or `hyprctl` and needs nothing.

### Confirm it came up

```sh
qs -p ~/.config/hyprshell     # the bar appears, with icons rather than boxes
command -v bagent awww-daemon # both resolve
```

## Features

### Status bar

Always up, one row across the top, in three clusters. Modules that have nothing
to report take no space rather than sitting there empty — a machine with no
battery has no battery readout, not a dead one.

- **Left**
  - **Workspaces** — click a pill to focus that workspace
  - **CPU** and **RAM** — live percentages
  - **System tray** — the whole cluster is gone while nothing is in it
- **Center**
  - **Control center button** — opens it with nothing expanded
  - **Clock**
  - **Power profile**
- **Right**
  - **Network throughput** — up and down, a readout rather than a button
  - **Wi-Fi** — *shortcut*
  - **Bluetooth** — *shortcut*
  - **Sound** — *shortcut*
  - **Brightness** — laptops, or any machine with a backlight to set
  - **Battery** — laptops, or anything else with one
  - **Microphone** — *shortcut*
  - **Notifications** — appears once there is something to show
  - **Date**

The four marked *shortcut* open the control center **already expanded** on their
own section, so reaching Wi-Fi is one click rather than two. Notifications opens
the notification center the same way.

### App launcher

Type to filter desktop entries. The search field never loses focus, so the
arrows move through the grid and the text cursor without you reaching for
anything: left and right walk the text while there is text to walk, and move
between apps once there is not.

### Control center

Five sections, one expanded at a time. Every card carries its own toggle, so a
radio can go off without opening anything.

- **Ethernet** — bring a profile up or down
- **Wi-Fi** — connect, disconnect, or forget a remembered network
- **Bluetooth** — scan, connect, disconnect
- **Audio output** — pick a device, and mute individual application streams
- **Microphone** — pick a device

Wi-Fi scanning is claimed while you are looking at it and released when you are
not, rather than running for as long as the shell does.

### Notification center

History that survives a restart, images included. Do not disturb, clear all, and
per-notification expand.

### Screenshot tool

Four modes, a delay of up to fifteen seconds, and the cursor in or out.

- **All** — every screen
- **Monitor** — one output
- **Window** — the focused one, resolved through `hyprctl`
- **Area** — dragged out with `slurp`

Captures land on disk **and** on the clipboard, and the tool waits for its own
overlay to be off the screen before the shutter, so it stays out of the picture.

### Wallpaper selector

Browses your wallpaper directory with search, format filters and cached
thumbnails.

### Theme selector

Thirteen palettes, applied live — and not only to the shell. The same colors
reach Hyprland's borders, hyprlock's fields and Ghostty's terminal through one
generated file.

### Power menu

Lock, suspend, log out, reboot and power off, each behind a confirmation that a
stray click cancels rather than confirms.

### Bluetooth pairing

A device asking for a PIN or a six-digit confirmation gets a real dialog, served
by a small companion agent — because Quickshell cannot own a D-Bus object and
BlueZ refuses a pairing nobody can answer.

---

## Where it keeps things

| Path | What |
|---|---|
| `~/.config/hyprshell` | The shell itself, put there by the installer. |
| `~/.config/hyprshell/settings.json` | Current theme and wallpaper. Created on first run, and left alone by an upgrade. |
| `~/.local/bin/bagent` | The Bluetooth pairing agent. |
| `~/.config/hypr/theme.conf` | Generated. Owned by the shell. |
| `~/.config/ghostty/config.ghostty` | A marked block inside your own config. |
| `~/Wallpapers` | Where the selector looks. Override with `AWWW_WALLPAPERS_DIR`. |
| `~/Pictures/Screenshots` | Where captures land. |
| `$XDG_CACHE_HOME/hyprshell/wallpapers` | Thumbnails. |
| `$XDG_CACHE_HOME/hyprshell/notification-images` | Notification images, so history survives a restart. |

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
[Quick start](#quick-start). Check the path in `-p` matches where it is installed:
`~/.config/hyprshell`, unless you cloned it somewhere else to work on it.

</details>

<details>
<summary><b>I picked a wallpaper and the screen did not change.</b></summary>

`awww-daemon` is not running. The shell only ever runs `awww img`, and it does
that detached — so nothing reports the failure back. The selector closes, the
choice is saved, `theme.conf` updates, and the picture never lands.

```sh
awww-daemon &          # then pick again
awww query             # names your outputs if it is up
```

Start it from your `hyprland.lua` so it is there every session — see
[step 4](#4-configure-hyprland). Worth knowing: your lock screen reads
`$wallpaper` from `theme.conf`, so this can leave hyprlock showing a picture your
desktop never did.

</details>

<details>
<summary><b>The Lock button does nothing.</b></summary>

Installing `hyprlock` is not enough. The power menu runs `loginctl lock-session`,
which asks logind to lock the session rather than launching a locker itself — so
something has to be listening for that. On Hyprland that is `hypridle`:

```ini
# ~/.config/hypr/hypridle.conf
general {
    lock_cmd = pidof hyprlock || hyprlock
}
```

Every other power-menu action goes straight to `systemctl` or `hyprctl` and needs
nothing registered, which is why Lock is the only one that can be silent.

</details>

<details>
<summary><b>My first theme change did not stick.</b></summary>

Known. The first change after the shell starts is written as the default instead,
and the second one works. It affects every theme.

</details>

<details>
<summary><b>Hyprland's borders do not follow the theme.</b></summary>

Hyprland cannot `source` a hyprlang file from a Lua config, so nothing reads
`theme.conf` until you parse it back yourself. The file holds one `$name = value`
per line — read it in your `hyprland.lua` and feed `$primary` and `$outline` to
`general.col`. An empty string is truthy in Lua, so a plain `theme[name] or
fallback` is not enough.

</details>

<details>
<summary><b>The lock screen's text is invisible on a light theme.</b></summary>

Known. hyprlock's labels sit on the wallpaper, and `on_surface` is a dark color
in the three light themes, so it disappears over a dark photo. There is no role
for text over a picture because the shell never paints any — the bar sits on
opaque `shadow`.

</details>

<details>
<summary><b>The wallpaper selector seems to keep memory after closing.</b></summary>

It does — about 46 MB, with 39 wallpapers on disk. It is not a leak: repeated
opens add 39.5 MB, then 13.7, then 2.1, and stop. It is not the images either —
eight wallpapers at 1920x1080 and the same eight at 320x180 retain the same
number, so sixteen times less pixel data on disk costs nothing. What is left
looks like a fixed cost of running the grid at all, around 20 MB, plus something
small per card. Naming it properly needs a heap profiler.
`features/wallpaperselector/WallpaperCard.qml` records every measurement and
everything that was ruled out.

</details>

<details>
<summary><b>Can I use it without Hyprland?</b></summary>

Not as it stands. The bar and panels are Wayland layer-shell surfaces and would
port, but workspaces, the window screenshot, the theme reload and the launch hook
all go through Hyprland's IPC.

</details>

---

## Development

Working on it means the repository, not the installer:

```sh
git clone https://github.com/adanft/hyprshell.git
cd hyprshell
./scripts/install-bagent.sh   # builds bagent from source — needs `rust`
qs -p "$PWD"
```

Clone it anywhere except `~/.config/hyprshell`. That is where an installed shell
and its `settings.json` live, and a checkout on top of them leaves state sitting
inside your working tree and the installer overwriting your work.

Tests, the harnesses, and why the suite runs inside a nested compositor:
**[`docs/development.md`](docs/development.md)**.

```sh
./run-tests.sh             # everything, on the compositor you are using
./run-tests.sh --isolated  # everything, compositor stages nested away
./run-tests.sh --js        # Node and Python only, no compositor needed
```

Releases are cut by hand. The script builds `bagent`, packs the runtime without
the tests or harnesses, and attaches both the archive and its checksum to a
GitHub release — which is what the installer's `latest` resolves to:

```sh
./scripts/make-release.sh v0.1.0 --dry-run   # build the assets, publish nothing
./scripts/make-release.sh v0.1.0             # build and publish
```

Layout is vertical: each feature owns its components, sizing and tests under
`features/`, shared pieces live in `shared/`, system access in `services/`, and
the design tokens — colors, typography, spacing, icons, shape, motion — in
`theme/`.

## Credits

- [**Quickshell**](https://quickshell.org) by outfoxxed — the runtime this is
  built on.
- [**Hyprland**](https://hypr.land) — the compositor, and hyprlock alongside it.
- The palettes are the work of their own authors: Catppuccin, Kanagawa,
  Rosé Pine, Ayu, One Dark, Atom One, Palenight, Aura, Aurora X and
  Hack The Box.

## License

[MIT](LICENSE). Use it, change it, ship it — ship the licence file with it.
