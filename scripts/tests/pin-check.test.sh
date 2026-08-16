#!/usr/bin/env bash
#
# Every outcome of the pin check in scripts/isolated-session.sh.
#
# This check has been written wrong three times, each time in a way that left it
# unable to report anything, and each time the run stayed green: first a jq
# alternative operator that fired on false as well as null, then a silence that
# could not be told from a healthy window, then a variable that was never
# assigned, which made every run blame the compositor for the script's own typo.
# None of those were caught by anything. This is that anything.
#
# The block is cut out of the real file rather than retyped, because a copy would
# pass while the shipped text was broken -- which is the shape of every failure
# above. hyprctl is stubbed, so no compositor is needed and this runs in the fast
# path alongside the Node and Python tests.
set -uo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_file="$repo/scripts/isolated-session.sh"
work=$(mktemp -d)
trap 'chmod -R u+w "$work" 2>/dev/null; rm -rf "$work"' EXIT

# From the warning helper to the first `fi` in the first column. Every `fi`
# inside the block is indented, so the first unindented one closes it. Anchoring
# on the text rather than on line numbers is what keeps this working when
# anything above it moves.
awk '/^pin_warning\(\) \{/ { inside = 1 } inside { print } inside && /^fi$/ { exit }' \
	"$source_file" >"$work/block.sh"

if [[ ! -s "$work/block.sh" ]] || ! grep -q '^fi$' "$work/block.sh"; then
	echo "-- FAILED: could not cut the pin check out of $source_file" >&2
	exit 1
fi

failures=0

expect() {
	local name="$1" stub="$2" writable="$3" pattern="$4"
	local dir="$work/$name"
	mkdir -p "$dir/bin" "$dir/session"
	printf '%s\n' "$stub" >"$dir/bin/hyprctl"
	chmod +x "$dir/bin/hyprctl"
	[[ "$writable" == "no" ]] && chmod a-w "$dir/session"

	local out
	out=$(
		PATH="$dir/bin:$PATH" \
			HYPRLAND_INSTANCE_SIGNATURE=stub \
			session_dir="$dir/session" \
			hypr_pid=4242 \
			bash "$work/block.sh" 2>&1
	)
	[[ "$writable" == "no" ]] && chmod u+w "$dir/session"

	if [[ "$pattern" == "<silence>" ]]; then
		if [[ -n "$out" ]]; then
			echo "-- FAILED: $name should have said nothing, said: $out" >&2
			failures=$((failures + 1))
		fi
		return
	fi

	if ! grep -qF -- "$pattern" <<<"$out"; then
		echo "-- FAILED: $name did not report \"$pattern\"; it said: ${out:-<silence>}" >&2
		failures=$((failures + 1))
	fi
}

expect pinned-true '#!/bin/sh
echo "[{\"pid\":4242,\"pinned\":true}]"' yes '<silence>'

expect pinned-false '#!/bin/sh
echo "[{\"pid\":4242,\"pinned\":false}]"' yes 'is not pinned'

expect window-absent '#!/bin/sh
echo "[{\"pid\":9999,\"pinned\":true}]"' yes 'not among your compositor'

expect hyprctl-fails '#!/bin/sh
echo "could not reach the compositor" >&2
exit 7' yes 'hyprctl exited 7; it said: could not reach the compositor'

# The shape a stub built on echo cannot produce, and the one a discarded
# `|| said=""` used to swallow: read returns non-zero at end of file even when it
# has already filled the variable, so the guard wiped what it had just captured.
expect fails-without-newline '#!/bin/sh
printf "no trailing newline" >&2
exit 9' yes 'hyprctl exited 9; it said: no trailing newline'

expect answered-empty '#!/bin/sh
exit 0' yes 'answered with nothing'

expect unwritable-error-path '#!/bin/sh
echo "[{\"pid\":4242,\"pinned\":true}]"' no 'The fault is here, not in your compositor'

if [[ "$failures" -ne 0 ]]; then
	echo "-- FAILED: $failures pin check outcome(s) wrong" >&2
	exit 1
fi

echo "pin check: every outcome named, and each one reachable"
