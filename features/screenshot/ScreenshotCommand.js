function processArguments(mode, includeCursor, monitorName, delaySeconds) {
	const script = String.raw`
set -eu
mode=$1
cursor=$2
monitor=$3
delay=$4
dir=$HOME/Pictures/Screenshots
mkdir -p -- "$dir"
# The tool hides itself before this runs, but the compositor drops the layer
# surface asynchronously, so waiting a fixed moment is a bet: under load the
# overlay is still on screen when grim fires and lands in the shot. Wait for the
# surface to actually be gone instead. Bounded, because a layer that never
# disappears must not hang the capture, and the loop exits on the first check in
# the ordinary case.
waited=0
while [ "$waited" -lt 50 ]; do
  hyprctl layers -j | jq -e 'any(.[].levels[][]; .namespace == "qs-screenshot")' >/dev/null 2>&1 || break
  sleep 0.02
  waited=$((waited + 1))
done
sleep "$delay"
file=$(mktemp -- "$dir/screenshot_$(date +%Y-%m-%d-%H-%M-%S-%3N)-XXXXXX.png")
cleanup() { rm -f -- "$file"; }
trap cleanup EXIT HUP INT TERM
set --
if [ "$cursor" = 1 ]; then set -- -c; fi
case "$mode" in
  monitor) grim "$@" -o "$monitor" "$file" ;;
  window)
    id=$(hyprctl activewindow -j | jq -r 'select(.stableId != null) | .stableId')
    [ -n "$id" ] || exit 0
    sleep 0.5
    grim "$@" -T "$id" "$file"
    ;;
  area)
    geometry=$(slurp)
    [ -n "$geometry" ] || exit 0
    grim "$@" -g "$geometry" "$file"
    ;;
  *) grim "$@" "$file" ;;
esac
wl-copy --type image/png < "$file"
notify-send -u low -i image-png "Screenshot captured" "$(basename "$file")
Copied to clipboard"
trap - EXIT HUP INT TERM
`;
	return [
		"sh",
		"-c",
		script,
		"qsrice-screenshot",
		String(mode || "all"),
		includeCursor ? "1" : "0",
		String(monitorName || ""),
		// The 0.2 that used to be added here was padding for the overlay
		// teardown; the script now waits for that surface directly, so this is
		// only the timer the user asked for.
		String(Math.max(0, Number(delaySeconds) || 0)),
	];
}

if (typeof module !== "undefined") module.exports = { processArguments };
