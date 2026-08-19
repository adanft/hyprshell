# HyprShell

HyprShell is a Wayland desktop shell for Hyprland that combines a bar, launcher, control center, notifications, screenshots, wallpapers, and internal palettes.

<div align="center">
  <img src="docs/screenshots/bar.webp" width="100%" alt="HyprShell status bar across the top of a desktop">
</div>

<details>
<summary>More screenshots</summary>

|                                Launcher                                 |                             Control center                              |
| :---------------------------------------------------------------------: | :---------------------------------------------------------------------: |
| <img src="docs/screenshots/launcher.webp" alt="Application launcher" /> | <img src="docs/screenshots/control-center.webp" alt="Control center" /> |

|                                Notifications                                |                           Power menu                           |
| :-------------------------------------------------------------------------: | :------------------------------------------------------------: |
| <img src="docs/screenshots/notifications.webp" alt="Notification center" /> | <img src="docs/screenshots/powermenu.webp" alt="Power menu" /> |

</details>

## What you get

- **A useful desktop surface:** workspaces, system status, tray, clock, network, audio, power, battery, brightness, and notifications.
- **Fast actions:** an app launcher, control center, notification history, power menu, and screenshot tool.
- **Personalization:** wallpaper browsing and thirteen internal palettes.
- **Graceful degradation:** unavailable radios, audio inputs, and other integrations remain unavailable or inert; battery and backlight modules hide when the hardware is absent.

## Requirements and support

| Area                     | Support                                                                                                                                                                       |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Required runtime         | Hyprland and Quickshell (`qs`). HyprShell uses Hyprland IPC and Wayland layer-shell surfaces.                                                                                 |
| Feature packages         | `awww`/`awww-daemon`, `jq`, `imagemagick`, `libnotify`, `grim`, `slurp`, `wl-clipboard`, and the other packages in the installation command below.                            |
| Optional integrations    | NetworkManager, BlueZ, PipeWire/WirePlumber, UPower, power-profiles-daemon, and a locker such as hyprlock. Their services/features are independent of shell startup. |
| Missing hardware         | Missing Bluetooth, Wi-Fi, Ethernet, or microphone stays unavailable/inert. Battery and backlight modules hide without matching hardware.                                      |
| Unsupported environments | Non-Hyprland compositors are not supported. Other distributions may work with equivalent package names, but this guide targets Arch Linux and Hyprland.                       |

## Quick start

### 1. Install dependencies

Install the stable packages from Arch's official repositories. No AUR helper is required for this setup.

```sh
sudo pacman -S --needed curl tar coreutils hyprland quickshell awww \
  ttf-nerd-fonts-symbols networkmanager bluez bluez-utils pipewire \
  wireplumber upower power-profiles-daemon accountsservice grim slurp \
  wl-clipboard jq imagemagick libnotify brightnessctl
```

`curl`, `tar`, and `coreutils` provide the downloader and archive/checksum tools used by the installer. Hyprland and Quickshell are startup-critical. The remaining packages support specific features such as networking, audio, notifications, screenshots, wallpapers, and typography.

### 2. Install HyprShell

```sh
curl -fsSL https://raw.githubusercontent.com/adanft/hyprshell/main/install.sh | sh
```

The installer places the shell in `${XDG_CONFIG_HOME:-$HOME/.config}/hyprshell` and installs `bagent` in `$HOME/.local/bin` by default. It warns, rather than failing, if `qs` or Hyprland is not present. Re-running the command upgrades the installed files and preserves `settings.json`.

### 3. Add the Hyprland configuration

HyprShell does not replace your Hyprland configuration. Add the following sections to `hyprland.lua`, adapting the surrounding configuration to your setup.

#### Essential startup

This is the only Hyprland configuration required to start the shell:

```lua
local config_home = os.getenv("XDG_CONFIG_HOME")
if not config_home or config_home == "" then
    config_home = os.getenv("HOME") .. "/.config"
end

local hyprshell = config_home .. "/hyprshell"

hl.on("hyprland.start", function()
    hl.exec_cmd("qs -p " .. hyprshell)
end)
```

#### Optional keybinds

Add panel/action IPC binds separately when you want them:

```lua
hl.bind("SUPER + D", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call applauncher toggle"))
hl.bind("SUPER + T", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call themeselector toggle"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call wallpaperselector toggle"))
hl.bind("SUPER + X", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call powermenu toggle"))
hl.bind("Print",     hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call screenshot toggle"))
```

#### Optional wallpaper support

Wallpaper changes need `awww-daemon`, but the shell itself does not. Add this line inside the `hyprland.start` callback above, before the `qs` command:

```lua
hl.exec_cmd("awww-daemon")
```

### 4. Verify

Check the required runtime and installed pairing agent separately:

```sh
command -v qs
command -v hyprland || command -v Hyprland
command -v bagent
```

Wallpaper support has its own optional check:

```sh
command -v awww-daemon
```

Then launch the shell directly if it is not already running:

```sh
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
qs -p "$config_home/hyprshell"
```

You should see the bar. If you added the optional keybinds or wallpaper support, verify those features separately.

## Typography

`ttf-nerd-fonts-symbols` provides `Symbols Nerd Font`, which HyprShell uses for icons. The shell still starts without it, but icons render as missing-glyph boxes.

Body text requests `SF Pro Display`. It is not bundled or installed by `install.sh`; when it is absent, Qt uses another system font, so HyprShell does not depend on it for startup. The files are available from the [San Francisco Pro Fonts repository](https://github.com/chris-short/apple-san-francisco-pro-fonts), whose README points back to Apple. Review the included restrictive Apple font license before installing or using it on Linux.

## Configuration and storage

- `settings.json` stores the current theme and wallpaper under `${XDG_CONFIG_HOME:-$HOME/.config}/hyprshell/`. It is created on first run and preserved by upgrades.

- Wallpapers are read from `$AWWW_WALLPAPERS_DIR`, or `$HOME/Wallpapers` when it is unset. Screenshots go to `$HOME/Pictures/Screenshots`.
- Cache data is stored under `${XDG_CACHE_HOME:-$HOME/.cache}/hyprshell/`.

## Troubleshooting

### Empty icon boxes

Confirm that `ttf-nerd-fonts-symbols` from the dependency step is installed, then restart the shell.

### The shell does not start

Check `qs` and Hyprland separately with the commands above, then confirm that the `-p` path uses the same XDG config directory as the installer. The installer only warns when either prerequisite is absent.

### Keybinds do nothing

The shell does not create Hyprland binds automatically. Add the IPC binds from the Quick start section and reload Hyprland.

### Wallpapers do not change

Start the optional `awww-daemon` from the Hyprland start hook, then try again:

```sh
awww-daemon &
awww query
```

### Lock does nothing

The power menu calls `loginctl lock-session`; it does not provide a locker. Configure a locker such as hyprlock through hypridle, for example:

```ini
general {
    lock_cmd = pidof hyprlock || hyprlock
}
```

## Development

See [Development](docs/development.md) for the test environment and project conventions.

```sh
git clone https://github.com/adanft/hyprshell.git
cd hyprshell
./scripts/install-bagent.sh
qs -p "$PWD"
./run-tests.sh --js
```

## Credits

- [Quickshell](https://quickshell.org) by outfoxxed
- [Hyprland](https://hypr.land)
- Catppuccin, Kanagawa, Rosé Pine, Ayu, One Dark, Atom One, Palenight, Aura, Aurora X, and Hack The Box for the palettes

## License

[MIT](LICENSE)
