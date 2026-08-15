const assert = require("node:assert/strict");
const files = require("./NotificationFileActions.js");

// Not our name. KDE reads this hint in libnotificationmanager, Flameshot, ksnip,
// KShare and Spectacle all send it, and winbar and ukui-notification-daemon read
// it without being KDE. Spelling it wrong here costs every one of those senders.
assert.equal(files.HINT_KEY, "x-kde-urls");

const path = "/home/someone/Pictures/Screenshots/screenshot 2026-08-15.png";
const url = "file:///home/someone/Pictures/Screenshots/screenshot%202026-08-15.png";

// The signature is `as`, and what Quickshell hands over is array-like but not an
// Array: Array.isArray() on the real hint is false, measured in an isolated
// session. A reader written against Array.isArray silently never fires, and
// from the passing side that is indistinguishable from one that works.
const arrayLike = { length: 1, 0: url };
assert.deepEqual(files.urlList({ "x-kde-urls": arrayLike }), [url]);
assert.deepEqual(files.urlList({ "x-kde-urls": [url] }), [url]);
// A scalar string is out of spec, but ukui-notification-daemon sends the hint
// that way and costs nothing to accept.
assert.deepEqual(files.urlList({ "x-kde-urls": url }), [url]);

assert.deepEqual(files.urlList({ "x-kde-urls": "" }), []);
assert.deepEqual(files.urlList({ "x-kde-urls": 42 }), []);
assert.deepEqual(files.urlList({ "sender-pid": 1 }), []);
assert.deepEqual(files.urlList({}), []);
assert.deepEqual(files.urlList(null), []);
assert.deepEqual(files.urlList("not an object"), []);
// Mixed contents keep the strings and drop the rest rather than failing whole.
assert.deepEqual(files.urlList({ "x-kde-urls": [url, 7, null, "file:///b"] }), [url, "file:///b"]);

// Percent decoding is the point: a space in a filename arrives as %20 and a
// path handed to xdg-open with a literal %20 in it names a different file.
assert.equal(files.decodeFileUrl(url), path);
assert.equal(files.decodeFileUrl("file:///tmp/a.png"), "/tmp/a.png");

// Only file://, and only with an empty authority. `file://host/path` names a
// file on another machine, and resolving it locally would open the wrong one.
assert.equal(files.decodeFileUrl("file://otherhost/tmp/a.png"), "");
assert.equal(files.decodeFileUrl("https://example.com/a.png"), "");
assert.equal(files.decodeFileUrl("smb://server/share/a.png"), "");
assert.equal(files.decodeFileUrl("/tmp/a.png"), "");
assert.equal(files.decodeFileUrl(""), "");
assert.equal(files.decodeFileUrl(null), "");
// A stray percent is a malformed URL, not a path that happens to contain one.
assert.equal(files.decodeFileUrl("file:///tmp/100%.png"), "");

// Any program on the bus can send this hint and the value reaches a shell
// command, so it is checked after decoding too — %27 decodes to the quote that
// would otherwise land inside the D-Bus literal in revealArguments.
assert.equal(files.decodeFileUrl("file:///tmp/it%27s.png"), "");
assert.equal(files.decodeFileUrl("file:///tmp/a%0Ab.png"), "");

assert.equal(files.firstLocalPath({ "x-kde-urls": [url] }), path);
// The first usable one, which is what KDE does: its own ThumbnailStrip notes the
// protocol allows several but only one is ever shown.
assert.equal(files.firstLocalPath({ "x-kde-urls": ["file:///a.png", "file:///b.png"] }), "/a.png");
// A leading url we cannot use must not hide a later one we can.
assert.equal(files.firstLocalPath({ "x-kde-urls": ["https://x/a.png", "file:///b.png"] }), "/b.png");
assert.equal(files.firstLocalPath({ "x-kde-urls": ["https://x/a.png"] }), "");
assert.equal(files.firstLocalPath({}), "");

assert.equal(files.directoryOf(path), "/home/someone/Pictures/Screenshots");
// A file directly under the root: the slash is the directory, not the empty
// string, which would make the reveal command open the process's own cwd.
assert.equal(files.directoryOf("/shot.png"), "/");
assert.equal(files.directoryOf("shot.png"), "");

assert.deepEqual(files.openArguments(path), ["xdg-open", path]);

const reveal = files.revealArguments(path);
assert.deepEqual(reveal.slice(0, 2), ["sh", "-c"]);
// The path travels as a positional argument, never spliced into the script
// text. That is what keeps the command one shape whatever the hint carried.
assert.equal(reveal[2].includes(path), false);
assert.deepEqual(reveal.slice(3), ["qsrice-file-reveal", path, "/home/someone/Pictures/Screenshots"]);
assert.match(reveal[2], /org\.freedesktop\.FileManager1\.ShowItems/);
assert.match(reveal[2], /\|\| exec xdg-open "\$2"/);

// NotificationCard counts as a button anything carrying invoke whose identifier
// is not "default", so neither of these may claim that name.
const run = [];
const built = files.actionsFor(path, args => run.push(args));
assert.deepEqual(
	built.map(action => action.identifier),
	[files.OPEN_IDENTIFIER, files.REVEAL_IDENTIFIER],
);
// The button names the file it opens. Any program on the bus can send this hint
// beside a summary and body of its choosing, so a button labelled only "Open"
// would let a notification claim one thing and open another.
assert.deepEqual(
	built.map(action => action.text),
	["Open screenshot 2026-08-15.png", "Show in folder"],
);
assert.equal(files.baseNameOf(path), "screenshot 2026-08-15.png");
assert.equal(files.baseNameOf("/shot.png"), "shot.png");
assert.equal(files.baseNameOf("shot.png"), "shot.png");
assert.equal(files.baseNameOf(""), "");
// A path ending in a slash has no name to show, and a button reading "Open "
// with nothing after it would be worse than one reading "Open".
assert.equal(files.openTextFor("/tmp/"), "Open");
assert.equal(built.some(action => action.identifier === "default"), false);

built[0].invoke();
built[1].invoke();
assert.deepEqual(run[0], ["xdg-open", path]);
assert.equal(run[1][0], "sh");

// No path, or nothing to run a command with, means no buttons rather than
// buttons that do nothing when pressed.
assert.deepEqual(files.actionsFor("", () => {}), []);
assert.deepEqual(files.actionsFor(path, null), []);

// Ours are added, never substituted. A notification comes from one sender, so
// the row that would be replaced is always that same sender's, and dropping it
// loses what only it could offer — Spectacle's "Annotate" among them.
const sent = [
	{ identifier: "open", text: "Open", invoke: () => {} },
	{ identifier: "annotate", text: "Annotate", invoke: () => {} },
];
assert.deepEqual(
	files.resolveActions(sent, { "x-kde-urls": [url] }, () => {}).map(action => action.identifier),
	["open", "annotate", files.OPEN_IDENTIFIER, files.REVEAL_IDENTIFIER],
);
// And the sender's own "Open" is still distinguishable from ours, which is what
// naming the file bought: this is why displacing the row is no longer needed.
assert.deepEqual(
	files.resolveActions(sent, { "x-kde-urls": [url] }, () => {}).map(action => action.text),
	["Open", "Annotate", "Open screenshot 2026-08-15.png", "Show in folder"],
);
// With no usable url the sender keeps everything: this must never be a way to
// lose the actions of a notification that has nothing to do with files.
assert.deepEqual(
	files.resolveActions(sent, {}, () => {}).map(action => action.identifier),
	["open", "annotate"],
);
assert.deepEqual(
	files.resolveActions(sent, { "x-kde-urls": ["https://x/a.png"] }, () => {}).map(action => action.text),
	["Open", "Annotate"],
);
assert.deepEqual(files.resolveActions(null, {}, () => {}), []);
// The sender's list is copied out rather than handed back, because the same
// array is read again when the entry is written to history.
const resolved = files.resolveActions(sent, {}, () => {});
assert.notEqual(resolved, sent);
assert.equal(sent.length, 2);

console.log("NotificationFileActions: x-kde-urls parsed array-like, decoded, guarded, named, and added to sender actions");
