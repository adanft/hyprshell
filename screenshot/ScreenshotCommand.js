function processArguments(mode, includeCursor, monitorName, delaySeconds) {
	const script = String.raw`
set -eu
mode=$1
cursor=$2
monitor=$3
delay=$4
dir=$HOME/Pictures/Screenshots
mkdir -p -- "$dir"
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
		String(Math.max(0, Number(delaySeconds) || 0) + 0.2),
	];
}

if (typeof module !== "undefined") module.exports = { processArguments };
