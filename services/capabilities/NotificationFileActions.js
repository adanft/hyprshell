// Open and reveal buttons for a notification that names a file.
//
// The hint is `x-kde-urls`, which is not ours. KDE Plasma reads it in
// libnotificationmanager and turns it into a thumbnail, a drag source and an
// "Open Containing Folder" menu; the role's own comment in that code names this
// exact case, "a path to a screenshot that was just taken". Flameshot, ksnip,
// KShare and Spectacle all send it, and winbar and ukui-notification-daemon
// both read it without being KDE. Inventing a private key would have worked
// only for our own screenshots and for nobody else's.
//
// The buttons are built on this side rather than sent as `notify-send -A`
// actions, and that is the whole point. A spec action belongs to its sender:
// clicking it emits ActionInvoked back over D-Bus, so the sender has to stay
// alive to hear it — Spectacle literally holds a QEventLoopLocker open with the
// comment "ensure program stays alive until the notification finishes". Built
// here there is nothing to keep alive, and because a path is a plain string it
// survives into the history file, so the buttons still work in the notification
// center long after the popup is gone and long after the sender exited.

var HINT_KEY = "x-kde-urls";

var OPEN_IDENTIFIER = "qsrice-file-open";
var REVEAL_IDENTIFIER = "qsrice-file-reveal";
var OPEN_TEXT = "Open";
var REVEAL_TEXT = "Show in folder";

// The hint's D-Bus signature is `as`, and what arrives on this side is
// array-like but *not* an Array: `Array.isArray()` on it is false, measured.
// Testing for a real Array here is the kind of check that never fires and reads
// exactly like one that does.
function urlList(hints) {
	if (!hints || typeof hints !== "object") return [];
	var value = hints[HINT_KEY];
	if (typeof value === "string") return value.length > 0 ? [value] : [];
	if (!value || typeof value.length !== "number") return [];

	var urls = [];
	for (var index = 0; index < value.length; index++)
		if (typeof value[index] === "string") urls.push(value[index]);
	return urls;
}

// The path reaches a shell command below, so it is checked rather than trusted:
// any program on the bus can send this hint. Absolute and single-line, and free
// of the quote that would otherwise land inside the D-Bus literal in
// revealArguments and change its shape.
function isUsablePath(value) {
	var path = typeof value === "string" ? value : "";
	return path.startsWith("/") && !/[\r\n']/.test(path);
}

// Only `file://`, and only with an empty authority. The field carries URLs in
// general, and `file://host/path` names a file on another machine that xdg-open
// would either refuse or, worse, resolve to a different local one.
function decodeFileUrl(url) {
	var text = typeof url === "string" ? url : "";
	if (!text.startsWith("file:///")) return "";

	var encoded = text.slice("file://".length);
	var path;
	try {
		path = decodeURIComponent(encoded);
	} catch (error) {
		// A stray percent is a malformed URL, not a path with a percent in it.
		return "";
	}
	return isUsablePath(path) ? path : "";
}

// The first url only, which is what KDE does with the same hint: its own
// ThumbnailStrip comments that the protocol allows several but only one is ever
// used. Two buttons that silently act on one of five files would be worse than
// two that always act on the first.
function firstLocalPath(hints) {
	var urls = urlList(hints);
	for (var index = 0; index < urls.length; index++) {
		var path = decodeFileUrl(urls[index]);
		if (path) return path;
	}
	return "";
}

// The last slash, and the root when there is nothing before it.
function directoryOf(path) {
	var cut = String(path || "").lastIndexOf("/");
	if (cut < 0) return "";
	return cut === 0 ? "/" : path.slice(0, cut);
}

function baseNameOf(path) {
	var text = String(path || "");
	var cut = text.lastIndexOf("/");
	return cut < 0 ? text : text.slice(cut + 1);
}

// The button says which file it opens, and that is a correctness property
// rather than a nicety. Any program on the bus may send this hint along with a
// summary and body of its choosing, so a button labelled only "Open" would let
// a notification claim one thing and open another. Naming the file makes the
// affordance unable to misrepresent itself, and it is also what removes the
// reason the buttons used to displace the sender's own: "Open screenshot.png"
// does not collide with an "Open" the sender offered.
function openTextFor(path) {
	var name = baseNameOf(path);
	return name ? OPEN_TEXT + " " + name : OPEN_TEXT;
}

function openArguments(path) {
	return ["xdg-open", path];
}

// "Show in folder" means the file, highlighted, not a directory listing the
// person then has to search. FileManager1 is the only portable way to say that
// and nothing is required to implement it — this machine's own file manager
// does not — so a failure falls through to opening the containing directory
// rather than doing nothing at all. GNOME Shell's own "Show in Files" skips
// this and only ever opens the folder.
function revealArguments(path) {
	var directory = directoryOf(path);
	var script =
		'gdbus call --session --dest org.freedesktop.FileManager1' +
		' --object-path /org/freedesktop/FileManager1' +
		' --method org.freedesktop.FileManager1.ShowItems "[\'file://$1\']" ""' +
		" >/dev/null 2>&1 || exec xdg-open \"$2\"";
	return ["sh", "-c", script, "qsrice-file-reveal", path, directory];
}

// Shaped like the actions Quickshell hands over for a real sender — identifier,
// text, invoke — because that is all NotificationCard reads. It counts anything
// carrying invoke and skips the identifier "default", so neither of these is
// mistaken for the click-the-body action.
function actionsFor(path, run) {
	if (!isUsablePath(path) || typeof run !== "function") return [];
	return [
		{
			identifier: OPEN_IDENTIFIER,
			text: openTextFor(path),
			invoke: function () {
				run(openArguments(path));
			},
		},
		{
			identifier: REVEAL_IDENTIFIER,
			text: REVEAL_TEXT,
			invoke: function () {
				run(revealArguments(path));
			},
		},
	];
}

// Ours are added to the sender's, never in place of them. KDE does displace the
// action row here — its FooterLoader swaps the whole thing out for the file
// affordances — and this followed that at first, to keep an "Open" of ours from
// sitting beside the "Open" Spectacle sends with the same hint. Review called
// that the wrong trade and it was right: a notification arrives from one sender,
// so the row being replaced is always that same sender's, and dropping it loses
// what only it could offer, Spectacle's "Annotate" among them. The collision it
// was avoiding is gone anyway, because ours now names its file.
//
// The list is copied out rather than handed back for the same reason urlList
// duck-types: what arrives here is array-like and not an Array, and the caller
// reads it again when the entry is written to history.
function resolveActions(senderActions, hints, run) {
	var existing = [];
	if (senderActions && typeof senderActions.length === "number")
		for (var index = 0; index < senderActions.length; index++) existing.push(senderActions[index]);
	return existing.concat(actionsFor(firstLocalPath(hints), run));
}

if (typeof module !== "undefined") {
	module.exports = {
		HINT_KEY,
		OPEN_IDENTIFIER,
		REVEAL_IDENTIFIER,
		OPEN_TEXT,
		REVEAL_TEXT,
		urlList,
		isUsablePath,
		baseNameOf,
		openTextFor,
		decodeFileUrl,
		firstLocalPath,
		directoryOf,
		openArguments,
		revealArguments,
		actionsFor,
		resolveActions,
	};
}
