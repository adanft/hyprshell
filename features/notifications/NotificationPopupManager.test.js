const assert = require("node:assert/strict");
const fs = require("node:fs");

const source = fs.readFileSync(`${__dirname}/NotificationPopupManager.qml`, "utf8");

assert.doesNotMatch(source, /isFocusedScreen|focusedNotificationScreenName/);
assert.match(source, /"active": true/);
assert.match(source, /"hoverOwnerId": root\.hoverOwnerId/);
assert.match(source, /registerNotificationPopupManager\(\)/);
assert.match(source, /unregisterNotificationPopupManager\(hoverOwnerId\)/);
assert.match(source, /readonly property real maxStackHeight:/);

// The window is sized and shown from the ALLOCATED stack height, never the
// painted one. This object is an xdg_popup surface, so sizing it from a value
// that moves every frame makes the compositor reconfigure that surface once per
// frame for the length of an expand. Pinned here because the difference is one
// identifier and is invisible in a screenshot: both spellings look right, and
// only one of them stops asking the compositor to resize a window thirteen times
// for one click.
assert.match(source, /implicitHeight: Math\.max\(1, Math\.min\(allocatedStackHeight, maxStackHeight\)\)/);
assert.match(source, /visible: allocatedStackHeight > 0/);
assert.doesNotMatch(source, /implicitHeight:[^\n]*\bstackHeight\b(?![A-Za-z])/);

// And the two must stay distinct: `stackHeight` is what is painted, so it is
// what the cards are positioned by. Collapsing them back into one property would
// silently reintroduce whichever defect the survivor does not cover.
assert.match(source, /stackHeight = Math\.max\(0, y - root\.spacing\)/);
assert.match(source, /allocatedStackHeight = Math\.max\(0, allocated - root\.spacing\)/);

// The slot readers take the height honestly. `renderedLayoutHeight || layoutHeight`
// treated a legitimate zero as "unset" and reserved a full-height slot for a card
// that had nothing to show yet, which collapsed one frame later.
assert.doesNotMatch(source, /renderedLayoutHeight \|\| /);

// The two readers answer different questions, so exactly one of them falls back.
// A card is given its data and measured in the same call stack, one turn before
// the deferred pass that sets its geometry: for that turn it reports no
// allocation while `layoutHeight` already knows how tall it will be.
//
// Sliced apart rather than matched over the whole file, because the interesting
// property is WHICH function contains the fallback. A single file-wide match
// would go on passing if the fallback migrated into the wrong one, which is the
// failure worth catching — that is how the old single reader got it wrong.
const readers = source.indexOf("function popupSlotHeight");
const allocationReader = source.indexOf("function popupSlotAllocation");
assert.ok(readers !== -1 && allocationReader > readers, "both slot readers present, in order");

const paintedReader = source.slice(readers, allocationReader);
const promisedReader = source.slice(allocationReader);

// Asked what is on screen. For that turn the honest answer is nothing, so it
// must not reach for the target height.
assert.doesNotMatch(paintedReader, /item\.layoutHeight/);

// Asked what to promise. Being too small here is the answer that shows, because
// a window short of the card about to be painted into it clips that card.
assert.match(promisedReader, /const target = Number\(item\.layoutHeight\)/);
assert.match(source, /id: popupLayer\s*anchors\.fill: parent\s*clip: true/);

console.log("NotificationPopupManager: every monitor renders a bounded popup stack");
