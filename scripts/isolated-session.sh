#!/usr/bin/env bash
#
# Runs a command inside a throwaway desktop session and exits with its status.
#
#     scripts/isolated-session.sh ./run-tests.sh --compositor-stages
#
# The session is a nested Hyprland with a private D-Bus bus and private config,
# cache and runtime directories, so nothing the command does reaches the session
# you are working in. Two things in this shell make that necessary, and both are
# correct where they live:
#
#   features/statusbar/BarWindow.qml  reserves a layer-shell exclusive zone, so
#     the compositor relayouts every window on the display the bar lands on.
#   theme/runtime/HyprTheme.qml       runs `hyprctl reload`, so Hyprland
#     re-applies its monitors, binds and window rules.
#
# What is isolated is what the shell writes and what would disturb you: its
# config directory, its cache, its runtime sockets, its bus, its compositor.
# What it only reads -- icon themes, desktop entries, PipeWire -- stays yours,
# because a session that cannot see them stops resembling the one the shell
# actually runs in, and the test starts reporting the sandbox instead of the code.
#
# Exit codes: the command's own, or 1 if the session could not be built, or 2
# for a usage error.

set -uo pipefail

if [[ $# -eq 0 ]]; then
	echo "usage: $0 COMMAND [ARG...]" >&2
	exit 2
fi

readonly STARTUP_TIMEOUT=20
readonly CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/isolated-hyprland.conf"

# Two separate limits sit on this path, and the tighter one is not the kernel's.
#
# A unix socket path is 108 bytes including the terminator, and the kernel
# truncates past that rather than failing: overrun it and hyprctl still works,
# because it truncates identically, while every other client gets
# ServerNotFoundError against a socket whose name is quietly a few characters
# short. Qt's QLocalSocket then stops one byte earlier still -- measured here,
# not read out of Qt: at 106 bytes .socket.sock connects and at 107
# .socket2.sock does not, which leaves the shell able to query the compositor
# and unable to receive a single event from it.
#
# Hyprland puts both under $XDG_RUNTIME_DIR/hypr/<signature>/, the signature runs
# about 62 characters, and "/hypr/" plus "/.socket2.sock" is another 20, so the
# runtime directory has roughly 24 to spend. The name below spends 23, and the
# check after startup measures the real path rather than trusting this estimate,
# because the signature's last component is a number of no fixed width.
readonly QT_SOCKET_PATH_LIMIT=106
readonly RUNTIME_PATH_BUDGET=24

# The directories the shell writes to, from the README's "Where it keeps things".
# Everything else under your config directory is linked back to the real one.
readonly OWNED_CONFIG=(hypr qsrice qscomponents ghostty)

for tool in Hyprland dbus-daemon hyprctl; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "-- INCONCLUSIVE: $tool is not installed; no isolated session can be built" >&2
		exit 1
	fi
done

if [[ ! -r "$CONFIG_FILE" ]]; then
	echo "-- INCONCLUSIVE: missing $CONFIG_FILE" >&2
	exit 1
fi

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
	echo "-- INCONCLUSIVE: XDG_RUNTIME_DIR is unset; there is nowhere to put the session" >&2
	exit 1
fi

readonly HOST_RUNTIME_DIR="$XDG_RUNTIME_DIR"
readonly HOST_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# Hyprland nests by connecting to the compositor already running, which means it
# needs the parent socket. Resolving it to an absolute path now is what lets it
# keep reaching that socket after XDG_RUNTIME_DIR has been pointed elsewhere:
# libwayland prepends the runtime directory only to a relative name.
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
	echo "-- INCONCLUSIVE: no WAYLAND_DISPLAY; there is no compositor to nest inside" >&2
	exit 1
fi

parent_socket="$WAYLAND_DISPLAY"
[[ "$parent_socket" != /* ]] && parent_socket="$HOST_RUNTIME_DIR/$parent_socket"

if [[ ! -S "$parent_socket" ]]; then
	echo "-- INCONCLUSIVE: no Wayland socket at $parent_socket" >&2
	exit 1
fi

# Two directories rather than one, and the short name is not cosmetic: the
# runtime directory is the one with the socket budget above to stay inside.
if ! run_dir=$(mktemp -d "$HOST_RUNTIME_DIR/q.XXXXXX"); then
	echo "-- INCONCLUSIVE: could not create the runtime directory" >&2
	exit 1
fi

if ! session_dir=$(mktemp -d "$HOST_RUNTIME_DIR/qsrice-isolated.XXXXXX"); then
	rmdir "$run_dir" 2>/dev/null
	echo "-- INCONCLUSIVE: could not create the session directory" >&2
	exit 1
fi

readonly RUN_DIR="$run_dir"
readonly SESSION_DIR="$session_dir"
readonly CONFIG_DIR="$SESSION_DIR/config"

hypr_pid=""
dbus_pid=""

cleanup() {
	if [[ -n "$hypr_pid" ]]; then
		kill "$hypr_pid" 2>/dev/null
		wait "$hypr_pid" 2>/dev/null
	fi
	if [[ -n "$dbus_pid" ]]; then
		kill "$dbus_pid" 2>/dev/null
	fi
	# Both guarded against the empty string and matched against the name they
	# were created under: an unguarded rm -rf here would take the runtime
	# directory of the session this script exists to protect.
	[[ "$RUN_DIR" == "$HOST_RUNTIME_DIR"/q.* ]] && rm -rf "$RUN_DIR"
	[[ "$SESSION_DIR" == "$HOST_RUNTIME_DIR"/qsrice-isolated.* ]] && rm -rf "$SESSION_DIR"
}
trap cleanup EXIT INT TERM

if [[ "${#RUN_DIR}" -gt "$RUNTIME_PATH_BUDGET" ]]; then
	echo "-- INCONCLUSIVE: the runtime directory needs to be at most" >&2
	echo "   ${RUNTIME_PATH_BUDGET} characters for Hyprland's IPC socket to fit in 108 bytes," >&2
	echo "   and $RUN_DIR is ${#RUN_DIR}. Truncation here is silent, so this stops" >&2
	echo "   rather than handing the shell a compositor it cannot talk to." >&2
	exit 1
fi

# A runtime directory the group or the world can reach makes libwayland refuse.
chmod 700 "$RUN_DIR"
mkdir -p "$CONFIG_DIR" "$SESSION_DIR/cache" "$SESSION_DIR/state" || exit 1

# Everything the shell does not own is linked back to your real configuration,
# so the icon theme, the GTK settings and the rest resolve exactly as they do in
# your session. The four it does own start empty, which is also what makes this
# run cover the first-launch paths your own config has long since moved past.
if [[ -d "$HOST_CONFIG_DIR" ]]; then
	for entry in "$HOST_CONFIG_DIR"/*; do
		[[ -e "$entry" ]] || continue
		name=$(basename "$entry")
		owned=false
		for reserved in "${OWNED_CONFIG[@]}"; do
			[[ "$name" == "$reserved" ]] && owned=true
		done
		[[ "$owned" == true ]] && continue
		ln -s "$entry" "$CONFIG_DIR/$name" 2>/dev/null
	done
fi

# PipeWire is a session service the shell reads from and never reconfigures, so
# the throwaway session borrows the real one instead of starting a second daemon
# it would then have to tear down.
for socket in "$HOST_RUNTIME_DIR"/pipewire-* "$HOST_RUNTIME_DIR"/pulse; do
	[[ -e "$socket" ]] || continue
	ln -s "$socket" "$RUN_DIR/$(basename "$socket")" 2>/dev/null
done

# Hyprland turns its own stdout logging off and writes to a file under the
# runtime directory instead, so the redirected stream alone would leave a
# startup failure with nothing to read.
dump_session_log() {
	if [[ -s "$SESSION_DIR/hyprland.log" ]]; then
		sed 's/^/   /' "$SESSION_DIR/hyprland.log" >&2
	fi
	for log in "$RUN_DIR"/hypr/*/hyprland.log; do
		[[ -s "$log" ]] || continue
		tail -n 40 "$log" | sed 's/^/   /' >&2
	done
}

# The nested compositor appears in your session as one ordinary window, with
# class `aquamarine`, and on a tiling compositor an ordinary window retiles the
# workspace you are on. This script deliberately does not deal with that itself.
#
# It tried to, once, with `hyprctl keyword windowrule ...`. That fails outright
# against a Lua config -- "keyword can't work with non-legacy parsers" -- and
# still exits 0, so it reported success while doing nothing. Dispatching the
# window away afterwards works, but only after it has already mapped and
# retiled, which is the part worth avoiding.
#
# The rule belongs in your own Hyprland config, where it applies before the
# window ever maps and where you can see it. See the README, "Why --isolated
# exists". Reaching into a live compositor from a test harness is the coupling
# this script exists to remove; it should not reintroduce it one directory up.

if ! dbus-daemon --session --fork --print-address=3 --print-pid=4 \
	3>"$SESSION_DIR/bus.address" 4>"$SESSION_DIR/bus.pid"; then
	echo "-- INCONCLUSIVE: the private D-Bus session bus did not start" >&2
	exit 1
fi

bus_address=$(<"$SESSION_DIR/bus.address")
dbus_pid=$(<"$SESSION_DIR/bus.pid")

if [[ -z "$bus_address" ]]; then
	echo "-- INCONCLUSIVE: dbus-daemon reported no address" >&2
	exit 1
fi

# HYPRLAND_NO_SD_VARS is the one that must not be dropped. Without it the nested
# Hyprland pushes its own WAYLAND_DISPLAY and instance signature into your
# systemd user environment, and every application you launch afterwards connects
# to a compositor that stopped existing when this script returned.
XDG_RUNTIME_DIR="$RUN_DIR" \
	XDG_CONFIG_HOME="$CONFIG_DIR" \
	XDG_CACHE_HOME="$SESSION_DIR/cache" \
	XDG_STATE_HOME="$SESSION_DIR/state" \
	DBUS_SESSION_BUS_ADDRESS="$bus_address" \
	WAYLAND_DISPLAY="$parent_socket" \
	HYPRLAND_NO_SD_NOTIFY=1 \
	HYPRLAND_NO_SD_VARS=1 \
	HYPRLAND_NO_CRASHREPORTER=1 \
	Hyprland -c "$CONFIG_FILE" >"$SESSION_DIR/hyprland.log" 2>&1 &
hypr_pid=$!

nested_display=""
signature=""
deadline=$((SECONDS + STARTUP_TIMEOUT))

while [[ "$SECONDS" -lt "$deadline" ]]; do
	if ! kill -0 "$hypr_pid" 2>/dev/null; then
		echo "-- FAILED: the nested Hyprland exited before it was ready" >&2
		dump_session_log
		hypr_pid=""
		exit 1
	fi

	nested_display=""
	signature=""

	for candidate in "$RUN_DIR"/wayland-*; do
		[[ -S "$candidate" ]] || continue
		nested_display=$(basename "$candidate")
		break
	done

	for candidate in "$RUN_DIR"/hypr/*/; do
		[[ -d "$candidate" ]] || continue
		signature=$(basename "$candidate")
		break
	done

	# Both sockets, and a real reply on the first. Hyprland serves requests on
	# .socket.sock before it opens the .socket2.sock event stream, so a check
	# that stops at "hyprctl answers" hands the shell a compositor it can query
	# and cannot subscribe to -- which surfaces much later, as an intermittent
	# "Unable to connect to hyprland event socket" from the smoke test rather
	# than as a startup failure here.
	if [[ -n "$nested_display" && -n "$signature" ]] &&
		[[ -S "$RUN_DIR/hypr/$signature/.socket.sock" ]] &&
		[[ -S "$RUN_DIR/hypr/$signature/.socket2.sock" ]] &&
		XDG_RUNTIME_DIR="$RUN_DIR" HYPRLAND_INSTANCE_SIGNATURE="$signature" \
			hyprctl monitors >/dev/null 2>&1; then
		break
	fi

	nested_display=""
	sleep 0.2
done

if [[ -z "$nested_display" || -z "$signature" ]]; then
	echo "-- FAILED: the nested Hyprland was not ready within ${STARTUP_TIMEOUT}s" >&2
	dump_session_log
	exit 1
fi

# The budget check above should make this unreachable. It stays because the
# failure it catches is invisible: a truncated socket path leaves a compositor
# that answers hyprctl and refuses everything else, which reads as a bug in the
# shell rather than a bug in this script.
for socket in .socket.sock .socket2.sock; do
	socket_path="$RUN_DIR/hypr/$signature/$socket"

	if [[ ! -S "$socket_path" ]]; then
		echo "-- FAILED: no IPC socket at \$XDG_RUNTIME_DIR/hypr/<signature>/$socket;" >&2
		echo "   the path was almost certainly truncated at 108 bytes." >&2
		exit 1
	fi

	# Existing is not the same as reachable. This is the check that would have
	# caught the event socket directly, instead of letting it surface a screen
	# away as a warning from the smoke test.
	if [[ "${#socket_path}" -gt "$QT_SOCKET_PATH_LIMIT" ]]; then
		echo "-- FAILED: $socket is ${#socket_path} bytes, past the ${QT_SOCKET_PATH_LIMIT} a Qt client can open." >&2
		echo "   The socket exists and the shell will not be able to connect to it." >&2
		exit 1
	fi
done

# Whether the window this compositor draws into will keep being drawn.
#
# Everything below depends on it and none of it is in this repository: the fix
# is a window rule in the developer's own Hyprland config. Without it a run does
# not fail cleanly, it fails as a timeout that looks exactly like a regression in
# whatever stage happened to be running — which is how this cost an afternoon
# before it was understood. So it is checked, and said plainly.
#
# A warning rather than a refusal: the rule is Hyprland's, the host may be
# another compositor, and someone who knows the trade may want to run anyway.
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v jq >/dev/null 2>&1; then
	# Not `// empty`, which is the obvious way to write this and is wrong: jq's
	# alternative operator fires on false as well as on null, so a window that
	# is genuinely unpinned reads the same as no window at all and the warning
	# never prints. A check that cannot fail is worse than no check, because it
	# looks like one.
	pinned=$(timeout 5 hyprctl clients -j 2>/dev/null |
		jq -r --arg pid "$hypr_pid" '[.[] | select(.pid == ($pid | tonumber)) | .pinned]
			| if length == 0 then "" else (.[0] | tostring) end')
	if [[ "$pinned" == "false" ]]; then
		echo "-- WARNING: this session's window is not pinned." >&2
		echo "   Your compositor stops sending frame callbacks to a window that is not on" >&2
		echo "   screen, and everything inside this session runs on those frames. Switch" >&2
		echo "   workspace during a run and its timers stop; the stage that was waiting" >&2
		echo "   then reports a timeout that reads like a regression. See the README," >&2
		echo "   \"Why --isolated exists\", for the three-line rule that fixes it." >&2
	fi
fi

# Not a headless output, and it is worth writing down why, because it is the
# obvious idea and it does not work here.
#
# The window this compositor draws into is an ordinary client of your session,
# so your session stops sending it frame callbacks whenever it is not shown.
# Everything inside then freezes, which surfaces much later as a test waiting on
# something that has to render. An output not backed by that window would fix
# it. `hyprctl output create headless` does add one on Hyprland 0.56.2, and it
# comes up 0x0: it reports 1920x1080@60 as its one available mode and takes
# neither that mode nor `preferred` from a monitor rule. A zero-sized screen is
# worse than none, because the shell builds a bar on it.
#
# DISPLAY is unset rather than overridden: left in place it is your session's X
# server, and a Qt client that falls back to xcb would draw into the very
# session this script is keeping the test away from.
env -u DISPLAY \
	XDG_RUNTIME_DIR="$RUN_DIR" \
	XDG_CONFIG_HOME="$CONFIG_DIR" \
	XDG_CACHE_HOME="$SESSION_DIR/cache" \
	XDG_STATE_HOME="$SESSION_DIR/state" \
	DBUS_SESSION_BUS_ADDRESS="$bus_address" \
	WAYLAND_DISPLAY="$nested_display" \
	HYPRLAND_INSTANCE_SIGNATURE="$signature" \
	QT_QPA_PLATFORM=wayland \
	"$@"
status=$?

exit "$status"
