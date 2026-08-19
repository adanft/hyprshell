#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

make_archive() {
  local root="$1"
  shift
  mkdir -p "$root/hyprshell"
  printf 'qml\n' >"$root/hyprshell/shell.qml"
  printf 'v-test\n' >"$root/hyprshell/VERSION"
  mkdir -p "$root/hyprshell/Wallpapers"
  for name in "$@"; do printf '%s\n' "$name" >"$root/hyprshell/Wallpapers/$name"; done
  tar -czf "$root/hyprshell.tar.gz" -C "$root" hyprshell
  sha256sum "$root/hyprshell.tar.gz" | sed "s#  $root/#  #" >"$root/hyprshell.tar.gz.sha256"
}

run_install() {
  HOME="$work/home" XDG_CONFIG_HOME="$work/config" HYPRSHELL_BASE_URL="file://$1" \
    HYPRSHELL_BIN_DIR="$work/bin" sh "$repo/install.sh" >/dev/null
}

mkdir -p "$work/home" "$work/config" "$work/bin"
make_archive "$work/release-one" starter-one.png starter-two.jpg
run_install "$work/release-one"
[[ -f "$work/home/Wallpapers/starter-one.png" ]]
[[ -f "$work/home/Wallpapers/starter-two.jpg" ]]
[[ ! -e "$work/config/hyprshell/Wallpapers" ]]
! grep -q '^Wallpapers$' "$work/config/hyprshell/.install-manifest"

printf 'user wallpaper\n' >"$work/home/Wallpapers/starter-one.png"
user_hash=$(sha256sum "$work/home/Wallpapers/starter-one.png")
make_archive "$work/release-two" starter-one.png starter-two.jpg starter-three.webp
run_install "$work/release-two"
[[ "$(sha256sum "$work/home/Wallpapers/starter-one.png")" == "$user_hash" ]]
[[ -f "$work/home/Wallpapers/starter-three.webp" ]]

printf 'current shell\n' >"$work/config/hyprshell/shell.qml"
mkdir -p "$work/bad/hyprshell"
printf 'bad\n' >"$work/bad/hyprshell/shell.qml"
printf 'v-bad\n' >"$work/bad/hyprshell/VERSION"
tar -czf "$work/bad/hyprshell.tar.gz" -C "$work/bad" hyprshell
sha256sum "$work/bad/hyprshell.tar.gz" | sed "s#  $work/bad/#  #" >"$work/bad/hyprshell.tar.gz.sha256"
if run_install "$work/bad"; then
  echo 'malformed payload unexpectedly passed' >&2
  exit 1
fi
[[ "$(cat "$work/config/hyprshell/shell.qml")" == 'current shell' ]]
[[ "$(sha256sum "$work/home/Wallpapers/starter-three.webp")" != '' ]]

echo "WALLPAPER-TEST: 3 scenarios passed"
