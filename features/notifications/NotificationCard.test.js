const assert = require("node:assert/strict");
const fs = require("node:fs");

const source = fs.readFileSync(`${__dirname}/NotificationCard.qml`, "utf8");

// The layered rectangle is sized in whole pixels, and this is the assertion that
// says the CARD is wired that way.
//
// A layer rasterises an item's contents into a texture the size of that item.
// The height here is animated, and an animation between two integers passes
// through fractional values, so without rounding the texture differs by a
// fraction of a pixel every frame, the mapping back to the screen shifts with
// it, and every glyph inside is resampled slightly differently. Measured across
// heights 160.00 to 161.00 in quarter-pixel steps, on a band of text that never
// moves in layout: 5525 of 36480 pixels changed raw, 0 rounded. The text was
// never moving — it was being redrawn wrong, which is why it read as trembling.
//
// tests/tst_NotificationCardPixelGrid.qml runs that mechanism, but it builds its
// own miniature, so it stays green if this file loses the rounding. Verified by
// removing it and watching that suite pass. This assertion is the half that
// notices, and it lives here because the binding is what it is about.
const cardRect = source.indexOf("id: cardRect");
const cardRectEnd = source.indexOf("radius: card.cornerRadius", cardRect);
assert.ok(cardRect !== -1 && cardRectEnd > cardRect, "the layered rectangle, and its radius");

const geometry = source.slice(cardRect, cardRectEnd);
assert.match(geometry, /height: card\.renderedHeightPx/);
assert.doesNotMatch(geometry, /height: card\.renderedLayoutHeight/);

// And the property it points at actually rounds. Pinned separately because the
// binding above would read exactly the same if this stopped doing anything.
assert.match(source, /readonly property real renderedHeightPx: Math\.round\(renderedLayoutHeight\)/);

// The card's inner viewport comes off the rounded value too, so the clip rects
// inside the texture sit on the same grid as the texture itself.
assert.match(source, /readonly property real viewportHeight: Math\.max\(0, renderedHeightPx - contentInset \* 2\)/);

// And so does the height the card reports upward. A first pass rounded only
// what was painted and left this on the raw value, which put the painted card
// and the slot the notification centre's list gives it half a pixel apart for
// the length of an expand — a divergence that did not exist before, because
// both used to read the same expression. Pinned because the two spellings are
// one identifier apart and only one of them keeps them on the same grid.
assert.match(source, /implicitHeight: useRenderedHeightForLayout \? renderedHeightPx : allocatedLayoutHeight/);
assert.doesNotMatch(source, /implicitHeight: useRenderedHeightForLayout \? renderedLayoutHeight/);

// The app icon stays pinned to the top of its row. Anchored to the row's
// vertical center it drifted down through the whole expand — the row takes its
// height from the growing column — while the close button beside it stayed put.
//
// Cut to the container's own property block rather than matched within some
// number of characters of its id: the first attempt allowed 400 and the anchor
// sits over 900 away, so it could not have failed however the icon was
// anchored. A window wide enough today closes the next time someone adds a line
// of explanation above the property it was meant to reach.
const iconStart = source.indexOf("id: iconContainer");
const iconEnd = source.indexOf("id: notificationImage", iconStart);
assert.ok(iconStart !== -1 && iconEnd > iconStart, "the icon container and its image, in order");

const iconGeometry = source.slice(iconStart, iconEnd);
assert.doesNotMatch(iconGeometry, /anchors\.verticalCenter/);
assert.match(iconGeometry, /anchors\.top: parent\.top/);

console.log("NotificationCard: the layered rectangle sits on whole pixels, and the icon stays at the top");
