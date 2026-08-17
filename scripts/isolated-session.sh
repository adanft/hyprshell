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
#
# Exactly the directories the shell reads or writes, and no name it used to go
# by. Everything absent from this list is symlinked to yours, so a name that
# belongs here and is missing hands a test run your real directory instead of an
# empty one.
readonly OWNED_CONFIG=(hypr hyprshell ghostty)

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

if ! session_dir=$(mktemp -d "$HOST_RUNTIME_DIR/hyprshell-isolated.XXXXXX"); then
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
	[[ "$SESSION_DIR" == "$HOST_RUNTIME_DIR"/hyprshell-isolated.* ]] && rm -rf "$SESSION_DIR"
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
# workspace you are on and can be scrolled off screen. This installs the rule
# that stops that, so nothing has to be present in your own config for the suite
# to work. Clone the repository and run it.
#
# This reverses what stood here before, which argued the script must not do it:
# reaching into a live compositor is the coupling this script exists to remove,
# and the rule belonged in your own config where you could see it. Two things
# changed the answer. The first is that the attempt it was written after had
# used `hyprctl keyword`, which refuses the rule and exits 0 — so the position
# was partly a conclusion drawn from a tool that lies, and `hyprctl eval` does
# not lie. The second is plainer: a suite that only works if something is
# present in one developer's personal config does not work for anyone who
# clones the repository, and that outranks the tidiness of the boundary. The
# coupling is real and is the price; it is one rule, on one class, that no
# session but a test run produces.
#
# Floating rather than hidden, and pinned: a tiling layout leaves a floating
# window alone, so nothing gets retiled, and a pinned window stays mapped so the
# nested compositor keeps receiving the frame callbacks its own timers run on. A
# hidden or scrolled-away window is unmapped, and then every stage that waits on
# a frame times out instead — a failure that reads exactly like a regression in
# whatever happened to be running.
#
# Applied before the compositor starts, so it is in force the first time the
# window maps. Dispatching afterwards also works, but only once the window has
# already appeared and retiled, which is the part worth avoiding.
#
# Two ways in, because Hyprland has two config parsers and they disagree about
# which one works:
#
#   `hyprctl keyword` is the obvious one and it is the trap. Against a Lua
#   config it refuses -- "keyword can't work with non-legacy parsers" -- and
#   still exits 0, so a script that trusts the status reports success while
#   having done nothing at all. Measured on Hyprland 0.56.2. Its output is read
#   instead of its status for exactly that reason.
#
#   `hyprctl eval` runs Lua and reports honestly: a call into a nil field exits
#   7. That is the one to try first, and the only one whose exit code means
#   anything.
#
# The rule lives until the compositor next reloads its config. It matches only
# the class a nested compositor gets, so nothing else in your session is
# affected, and the pin check further down is what proves it actually took —
# this function reporting success is not the same as the window being pinned.
# Whether an answer from `hyprctl keyword` is a refusal. Its status never is, so
# this reads what it said. Matched case-insensitively rather than by cutting the
# first letter off "invalid", which is the trick this used to play: it worked,
# and it read as a typo, and the obvious correction to it would have silently
# stopped catching the capitalised spelling.
keyword_refused() {
	local said
	said=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
	[[ "$said" == *"non-legacy parsers"* || "$said" == *"invalid"* ]]
}

install_window_rule() {
	local lua='hl.window_rule({ name = "hyprshell-isolated-session", match = { class = "aquamarine" }, float = true, no_focus = true, pin = true })'

	if hyprctl eval "$lua" >/dev/null 2>&1; then
		return 0
	fi

	# Legacy parser, one property per call, and each one answered for.
	#
	# `pin` is checked as carefully as `float` because it is the one that matters
	# most: a floating window that is not pinned still leaves the workspace alone,
	# but it stops being drawn the moment you switch away, which is the failure
	# this whole thing exists to prevent. An earlier version fired it and the next
	# call blind and returned success regardless, so a compositor that took float
	# and refused pin reported as installed. Three separate readers caught that
	# independently, which is about how obvious it is from the outside and how
	# invisible from within.
	local said property
	for property in float pin; do
		said=$(hyprctl keyword windowrulev2 "$property, class:^(aquamarine)$" 2>&1)
		if keyword_refused "$said"; then
			return 1
		fi
	done

	# nofocus is the one genuine convenience here: without it the nested window
	# takes focus when it maps, which is irritating and nothing more. Not worth
	# failing the run over, and said so rather than left to look like an oversight.
	hyprctl keyword windowrulev2 "nofocus, class:^(aquamarine)$" >/dev/null 2>&1
	return 0
}

# No `command -v hyprctl` here: the preflight near the top of this file already
# exits when it is missing, so a second check would guard a state that cannot be
# reached and invite someone to reason about it.
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
	if ! install_window_rule; then
		echo "-- WARNING: this script could not install the window rule that keeps the" >&2
		echo "   nested compositor floating and pinned, so your compositor accepted" >&2
		echo "   neither its Lua nor its legacy form. The run continues; if the window" >&2
		echo "   retiles your workspace or scrolls out of sight, that is why, and the" >&2
		echo "   pin check below will say so in its own words." >&2
	fi
fi

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
# The rule that arranges it is installed above, so this is no longer a check on
# something outside the repository — it is the check that the thing this script
# just did actually happened. Those are not the same, and only this one looks at
# the window. Without it a run does not fail cleanly: it fails as a timeout that
# looks exactly like a regression in whatever stage happened to be running,
# which is how it cost an afternoon before it was understood.
#
# A warning rather than a refusal: the host may be another compositor entirely,
# and someone who knows the trade may want to run anyway.
# Every outcome is named, including the ones where the check itself did not
# work, because this warning has now been written wrong twice in the same way.
#
# First it used jq's `// empty`, whose alternative operator fires on false as
# well as on null, so a genuinely unpinned window read the same as no window and
# the warning could never print. Then, with that fixed, a hyprctl that failed or
# timed out still left the value empty and still said nothing — a silence that
# is indistinguishable from a window that is fine.
#
# So the query and its interpretation are separated: whether the compositor
# answered at all is one question, and what it answered is another. A check that
# cannot fail is worse than no check, because it looks like one.
pin_warning() {
	echo "-- WARNING: $1" >&2
	echo "   Your compositor stops sending frame callbacks to a window that is not on" >&2
	echo "   screen, and everything inside this session runs on those frames. Switch" >&2
	echo "   workspace during a run and its timers stop; the stage that was waiting" >&2
	echo "   then reports a timeout that reads like a regression. This script installs" >&2
	echo "   the rule that prevents it, so seeing this means the rule did not take —" >&2
	echo "   see \"Why --isolated exists\" in docs/development.md." >&2
}

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v jq >/dev/null 2>&1; then
	# The third way this one check managed to report nothing, and the first that
	# was this file's own fault: it wrote hyprctl's errors to a path built from a
	# variable that was never assigned. Under `set -u` that fails inside the
	# command substitution, which leaves the status non-zero and sends the code
	# straight down the branch below — so a typo here wore the costume of a
	# compositor that had simply not answered, and said so on every single run.
	#
	# Opened and checked before the query for that reason. A path this script
	# cannot write is a bug in this script, and it now says so in those words
	# rather than borrowing the compositor's.
	hyprctl_error="$session_dir/hyprctl.err"
	# `2>/dev/null` before the target, not after: redirections are applied left
	# to right, so with the target first bash has already printed its own
	# complaint by the time the silencer is in place, and the run says the same
	# thing twice in two voices.
	if ! : 2>/dev/null >"$hyprctl_error"; then
		pin_warning "this session script could not open ${hyprctl_error} to capture hyprctl's errors, so the pin was never checked. The fault is here, not in your compositor."
	else
		# The status is read on its own line and not from inside an `if !`,
		# where `$?` is the negation's own result and always zero. Written that
		# way the warning reported "hyprctl exited 0" — a number that is both
		# wrong and impossible, in the message whose whole job is to say what
		# went wrong.
		host_clients=$(timeout 5 hyprctl clients -j 2>"$hyprctl_error")
		host_clients_status=$?

		# Written down and then never read was the old shape of this file: the
		# errors were captured and nothing ever opened them, so whatever hyprctl
		# had to say died in a temporary directory.
		# No `|| hyprctl_said=""` after this. `read` returns non-zero at end of
		# file even when it has already filled the variable with a whole line
		# that simply lacks a trailing newline, so the guard would wipe exactly
		# what it had just captured — and a one-line diagnostic written without
		# a newline is the ordinary shape. It was verified with a stub built on
		# `echo`, which appends the newline and so could never reach the case.
		hyprctl_said=""
		read -r hyprctl_said <"$hyprctl_error" 2>/dev/null

		if [[ "$host_clients_status" -ne 0 ]]; then
			pin_warning "your compositor did not answer when asked about this session's window (hyprctl exited ${host_clients_status}${hyprctl_said:+; it said: ${hyprctl_said}}), so whether it is pinned is unknown."
		elif [[ -z "$host_clients" ]]; then
			pin_warning "your compositor answered with nothing when asked about this session's window, so whether it is pinned is unknown."
		else
			pinned=$(jq -r --arg pid "$hypr_pid" '[.[] | select(.pid == ($pid | tonumber)) | .pinned]
				| if length == 0 then "absent" else (.[0] | tostring) end' <<<"$host_clients")
			case "$pinned" in
			true) ;;
			false)
				pin_warning "this session's window is not pinned."
				;;
			*)
				pin_warning "this session's window was not among your compositor's clients, so whether it is pinned is unknown."
				;;
			esac
		fi
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
