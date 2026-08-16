#!/usr/bin/env bash
#
# Every outcome of the pin check in scripts/isolated-session.sh.
#
# The check warns when the nested compositor's window will stop being drawn,
# which is the difference between a stage that fails and a stage that hangs
# looking like a regression. It has been written unable to report anything three
# times — a jq alternative operator that fired on false as well as null, then a
# silence that could not be told from a healthy window, then a variable that was
# never assigned, which made every run blame the compositor for a typo in the
# script. None of those were caught by anything. This is that anything.
#
# The block is cut out of the real file rather than retyped, because a copy would
# keep passing while the shipped text was broken, which is the shape of all three
# failures above. hyprctl is stubbed, so no compositor is needed.
set -uo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_file="$repo/scripts/isolated-session.sh"

# The block does nothing at all without jq, so without it every case would see
# silence and six of the seven would fail saying they expected some text — six
# messages, none of them naming the cause. Said once, in the words of the thing
# that is actually missing. Non-zero because a check that could not run is not a
# check that passed, which is how the rest of this suite treats a missing tool.
if ! command -v jq >/dev/null 2>&1; then
	echo "-- INCONCLUSIVE: jq is not installed, so the pin check cannot run and this proves nothing" >&2
	exit 1
fi

work=$(mktemp -d)
trap 'chmod -R u+w "$work" 2>/dev/null; rm -rf "$work"' EXIT

# From the warning helper to the first `fi` in the first column. Every `fi`
# inside the block is indented, so the first unindented one closes it. Anchoring
# on text rather than line numbers is what keeps this working when anything
# above it moves.
awk '/^pin_warning\(\) \{/ { inside = 1 } inside { print } inside && /^fi$/ { exit }' \
	"$source_file" >"$work/block.sh"

# What the block has to contain to be the block, rather than merely being some
# text that ends in `fi`. The extraction stops at the first unindented `fi`, so
# checking for one proves nothing — it is there by construction, and it would
# still be there if a different construct had been captured instead. These three
# are the query, the interpretation and the reporting: cut the wrong region and
# at least one goes missing.
#
# The third carries the space and the quote on purpose. Bare `pin_warning` is
# the name in the definition the extraction starts on, so it is printed as the
# first line of every possible capture and can never be absent — the same
# nothing the `fi` was, written into the guard meant to replace it. With the
# quote it matches only the calls, and a region cut short of them has none.
for needle in 'hyprctl clients -j' 'pinned' 'pin_warning "'; do
	if ! grep -qF -- "$needle" "$work/block.sh"; then
		# Single quotes around the needle, because one of them ends in a double
		# quote and nesting it inside another pair reads as a typo.
		echo "-- FAILED: the text cut out of $source_file does not contain '$needle';" >&2
		echo "   the pin check has moved or been renamed and this test is reading the wrong lines." >&2
		exit 1
	fi
done

failures=0
skipped=0
cases=0

# `writable` is the third of four positionals and spells itself out at the call
# sites — `writable` or `unwritable`, not a bare yes or no, so a reader scanning
# a call knows what the word is about without coming up here. It stays a word
# rather than becoming a flag because only one of the seven cases differs, and
# that one is named for it.
expect() {
	local name="$1" stub="$2" writable="$3" pattern="$4"
	local dir="$work/$name"
	mkdir -p "$dir/bin" "$dir/session"
	printf '%s\n' "$stub" >"$dir/bin/hyprctl"
	chmod +x "$dir/bin/hyprctl"

	if [[ "$writable" == "unwritable" ]]; then
		chmod a-w "$dir/session"
		# Root ignores the write bit, and so does anything holding
		# CAP_DAC_OVERRIDE, which is ordinary inside a container. Asking the
		# filesystem whether the chmod took is the only honest test: assuming it
		# did would fail this case for a reason that has nothing to do with the
		# code, and assuming it did not would skip it on the machines where it
		# works.
		if [[ -w "$dir/session" ]]; then
			echo "-- SKIPPED: $name needs a directory this user cannot write, and this one can write it anyway" >&2
			chmod u+w "$dir/session"
			skipped=$((skipped + 1))
			return
		fi
	fi

	local out
	out=$(
		PATH="$dir/bin:$PATH" \
			HYPRLAND_INSTANCE_SIGNATURE=stub \
			session_dir="$dir/session" \
			hypr_pid=4242 \
			bash "$work/block.sh" 2>&1
	)
	cases=$((cases + 1))
	[[ "$writable" == "unwritable" ]] && chmod u+w "$dir/session"

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
echo "[{\"pid\":4242,\"pinned\":true}]"' writable '<silence>'

expect pinned-false '#!/bin/sh
echo "[{\"pid\":4242,\"pinned\":false}]"' writable 'is not pinned'

expect window-absent '#!/bin/sh
echo "[{\"pid\":9999,\"pinned\":true}]"' writable 'not among your compositor'

expect hyprctl-fails '#!/bin/sh
echo "could not reach the compositor" >&2
exit 7' writable 'hyprctl exited 7; it said: could not reach the compositor'

# The shape a stub built on echo cannot produce, and the one a discarded
# `|| said=""` used to swallow: read returns non-zero at end of file even when it
# has already filled the variable, so the guard wiped what it had just captured.
expect fails-without-newline '#!/bin/sh
printf "no trailing newline" >&2
exit 9' writable 'hyprctl exited 9; it said: no trailing newline'

expect answered-empty '#!/bin/sh
exit 0' writable 'answered with nothing'

expect unwritable-error-path '#!/bin/sh
echo "[{\"pid\":4242,\"pinned\":true}]"' unwritable 'The fault is here, not in your compositor'

if [[ "$failures" -ne 0 ]]; then
	echo "-- FAILED: $failures pin check outcome(s) wrong" >&2
	exit 1
fi

# The count is in the line because a skip used to be invisible from here: the
# SKIPPED case returned without touching `failures`, so six of seven cases
# passing printed the same words and the same status as seven, and the words
# said every outcome was reachable. Whoever reads only this line and the exit
# code — which is what CI reads — was told something that was not true.
if [[ "$skipped" -ne 0 ]]; then
	echo "pin check: $cases outcomes named, $skipped skipped and therefore unproven (see above)"
else
	echo "pin check: all $cases outcomes named, and each one reachable"
fi
