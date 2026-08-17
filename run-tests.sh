#!/usr/bin/env bash
#
# Runs the whole suite: Node contract tests, Python benchmark tests, QML
# component tests, then the QML smoke test.
#
#     ./run-tests.sh              all four stages, on the compositor you are using
#     ./run-tests.sh --isolated   the same four, compositor stages nested away
#     ./run-tests.sh --js         Node + Python tests; QML/compositor skipped
#
# --js omits the compositor-dependent QML stages but still runs the Python
# benchmark tests.
#
# --isolated runs those stages inside a throwaway nested Hyprland instead, so
# the exclusive zone the status bar reserves and the `hyprctl reload` the theme
# runs land there rather than on your desktop. Prefer it while you are working
# in the session; see scripts/isolated-session.sh.
#
# Exits non-zero if any stage fails or is inconclusive.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

readonly SMOKE_TIMEOUT=30
readonly SUCCESS_LINE='SMOKETEST: all components instantiated'
readonly CAPTURE_LINE='SMOKETEST: capture top-level delta=0 | type=PanelWindow'
readonly LIFECYCLE_LINE='SMOKETEST: notification lifecycle capture/card/center/dnd/host/error passed'
readonly ROLES_LINE='SMOKETEST: 16 color roles resolved'
readonly TIMEOUT_HARNESS_LINE='TIMEOUT-HARNESS: two-copy hover/remaining/destruction/critical/dnd/single-close passed'
readonly OVERLAY_LIFECYCLE_LINE='OVERLAY-LIFECYCLE-HARNESS: close/reopen/self-close all destroy the item'
readonly PANEL_INTERACTION_LINE='PANEL-INTERACTION-HARNESS: open/displace/close/reopen passed'
readonly CENTER_INTERACTION_LINE='CENTER-INTERACTION-HARNESS: control center and notification center passed'

# Measured cycles for the resource stage, after the unmeasured warm-up one, and
# the number is what buys the margin rather than the threshold is.
#
# The descriptor noise floor was measured at 2 and it does not move with the
# cycle count: three cycles read +2.0, +1.0, +1.5, -0.5 and five cycles read
# +2.0, -1.0, -1.5. A leak does move with it — one descriptor per cycle is a
# delta of five here. So five leaves three between the smallest leak worth
# catching and the largest drift ever seen, where three left one. Raise it to
# widen that gap further; the threshold itself must not be raised, because
# doing so is what would hide the leak.
readonly CYCLE_BENCH_CYCLES="${CYCLE_BENCH_CYCLES:-5}"

# Qt asks the desktop portal to register an application ID and the connection
# already carries one. Measured: an empty ShellRoot prints it too, before any of
# this shell's code runs, so it reports the session rather than the shell. It is
# dropped only for the panel harness, which is the one stage that reads warnings
# from a run that opens real overlays.
readonly PLATFORM_NOISE='Failed to register with host portal'

# Emitted whenever another notification daemon already owns the D-Bus name,
# which is the normal case while a shell is running. Matched literally rather
# than by category, so a genuine NotificationService fault still fails the run.
readonly ENVIRONMENTAL='Could not register notification server at org.freedesktop.Notifications|Registration will be attempted again if the active service is unregistered'

js_only=false
isolated=false
compositor_only=false

case "${1:-}" in
	"") ;;
	--js) js_only=true ;;
	--isolated) isolated=true ;;
	# Internal, set by scripts/isolated-session.sh once the throwaway session is
	# up. Typed by hand it still runs against whatever compositor is in reach,
	# which is the thing --isolated exists to avoid.
	--compositor-stages) compositor_only=true ;;
	*)
		echo "usage: $0 [--js|--isolated]" >&2
		exit 2
		;;
esac

# On the private bus an isolated run gets, nothing else owns
# org.freedesktop.Notifications, so the shell takes it and the message above
# never appears. Keeping the filter on would mean the one run that can prove the
# notification server registers is also the one that would not notice if it
# stopped. A pattern that matches no line at all is how that is said to grep.
if [[ "$compositor_only" == true ]]; then
	readonly WARNING_FILTER='$^'
else
	readonly WARNING_FILTER="$ENVIRONMENTAL"
fi

failed=0

if [[ "$compositor_only" == false ]]; then
	echo "== Node contract tests =="
	if node --test; then
		echo "-- Node tests passed"
	else
		echo "-- Node tests FAILED"
		failed=1
	fi

	echo
	echo "== Python benchmark tests =="
	if python3 scripts/hyprshell-bench.test.py; then
		echo "-- Python benchmark tests passed"
	else
		echo "-- Python benchmark tests FAILED"
		failed=1
	fi

	# The pin check drives a stubbed hyprctl, so it needs no compositor and
	# belongs here rather than among the stages that build one. It is the only
	# shell in this repository with a test, and it earned one: the check it
	# covers has been written wrong three times, every time in a way that left it
	# reporting nothing, and every time the suite stayed green.
	echo
	echo "== Shell tests =="
	if ./scripts/isolated-session.test.sh; then
		echo "-- Shell tests passed"
	else
		echo "-- Shell tests FAILED"
		failed=1
	fi

	if [[ "$js_only" == true ]]; then
		echo "== QML component tests SKIPPED (--js) =="
		echo "== QML smoke test SKIPPED (--js) =="
		exit "$failed"
	fi
fi

# Everything below reserves a layer-shell exclusive zone and can make the shell
# reload Hyprland. Handing that a compositor of its own is the difference
# between testing the shell and rearranging the desktop you are sitting at.
if [[ "$isolated" == true ]]; then
	echo
	echo "== Compositor stages, isolated session =="
	scripts/isolated-session.sh "$PWD/run-tests.sh" --compositor-stages || failed=1

	echo
	if [[ "$failed" -eq 0 ]]; then
		echo "All checks passed."
	else
		echo "Checks FAILED."
	fi
	exit "$failed"
fi

echo
echo "== QML component tests =="

if ! resolved_qmltestrunner=$(scripts/find-qmltestrunner.sh); then
	echo "-- INCONCLUSIVE: qmltestrunner not found via QMLTESTRUNNER, PATH, or distro fallbacks"
	failed=1
else
	readonly QMLTESTRUNNER="$resolved_qmltestrunner"
	# Each file runs from its own directory, because the tests reach their
	# subjects through a relative import.
	for test_file in tests/tst_*.qml features/controlcenter/tests/tst_*.qml theme/runtime/tests/tst_*.qml; do
		test_dir=$(dirname "$test_file")
		test_name=$(basename "$test_file")
		if output=$(cd "$test_dir" && timeout 60 "$QMLTESTRUNNER" -input "$test_name" 2>&1); then
			printf -- "-- %-42s %s\n" "$test_name" "$(grep -E '^Totals:' <<<"$output")"
		else
			printf -- "-- %-42s FAILED\n" "$test_name"
			grep -E '^(FAIL|QWARN)' <<<"$output" | sed 's/^/     /'
			failed=1
		fi
	done
fi

echo
echo "== QML smoke test =="

if ! command -v qs >/dev/null 2>&1; then
	echo "-- INCONCLUSIVE: quickshell (qs) is not installed"
	exit 1
fi

if [[ -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" ]]; then
	echo "-- INCONCLUSIVE: no WAYLAND_DISPLAY or DISPLAY; the overlays cannot"
	echo "   be instantiated without a compositor. Re-run inside a session, or"
	echo "   use --js to run the Node tests alone."
	exit 1
fi

echo
echo "== QML notification timeout harness =="
timeout_output=$(timeout 15 qs -p notification-timeout-harness.qml 2>&1)
timeout_status=$?
timeout_output=$(printf '%s\n' "$timeout_output" | sed -E 's/\x1b\[[0-9;]*m//g')
if [[ "$timeout_status" -ne 0 ]] || ! grep -qF "$TIMEOUT_HARNESS_LINE" <<<"$timeout_output"; then
	echo "-- FAILED: notification timeout harness"
	printf '%s\n' "$timeout_output" | sed 's/^/   /'
	failed=1
else
	echo "-- Notification timeout harness passed"
fi

# Whether a closed overlay is destroyed can only be seen by running the loader:
# the source-text assertion that used to cover it passed for eight months while
# the observing block never instantiated.
echo
echo "== QML overlay lifecycle harness =="
lifecycle_output=$(timeout 15 qs -p overlay-lifecycle-harness.qml 2>&1)
lifecycle_status=$?
lifecycle_output=$(printf '%s\n' "$lifecycle_output" | sed -E 's/\x1b\[[0-9;]*m//g')
if [[ "$lifecycle_status" -ne 0 ]] || ! grep -qF "$OVERLAY_LIFECYCLE_LINE" <<<"$lifecycle_output"; then
	echo "-- FAILED: overlay lifecycle harness"
	printf '%s\n' "$lifecycle_output" | sed 's/^/   /'
	failed=1
else
	echo "-- Overlay lifecycle harness passed"
fi

# Both interaction harnesses are read the same way, so they are read by the same
# function: a success line to match literally, a warning scan on top of it, and a
# count to report. Written twice, a later fix to one drifts from the other.
#
# The warnings matter as much as the verdict here, which is what separates these
# two stages from the harnesses above. A panel that opens with a broken binding
# says so in a warning and still returns a perfectly good success line.
#
#   $1 label, $2 qml file, $3 success line, $4 what is counted, $5 timeout
run_interaction_harness() {
	local label="$1" file="$2" marker="$3" noun="$4" seconds="$5"
	local output status problems count

	output=$(timeout "$seconds" qs -p "$file" 2>&1)
	status=$?
	output=$(printf '%s\n' "$output" | sed -E 's/\x1b\[[0-9;]*m//g')
	problems=$(grep -E '(WARN|ERROR)' <<<"$output" | grep -Fv "$PLATFORM_NOISE")

	if [[ "$status" -ne 0 ]] || ! grep -qF "$marker" <<<"$output"; then
		echo "-- FAILED: $label harness"
		printf '%s\n' "$output" | sed 's/^/   /'
		return 1
	fi

	if [[ -n "$problems" ]]; then
		echo "-- FAILED: the $label harness reported warnings or errors:"
		printf '%s\n' "$problems" | sed 's/^/   /'
		return 1
	fi

	count=$(grep -o "$noun exercised: [0-9]*" <<<"$output" | grep -o '[0-9]*$')
	echo "-- Passed: $label, ${count:-?} $noun"
}

# The lifecycle harness above drives the real loader against a stub, and
# smoketest.qml builds the real overlays without ever opening one. Neither of
# them opens a real overlay the way shell.qml does, which is what this stage is
# for: through the arbiter, through the lazy loader, into the panel's own open().
echo
echo "== QML panel interaction harness =="
run_interaction_harness "panel interaction" panel-interaction-harness.qml \
	"$PANEL_INTERACTION_LINE" overlays 30 || failed=1

# The other two panels, which do not open like those five. The control center
# rises through a signal into a handler inside BarWindow and a loader that
# BarWindow keeps to itself; the notification center is the one loader in the
# shell with directVisibility set, a branch nothing else here has ever taken.
echo
echo "== QML center interaction harness =="
run_interaction_harness "center interaction" center-interaction-harness.qml \
	"$CENTER_INTERACTION_LINE" sections 40 || failed=1

# smoketest.qml calls Qt.quit() on its own; the timeout only catches a hang.
smoke_output=$(timeout "$SMOKE_TIMEOUT" qs -p smoketest.qml 2>&1)
smoke_status=$?

# Strip ANSI color so the pattern matching sees plain text.
smoke_output=$(printf '%s\n' "$smoke_output" | sed -E 's/\x1b\[[0-9;]*m//g')

if [[ "$smoke_status" -eq 124 ]]; then
	echo "-- FAILED: smoke test did not exit within ${SMOKE_TIMEOUT}s"
	failed=1
elif [[ "$smoke_status" -ne 0 ]]; then
	echo "-- FAILED: quickshell exited with status $smoke_status"
	failed=1
fi

if ! grep -qF "$SUCCESS_LINE" <<<"$smoke_output"; then
	echo "-- FAILED: smoke test never reported success"
	failed=1
fi

if ! grep -qF "$CAPTURE_LINE" <<<"$smoke_output"; then
	echo "-- FAILED: capture host was not proven to reuse status bar windows"
	failed=1
fi

if ! grep -qF "$LIFECYCLE_LINE" <<<"$smoke_output"; then
	echo "-- FAILED: notification image lifecycle harness did not complete"
	failed=1
fi

# A color role whose QML binding never took reads as black, which no static
# check can see. The smoke test compares every role against its palette.
if ! grep -qF "$ROLES_LINE" <<<"$smoke_output"; then
	echo "-- FAILED: the 16 color roles did not resolve to their palette"
	failed=1
fi

if grep -qF 'NotificationImageCaptureWindow' <<<"$smoke_output"; then
	echo "-- FAILED: dedicated notification capture window was instantiated"
	failed=1
fi

# QML warnings do not affect the exit code, so they are checked separately.
# This is the whole reason the smoke test needs a wrapper at all.
problems=$(grep -E '(WARN|ERROR)' <<<"$smoke_output" | grep -Ev "$WARNING_FILTER")
if [[ -n "$problems" ]]; then
	echo "-- FAILED: smoke test reported warnings or errors:"
	printf '%s\n' "$problems" | sed 's/^/   /'
	failed=1
fi

if [[ "$failed" -eq 0 ]]; then
	echo "-- Smoke test passed: every window instantiated, no warnings"
fi

# Last because it is the slowest, and because everything above has to hold
# before its numbers mean anything: this is the only stage that runs shell.qml
# itself. It measures the shell twice — sitting idle, which is where a desktop
# shell spends nearly all its life and which nothing else here looks at, and
# then while every overlay is opened over IPC the way a person does.
#
# See scripts/shell-cycle-bench.sh for which numbers fail the run: descriptors
# in both phases and processor use while idle. Memory is reported and never
# fails, because a threshold tight enough to catch a leak in RSS also fails on
# an allocator having a quiet day.
echo
echo "== Shell overlay cycles and resources =="
#
# Bounded from out here as well as from inside. The stage guards each of its own
# IPC calls, but it is the only one that runs a shell for the length of a
# benchmark, and every other qs invocation in this file is wrapped, so leaving
# this one unwrapped would make it the single step able to hang the whole run.
# The number is a backstop, not a schedule: the stage takes about forty seconds
# at three cycles, so raising CYCLE_BENCH_CYCLES far past that needs this raised
# with it.
# -k because the stage traps TERM to clean up its children: a trap that ever
# wedged would swallow the bound this line exists to be.
timeout -k 10 300 scripts/shell-cycle-bench.sh "$CYCLE_BENCH_CYCLES"
cycle_status=$?
if [[ "$cycle_status" -eq 0 ]]; then
	echo "-- Overlay cycles passed: idle is quiet, no descriptor growth"
else
	if [[ "$cycle_status" -eq 124 ]]; then
		echo "-- FAILED: overlay cycle benchmark did not finish within 300s"
	else
		echo "-- FAILED: overlay cycle benchmark"
	fi
	failed=1
fi

echo
# Under --compositor-stages this is one half of a run whose other half already
# reported; the verdict belongs to the parent, which owns the exit code.
if [[ "$compositor_only" == false ]]; then
	if [[ "$failed" -eq 0 ]]; then
		echo "All checks passed."
	else
		echo "Checks FAILED."
	fi
fi
exit "$failed"
