#!/usr/bin/env bash
#
# Runs the whole suite: Node contract tests, Python benchmark tests, QML
# component tests, then the QML smoke test.
#
#     ./run-tests.sh              all four stages
#     ./run-tests.sh --js         Node + Python tests; QML/compositor skipped
#
# --js omits the compositor-dependent QML stages but still runs the Python
# benchmark tests.
#
# Exits non-zero if any stage fails or is inconclusive.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

readonly SMOKE_TIMEOUT=30
readonly SUCCESS_LINE='SMOKETEST: all components instantiated'
readonly CAPTURE_LINE='SMOKETEST: capture top-level delta=0 | type=PanelWindow'
readonly LIFECYCLE_LINE='SMOKETEST: notification lifecycle capture/card/center/dnd/host/error passed'
readonly ROLES_LINE='SMOKETEST: 16 colour roles resolved'
readonly TIMEOUT_HARNESS_LINE='TIMEOUT-HARNESS: two-copy hover/remaining/destruction/critical/dnd/single-close passed'
readonly OVERLAY_LIFECYCLE_LINE='OVERLAY-LIFECYCLE-HARNESS: close/reopen/self-close all destroy the item'

# Emitted whenever another notification daemon already owns the D-Bus name,
# which is the normal case while a shell is running. Matched literally rather
# than by category, so a genuine NotificationService fault still fails the run.
readonly ENVIRONMENTAL='Could not register notification server at org.freedesktop.Notifications|Registration will be attempted again if the active service is unregistered'

js_only=false
[[ "${1:-}" == "--js" ]] && js_only=true

failed=0

echo "== Node contract tests =="
if node --test; then
	echo "-- Node tests passed"
else
	echo "-- Node tests FAILED"
	failed=1
fi

echo
echo "== Python benchmark tests =="
if python3 scripts/qsrice-bench.test.py; then
	echo "-- Python benchmark tests passed"
else
	echo "-- Python benchmark tests FAILED"
	failed=1
fi

if [[ "$js_only" == true ]]; then
	echo "== QML component tests SKIPPED (--js) =="
	echo "== QML smoke test SKIPPED (--js) =="
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

# smoketest.qml calls Qt.quit() on its own; the timeout only catches a hang.
smoke_output=$(timeout "$SMOKE_TIMEOUT" qs -p smoketest.qml 2>&1)
smoke_status=$?

# Strip ANSI colour so the pattern matching sees plain text.
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

# A colour role whose QML binding never took reads as black, which no static
# check can see. The smoke test compares every role against its palette.
if ! grep -qF "$ROLES_LINE" <<<"$smoke_output"; then
	echo "-- FAILED: the 16 colour roles did not resolve to their palette"
	failed=1
fi

if grep -qF 'NotificationImageCaptureWindow' <<<"$smoke_output"; then
	echo "-- FAILED: dedicated notification capture window was instantiated"
	failed=1
fi

# QML warnings do not affect the exit code, so they are checked separately.
# This is the whole reason the smoke test needs a wrapper at all.
problems=$(grep -E '(WARN|ERROR)' <<<"$smoke_output" | grep -Ev "$ENVIRONMENTAL")
if [[ -n "$problems" ]]; then
	echo "-- FAILED: smoke test reported warnings or errors:"
	printf '%s\n' "$problems" | sed 's/^/   /'
	failed=1
fi

if [[ "$failed" -eq 0 ]]; then
	echo "-- Smoke test passed: every window instantiated, no warnings"
fi

echo
if [[ "$failed" -eq 0 ]]; then
	echo "All checks passed."
else
	echo "Checks FAILED."
fi
exit "$failed"
