const assert = require("node:assert/strict");
const fs = require("node:fs");

const card = fs.readFileSync(`${__dirname}/NotificationCard.qml`, "utf8");
const popup = fs.readFileSync(`${__dirname}/NotificationPopup.qml`, "utf8");

assert.match(
	card,
	/readonly property bool cardHovered: cardHoverHandler\.hovered \|\| closeMouse\.containsMouse \|\| expandMouse\.containsMouse/,
);
assert.match(
	card,
	/border\.color: card\.cardHovered \? card\.colors\.secondary : card\.colors\.border/,
);
assert.match(card, /HoverHandler\s*{\s*id: cardHoverHandler\s*cursorShape: Qt\.ArrowCursor/);
assert.match(
	card,
	/id: defaultActionMouse[\s\S]*?cursorShape: Qt\.ArrowCursor[\s\S]*?onClicked: card\.actionInvoked\(card\.defaultAction\)/,
);
assert.match(
	popup,
	/running: popup\.active && popup\.visible && !popup\.exiting && !notificationCard\.cardHovered/,
);

for (const [id, click] of [
	["closeMouse", "card.closeRequested()"],
	["expandMouse", "card.toggleExpanded()"],
]) {
	const area = new RegExp(`id: ${id}([\\s\\S]*?)\\n\\s*}`);
	const match = area.exec(card);
	assert.ok(match, `${id} must exist`);
	assert.match(match[1], /hoverEnabled: true/);
	assert.match(match[1], /activeFocusOnTab: true/);
	assert.match(match[1], /Accessible\.role: Accessible\.Button/);
	assert.ok(match[1].includes(`onClicked: ${click}`));
}

assert.match(card, /text: card\.expanded \? card\.icons\.chevronUp : card\.icons\.chevronDown/);

console.log("NotificationCard: whole-card hover pauses timeout and preserves controls");
