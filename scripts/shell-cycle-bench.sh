#!/usr/bin/env bash
#
# Opens and closes every overlay on the real shell, repeatedly, and reports what
# that costs.
#
#     scripts/shell-cycle-bench.sh [cycles]
#
# This is the only stage that runs shell.qml itself. Every other one composes
# the pieces: the harnesses build their own arbiter and loaders, and smoketest
# instantiates the panels directly. None of them can say whether shell.qml's own
# wiring works, because none of them use it — the five IpcHandler blocks that
# actually open these overlays have never been called by a test.
#
# So this drives them the way a person does, through `qs ipc`, while
# qsrice-bench.py samples the process tree.
#
# The verdict is deliberately lopsided:
#
#   File descriptors are a hard failure. A socket, a file or a watch that a
#     closed overlay did not release shows up here and nowhere else, and the
#     number is an integer that does not drift on its own.
#
#   Memory is reported and never fails. RSS moves with the allocator and the
#     caches underneath it, so a threshold tight enough to catch a real leak is
#     also tight enough to fail on nothing at all. The trend is printed so a
#     person can look; it is not something to fail a merge on.
#
# Exits non-zero on a descriptor leak, a shell that died or logged a problem, or
# a bench that could not sample.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

readonly CYCLES="${1:-3}"
readonly TARGETS=(applauncher powermenu wallpaperselector themeselector screenshot)
readonly READY_TIMEOUT=20
readonly SETTLE=0.3

# Every `qs ipc` call is wrapped in this. A loop deadline is only re-read
# between iterations, so an IPC call that blocks rather than answering is a
# deadline that never fires — and the shell being alive but not answering is
# precisely the state the readiness loop below exists to detect, so the one
# check that must survive it cannot be the one without a bound. These calls
# answer in milliseconds when they answer at all.
readonly IPC_TIMEOUT=5
readonly WARMUP=2
readonly INTERVAL=1

# Qt asks the desktop portal for an application ID the connection already
# carries. An empty ShellRoot prints it too, so it reports the session rather
# than this shell.
readonly PLATFORM_NOISE='Failed to register with host portal'

if ! command -v qs >/dev/null 2>&1; then
	echo "-- INCONCLUSIVE: quickshell (qs) is not installed" >&2
	exit 1
fi

if [[ -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" ]]; then
	echo "-- INCONCLUSIVE: no compositor; the overlays cannot be opened" >&2
	exit 1
fi

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/qsrice-cycle.XXXXXX") || exit 1
shell_log="$work_dir/shell.log"
samples="$work_dir/samples.jsonl"

shell_pid=""
bench_pid=""

# TERM first, then KILL for anything still up, and never a bare wait: a shell
# that ignores TERM would otherwise leave the trap itself blocking, turning a
# cancelled run into a hang at the exact moment someone is trying to stop it.
cleanup() {
	local pid attempt alive
	for pid in "$bench_pid" "$shell_pid"; do
		[[ -n "$pid" ]] && kill "$pid" 2>/dev/null
	done
	# Every liveness test is guarded on a non-empty pid, and that guard is the
	# whole point rather than tidiness: `kill -0 "${pid:-0}"` on an empty pid
	# becomes `kill -0 0`, which signals this script's own process group and
	# always succeeds, so the loop would never break and the KILL below would
	# fire on every clean exit. Both pids are routinely empty here — the
	# successful path clears bench_pid before returning.
	for attempt in 1 2 3 4 5 6 7 8 9 10; do
		alive=false
		for pid in "$bench_pid" "$shell_pid"; do
			[[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && alive=true
		done
		[[ "$alive" == true ]] || break
		sleep 0.2
	done
	for pid in "$bench_pid" "$shell_pid"; do
		[[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
	done
	wait 2>/dev/null
	[[ "$work_dir" == "${TMPDIR:-/tmp}"/qsrice-cycle.* ]] && rm -rf "$work_dir"
}
# A bash signal handler that returns hands control back to where the script was
# interrupted, so a single trap on EXIT INT TERM does not stop anything: the body
# runs on with its work directory already deleted, and cleanup runs a second time
# from EXIT on the way out. Interrupting has to end the script, which means
# saying so — clearing the EXIT trap first so the removal is not attempted twice,
# and exiting on the conventional 128 plus the signal number.
on_signal() {
	local signal="$1"
	cleanup
	trap - EXIT
	exit $((128 + signal))
}

trap cleanup EXIT
trap 'on_signal 2' INT
trap 'on_signal 15' TERM

qs -p shell.qml >"$shell_log" 2>&1 &
shell_pid=$!

# Waiting for the IPC socket to answer rather than for a log line: the log says
# the configuration loaded, which happens before the handlers are callable, and
# a call into a shell that is not listening yet fails for the wrong reason.
ready=false
deadline=$((SECONDS + READY_TIMEOUT))
while [[ "$SECONDS" -lt "$deadline" ]]; do
	if ! kill -0 "$shell_pid" 2>/dev/null; then
		echo "-- FAILED: the shell exited during startup" >&2
		sed 's/^/   /' "$shell_log" >&2
		shell_pid=""
		exit 1
	fi
	if timeout "$IPC_TIMEOUT" qs ipc --pid "$shell_pid" show >/dev/null 2>&1; then
		ready=true
		break
	fi
	sleep 0.25
done

if [[ "$ready" != true ]]; then
	echo "-- FAILED: the shell did not answer IPC within ${READY_TIMEOUT}s" >&2
	sed 's/^/   /' "$shell_log" >&2
	exit 1
fi

# Every target shell.qml declares has to be there. A handler renamed or dropped
# is a panel the user can no longer open, and nothing else in the suite reads
# this list.
missing=()
ipc_targets=$(timeout "$IPC_TIMEOUT" qs ipc --pid "$shell_pid" show 2>/dev/null)
for target in "${TARGETS[@]}"; do
	grep -qE "(^|[^a-z])${target}([^a-z]|$)" <<<"$ipc_targets" || missing+=("$target")
done
if [[ "${#missing[@]}" -gt 0 ]]; then
	echo "-- FAILED: shell.qml exposes no IPC target for: ${missing[*]}" >&2
	exit 1
fi

# The opening verb is a parameter because each handler in shell.qml declares
# two, open() and toggle(), and a pass that only ever toggles leaves open()
# uncalled — a function no test reaches is a panel that can stop opening from
# its keybind without anything noticing. Closing is always toggle: it is the
# only verb that closes, and its closing half took a different branch from
# close() for long enough to be worth exercising every cycle.
cycle_once() {
	local label="$1" open_verb="$2" target
	for target in "${TARGETS[@]}"; do
		if ! timeout "$IPC_TIMEOUT" qs ipc --pid "$shell_pid" call "$target" "$open_verb" >/dev/null 2>&1; then
			echo "-- FAILED: $open_verb on $target over IPC failed on $label" >&2
			exit 1
		fi
		sleep "$SETTLE"
		if ! timeout "$IPC_TIMEOUT" qs ipc --pid "$shell_pid" call "$target" toggle >/dev/null 2>&1; then
			echo "-- FAILED: closing $target over IPC failed on $label" >&2
			exit 1
		fi
		sleep "$SETTLE"
	done
}

# One full pass before anything is measured, and it is the difference between a
# measurement and a number.
#
# The first time an overlay opens, its QML is compiled, its fonts and icons are
# resolved and Qt's thread pools spin up. Measured on the first version of this
# script, two cycles from cold read as descriptors 70 -> 83, threads 8 -> 19 and
# RSS +53 MB, none of which is a leak: it is the cost of existing, paid once.
#
# A leak grows on every cycle. Lazy initialisation grows on the first. Warming
# up puts both ends of the comparison on the warm side of that line, so what is
# left to see is only the part that repeats.
# Opens with open() so that verb is covered too. The warm-up pass is thrown
# away as a measurement, which makes it the right place to spend a check
# that has nothing to do with resources.
cycle_once "the warm-up cycle" open

# Two toggles per target per measured cycle, plus the warmup and a tail, with
# enough margin that the bench outlives the cycles rather than the other way
# round.
toggles=$((CYCLES * ${#TARGETS[@]} * 2))
duration=$(python3 -c "print(max(8, int($toggles * $SETTLE + $WARMUP + 4)))")

python3 scripts/qsrice-bench.py \
	--pid "$shell_pid" \
	--scenario panel-cycles \
	--duration "$duration" \
	--warmup "$WARMUP" \
	--interval "$INTERVAL" \
	--memory-every 1 \
	--jsonl "$samples" \
	--quiet >/dev/null 2>"$work_dir/bench.err" &
bench_pid=$!

sleep "$WARMUP"

for ((cycle = 1; cycle <= CYCLES; cycle++)); do
	cycle_once "cycle $cycle" toggle
done

if ! kill -0 "$shell_pid" 2>/dev/null; then
	echo "-- FAILED: the shell died while its overlays were being cycled" >&2
	sed 's/^/   /' "$shell_log" >&2
	shell_pid=""
	exit 1
fi

wait "$bench_pid" 2>/dev/null
bench_status=$?
bench_pid=""

# Both halves of "did the measurement happen". A benchmark that writes a few
# samples and then dies leaves a non-empty file, so checking the file alone
# reports a clean pass on a run whose numbers stop partway through — which is
# the one outcome this stage must never produce, because its whole job is to
# say something about a trend.
if [[ "$bench_status" -ne 0 ]]; then
	echo "-- FAILED: the benchmark exited $bench_status; its samples cannot be trusted" >&2
	sed 's/^/   /' "$work_dir/bench.err" >&2
	exit 1
fi

if [[ ! -s "$samples" ]]; then
	echo "-- FAILED: the benchmark produced no samples" >&2
	sed 's/^/   /' "$work_dir/bench.err" >&2
	exit 1
fi

problems=$(sed -E 's/\x1b\[[0-9;]*m//g' "$shell_log" | grep -E '(WARN|ERROR)' | grep -Fv "$PLATFORM_NOISE")
if [[ -n "$problems" ]]; then
	echo "-- FAILED: the shell reported warnings or errors while cycling:" >&2
	printf '%s\n' "$problems" | sed 's/^/   /' >&2
	exit 1
fi

python3 - "$samples" "$CYCLES" <<'PY'
import json
import statistics
import sys

samples_path, cycles = sys.argv[1], sys.argv[2]
samples = []
with open(samples_path) as handle:
    for line in handle:
        line = line.strip()
        if line:
            samples.append(json.loads(line))

if len(samples) < 6:
    print(f"-- FAILED: {len(samples)} samples is too few to read a trend", file=sys.stderr)
    raise SystemExit(1)


def series(field):
    return [s[field] for s in samples if isinstance(s.get(field), (int, float))]


def thirds(values):
    size = len(values) // 3
    return values[:size], values[-size:]


def report(label, field, unit):
    values = series(field)
    if not values:
        return None, None
    first, last = thirds(values)
    early, late = statistics.median(first), statistics.median(last)
    print(f"   {label:<22} {early:>10.1f} -> {late:>10.1f} {unit} "
          f"(min {min(values):.1f}, max {max(values):.1f})")
    return early, late


print(f"   samples: {len(samples)} over {cycles} open/close cycles of every overlay")
fd_early, fd_late = report("descriptors (shell)", "main_fds", "")
report("descriptors (tree)", "tree_fds", "")
report("RSS (shell)", "main_rss_kib", "KiB")
report("RSS (tree)", "tree_rss_kib", "KiB")
report("threads (shell)", "main_threads", "")

if fd_early is None:
    print("-- FAILED: the benchmark could not read file descriptor counts", file=sys.stderr)
    raise SystemExit(1)

# The median of the last third against the median of the first third, with a
# tolerance that was measured rather than picked.
#
# A shell that opens nothing at all drifts too: an idle run over the same window
# moved 68 -> 69 descriptors, so roughly one is background and belongs to
# neither the overlays nor a bug. Warmed-up runs measured +2.0, +1.0, +1.5 and
# -0.5 over three cycles, and +2.0, -1.0 and -1.5 over five.
#
# That second row is the one that matters, and it is why this number stays put.
# The floor is two at three cycles and still two at five: drift does not
# accumulate with the cycling, it just wobbles. A leak does accumulate — one
# descriptor per cycle is a delta of five at five cycles. So the way to buy
# margin is to raise the cycles and leave this alone. Raising this instead would
# close the only gap the check has: at a tolerance of three, a one-per-cycle
# leak at three cycles becomes invisible.
FD_TOLERANCE = 2

growth = fd_late - fd_early
if growth > FD_TOLERANCE:
    print(f"-- FAILED: file descriptors grew across the cycles: "
          f"{fd_early:.0f} -> {fd_late:.0f} ({growth:+.1f}, tolerance "
          f"{FD_TOLERANCE}). An overlay is not releasing something it opens.",
          file=sys.stderr)
    raise SystemExit(1)

print(f"   descriptor growth: {growth:+.1f} of {FD_TOLERANCE} tolerated")
PY
