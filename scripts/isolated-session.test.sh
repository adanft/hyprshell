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

# The rule installer, cut out the same way and driven against a stubbed hyprctl.
#
# It is here because of the trap inside it: against a Lua config `hyprctl
# keyword` refuses the rule and still exits 0, so an installer that trusts the
# status reports success while the window retiles the workspace anyway. That is
# a check that cannot fail wearing a different hat, and nothing else in the
# suite would notice — the run still passes, it just moves your windows.
# Two functions, because the installer calls the one that decides what counts as
# a refusal and neither is any use alone. Cut separately and joined, so the
# sourced file has both and the extraction still anchors on text.
awk '/^keyword_refused\(\) \{/ { inside = 1 } inside { print } inside && /^\}$/ { exit }' \
	"$source_file" >"$work/install.sh"
awk '/^install_window_rule\(\) \{/ { inside = 1 } inside { print } inside && /^\}$/ { exit }' \
	"$source_file" >>"$work/install.sh"

# The query, the refusal text, the honest route, and the call that joins them.
# The last carries a space and a quote so it matches the call and not the
# definition the extraction starts on — a bare name would be printed as the
# first line of every possible capture and could never be missing.
for needle in 'hyprctl eval' 'non-legacy parsers' 'hyprctl keyword' 'keyword_refused "'; do
	if ! grep -qF -- "$needle" "$work/install.sh"; then
		echo "-- FAILED: the text cut out of $source_file does not contain '$needle';" >&2
		echo "   the rule installer has moved or been renamed and this test is reading the wrong lines." >&2
		exit 1
	fi
done

failures=0
skipped=0
cases=0

# `stub` is the body of a fake hyprctl. `want` is the exit status the installer
# should reach with it.
#
# Counted into the same `failures` and `cases` as everything below rather than
# kept apart. The first version had its own counter and exited on the spot,
# which cost twice: a failure here hid any pin check regression happening at the
# same time, and on the way through, three outcomes ran that the closing line
# never counted — so it named a total three short of what had actually been
# exercised, in a file whose whole point is that the last line tells the truth.
#
# Only 127 can come back from a broken extraction — measured, against a
# truncated function, a missing file and a function under another name — and no
# case wants 127, so a capture that failed to capture cannot pass as a refusal.
expect_install() {
	local name="$1" stub="$2" want="$3"
	local dir="$work/install-$name"
	mkdir -p "$dir/bin"
	printf '%s\n' "$stub" >"$dir/bin/hyprctl"
	chmod +x "$dir/bin/hyprctl"

	local got
	PATH="$dir/bin:$PATH" bash -c "source '$work/install.sh'; install_window_rule" >/dev/null 2>&1
	got=$?
	cases=$((cases + 1))

	if [[ "$got" -ne "$want" ]]; then
		echo "-- FAILED: $name should have returned $want, returned $got" >&2
		failures=$((failures + 1))
	fi
}

# A Lua config: eval takes it, and nothing else is needed.
expect_install lua-config '#!/bin/sh
[ "$1" = "eval" ] && exit 0
exit 1' 0

# A legacy config: eval has no Lua to run, keyword accepts.
expect_install legacy-config '#!/bin/sh
[ "$1" = "eval" ] && exit 1
exit 0' 0

# The shape that must not read as success. Both refuse, and keyword lies with a
# zero status while saying so in its output — which is why the output is what
# gets read.
expect_install both-refuse '#!/bin/sh
[ "$1" = "eval" ] && exit 1
echo "keyword can'"'"'t work with non-legacy parsers. Use eval."
exit 0' 1

# The outcome the other three cannot reach, and the one that matters most.
#
# Every stub above keys only on whether the first argument is `eval`, so the pin
# call always shares the float call's fate. A compositor that takes float and
# refuses pin is a real state, and it is the worst one: the window floats, so
# nothing retiles and everything looks right, and then it stops being drawn the
# moment you switch workspace — exactly the timeout this file exists to prevent.
# An earlier version of the installer returned success there.
#
# Capitalised on purpose. The refusal is matched case-insensitively now, and
# this is what says so: the previous spelling cut the leading letter off the
# word to catch both, which worked and read as a typo.
expect_install float-ok-pin-refused '#!/bin/sh
[ "$1" = "eval" ] && exit 1
case "$3" in
pin*) echo "Invalid rule"; exit 0 ;;
esac
exit 0' 1

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
	echo "-- FAILED: $failures outcome(s) wrong" >&2
	exit 1
fi

# The count is in the line because a skip used to be invisible from here: the
# SKIPPED case returned without touching `failures`, so six of seven cases
# passing printed the same words and the same status as seven, and the words
# said every outcome was reachable. Whoever reads only this line and the exit
# code — which is what CI reads — was told something that was not true.
if [[ "$skipped" -ne 0 ]]; then
	echo "isolated session: $cases outcomes named, $skipped skipped and therefore unproven (see above)"
else
	echo "isolated session: all $cases outcomes named, and each one reachable"
fi
