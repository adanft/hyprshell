#!/bin/sh
#
# The one-line install.
#
#     curl -fsSL https://raw.githubusercontent.com/adanft/hyprshell/main/install.sh | sh
#
# Downloads the current release, puts the shell in ~/.config/hyprshell and the
# Bluetooth pairing agent on your PATH. Nothing is compiled and nothing is
# cloned: the release already carries a built bagent, and the repository — tests,
# harnesses, Rust sources, this script's own siblings — never reaches you.
#
# Run it again to upgrade. Your settings.json is not touched.
#
#     HYPRSHELL_VERSION=v0.2.0  sh install.sh   a specific release
#     HYPRSHELL_BIN_DIR=~/bin   sh install.sh   somewhere else for bagent
#
# Written for POSIX sh, because the documented way to run it is a pipe into sh
# and that is not always bash.

set -eu

readonly REPO="adanft/hyprshell"
readonly ARCHIVE="hyprshell.tar.gz"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SHELL_DIR="$CONFIG_HOME/hyprshell"
BIN_DIR="${HYPRSHELL_BIN_DIR:-$HOME/.local/bin}"
VERSION="${HYPRSHELL_VERSION:-latest}"

# What the last install put here. Kept so an upgrade removes exactly what it
# placed and nothing else — settings.json lives in this same directory, and a
# blanket wipe would take a theme and a wallpaper with it every time.
readonly MANIFEST=".install-manifest"

say() { printf '%s\n' "$*"; }
fail() {
	printf -- '-- FAILED: %s\n' "$*" >&2
	exit 1
}

# Installing into $HOME as root leaves every file owned by root, and the shell
# then cannot write its own settings. Only $HOME is written here, so there is
# nothing root is needed for.
[ "$(id -u)" -eq 0 ] && fail "do not run this as root — it installs into $HOME"

for tool in curl tar sha256sum install; do
	command -v "$tool" >/dev/null 2>&1 || fail "$tool is required and not installed"
done

if [ -n "${HYPRSHELL_BASE_URL:-}" ]; then
	# Where the assets are fetched from, for trying a build before it is a
	# release. `file://$PWD/dist` after scripts/make-release.sh --dry-run runs
	# this whole script against what you just packed.
	base="$HYPRSHELL_BASE_URL"
elif [ "$VERSION" = latest ]; then
	# GitHub resolves this redirect to the newest release's asset, so the version
	# never has to be discovered first. No API call, so no rate limit and no JSON
	# to parse without jq.
	base="https://github.com/$REPO/releases/latest/download"
else
	base="https://github.com/$REPO/releases/download/$VERSION"
fi

work=$(mktemp -d) || fail "could not create a temporary directory"
# Leaving a half-unpacked tree in /tmp on every failed run is how a disk fills up
# quietly, so this is cleaned on the way out however the script leaves.
trap 'rm -rf "$work"' EXIT INT TERM

say "== hyprshell =="
say "-- downloading ($VERSION)"

curl -fsSL "$base/$ARCHIVE" -o "$work/$ARCHIVE" ||
	fail "could not download $base/$ARCHIVE"
curl -fsSL "$base/$ARCHIVE.sha256" -o "$work/$ARCHIVE.sha256" ||
	fail "could not download the checksum for $ARCHIVE"

# The archive arrived over the network and is about to be unpacked into your
# config. Checking it costs one command.
say "-- verifying"
(cd "$work" && sha256sum -c "$ARCHIVE.sha256" >/dev/null 2>&1) ||
	fail "the checksum does not match — the download is corrupt or tampered with"

tar -xzf "$work/$ARCHIVE" -C "$work" || fail "the archive could not be unpacked"

readonly UNPACKED="$work/hyprshell"
[ -f "$UNPACKED/shell.qml" ] ||
	fail "the archive does not look like a hyprshell release"

version=$(cat "$UNPACKED/VERSION" 2>/dev/null || echo unknown)

# Remove what the previous install placed, from its own record, before writing
# the new tree. Without this an entry dropped between versions would linger in
# your config forever, and Quickshell would keep loading it.
if [ -f "$SHELL_DIR/$MANIFEST" ]; then
	say "-- replacing the previous install"
	while IFS= read -r entry; do
		# Anything with a slash, empty, or relative is refused rather than
		# trusted: this file decides what gets deleted, so it is read as data and
		# never as a path to follow.
		case "$entry" in
		"" | */* | .* ) continue ;;
		esac
		rm -rf -- "${SHELL_DIR:?}/$entry"
	done <"$SHELL_DIR/$MANIFEST"
	rm -f -- "$SHELL_DIR/$MANIFEST"
fi

mkdir -p -- "$SHELL_DIR" || fail "could not create $SHELL_DIR"

say "-- installing the shell into $SHELL_DIR"
: >"$work/manifest"
for path in "$UNPACKED"/*; do
	entry=$(basename -- "$path")
	# bin/ is the agent, which belongs on PATH rather than in a config directory.
	[ "$entry" = bin ] && continue
	cp -R -- "$path" "$SHELL_DIR/" || fail "could not write $SHELL_DIR/$entry"
	printf '%s\n' "$entry" >>"$work/manifest"
done
cp -- "$work/manifest" "$SHELL_DIR/$MANIFEST"

if [ -x "$UNPACKED/bin/bagent" ]; then
	say "-- installing bagent into $BIN_DIR"
	install -Dm755 -- "$UNPACKED/bin/bagent" "$BIN_DIR/bagent" ||
		fail "could not write $BIN_DIR/bagent"

	# Installed somewhere the shell will never look is the one failure that looks
	# like success, so it is checked rather than assumed.
	case ":$PATH:" in
	*":$BIN_DIR:"*) ;;
	*)
		say "-- WARNING: $BIN_DIR is not on your PATH"
		say "   The shell launches bagent by name, so it will not be found there."
		say "   Add it to PATH, or re-run with HYPRSHELL_BIN_DIR set somewhere that is."
		;;
	esac
fi

command -v qs >/dev/null 2>&1 ||
	say "-- WARNING: quickshell (qs) is not installed — the shell cannot start without it"
command -v hyprland >/dev/null 2>&1 || command -v Hyprland >/dev/null 2>&1 ||
	say "-- WARNING: Hyprland is not installed — the shell cannot start without it"

say ""
say "Installed hyprshell $version."
say ""
say "Add this to your hyprland.lua — the launch hook, and one bind per panel:"
say ""
cat <<'LUA'
    local hyprshell = os.getenv("HOME") .. "/.config/hyprshell"

    hl.on("hyprland.start", function()
        hl.exec_cmd("qs -p " .. hyprshell)
    end)

    hl.bind("SUPER + D", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call applauncher toggle"))
    hl.bind("SUPER + T", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call themeselector toggle"))
    hl.bind("SUPER + B", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call wallpaperselector toggle"))
    hl.bind("SUPER + X", hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call powermenu toggle"))
    hl.bind("Print",     hl.dsp.exec_cmd("qs ipc -p " .. hyprshell .. " call screenshot toggle"))
LUA
say ""
say "Then start it:"
say ""
say "    qs -p $SHELL_DIR"
