#!/usr/bin/env bash
#
# Builds bagent and puts it where the shell can find it.
#
#     ./install.sh                        into ~/.local/bin
#
#     ./install.sh                        for everyone on the machine: build as
#     PREFIX=/usr/local sudo ./install.sh  yourself, then install as root
#
# bagent is the Bluetooth pairing agent. Quickshell cannot serve a D-Bus object,
# so `org.bluez.Agent1` lives in this separate process; without it every pairing
# that needs a person to confirm a code is refused before you see it.
#
# The shell launches it by name, the same way it launches bluetoothctl and grim,
# so what matters is that it lands somewhere on PATH. Nothing else is installed:
# the shell itself runs from this directory.
#
# Exits non-zero if the build fails or the binary cannot be placed.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

readonly PREFIX="${PREFIX:-$HOME/.local}"
readonly BIN_DIR="$PREFIX/bin"
readonly TARGET="$BIN_DIR/bagent"
readonly BUILT="bagent/target/release/bagent"

echo "== bagent =="

if ! command -v cargo >/dev/null 2>&1; then
	echo "-- FAILED: cargo is not installed"
	echo "   Rust builds this. On Arch: pacman -S rust"
	exit 1
fi

# Never as root.
#
# The documented system-wide install runs this whole script under sudo, and a
# build under sudo compiles every dependency in the tree as root — running each
# crate's build script and proc macro with privileges none of them need. Only
# placing the file needs root, so under root the build is refused and an
# already-built binary is required instead.
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
	if [[ ! -x "$BUILT" ]]; then
		echo "-- FAILED: refusing to build as root"
		echo "   Build it as yourself first, then install:"
		echo "       ./install.sh"
		echo "       PREFIX=/usr/local sudo ./install.sh"
		exit 1
	fi
	echo "-- using the binary already built (a root build is refused)"
else
	echo "-- building (release)"
	if ! cargo build --release --manifest-path bagent/Cargo.toml; then
		echo "-- FAILED: the build did not finish"
		exit 1
	fi
fi

if [[ ! -x "$BUILT" ]]; then
	echo "-- FAILED: $BUILT is missing after a build that reported success"
	exit 1
fi

# -D creates the directory, and the mode is stated rather than inherited from
# whatever umask happens to be in force.
if ! install -Dm755 "$BUILT" "$TARGET"; then
	echo "-- FAILED: could not write $TARGET"
	if [[ ! -w "$BIN_DIR" && ! -w "$PREFIX" ]]; then
		echo "   $BIN_DIR is not writable."
		echo "   Re-run with sudo, or leave PREFIX at its default."
	fi
	exit 1
fi

echo "-- installed: $TARGET"

# Installed somewhere the shell will never look is the one failure that looks
# like success, so it is checked rather than assumed.
case ":$PATH:" in
*":$BIN_DIR:"*)
	;;
*)
	echo "-- WARNING: $BIN_DIR is not on your PATH"
	echo "   The shell launches bagent by name, so it will not be found there."
	echo "   Add it to PATH, or install with PREFIX=/usr/local instead."
	;;
esac

resolved="$(command -v bagent 2>/dev/null)"
if [[ -n "$resolved" && "$resolved" != "$TARGET" ]]; then
	echo "-- WARNING: another bagent comes first on PATH: $resolved"
	echo "   That one is what the shell will run."
fi

echo
echo "The shell starts and stops it with the Bluetooth adapter, so there is no"
echo "service to enable. Restart the shell to pick this up:"
echo
echo "    pkill -x qs && qs -p $(pwd)"
