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
# x-kde-urls names the file for the shell, which is the notification daemon as
# well as the thing that asked for this capture but has no other way to learn
# what the name turned out to be. The hint is KDE's rather than ours on purpose:
# Plasma, winbar and ukui-notification-daemon all already read it, so this
# script keeps working as a screenshot tool under any of them.
#
# Sent, not clicked: a notify-send -A button would belong to this script, so it
# would have to sit here waiting for the click and would die with the popup.
#
# A path is not a URI. Only two characters break the trip: a percent, which the
# reader would take for an escape, and a quote, which would close the variant
# literal below. Percent goes first or it would escape its own replacement.
url=$(printf 'file://%s' "$file" | sed -e 's/%/%25/g' -e "s/'/%27/g")
notify-send -u low -i image-png -h "variant:x-kde-urls:['$url']" \
  "Screenshot captured" "$(basename "$file")
Copied to clipboard"
trap - EXIT HUP INT TERM
`;
	return [
		"sh",
		"-c",
		script,
		"hyprshell-screenshot",
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
