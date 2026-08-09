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
	/border\.color: card\.colors\.border/,
);
assert.doesNotMatch(card, /border\.color:.*cardHovered/);
assert.match(
	card,
	/case NotificationUrgency\.Critical:\s*return card\.colors\.critical[\s\S]*?case NotificationUrgency\.Low:\s*return card\.colors\.text[\s\S]*?default:\s*return card\.colors\.info/,
);
assert.match(
	card,
	/readonly property color urgencyBarHoverColor: card\.colors\.success/,
);
assert.doesNotMatch(card, /Qt\.lighter\(urgencyBarColor/);
assert.match(
	card,
	/color: card\.cardHovered \? card\.urgencyBarHoverColor : card\.urgencyBarColor/,
);
assert.match(card, /HoverHandler\s*{\s*id: cardHoverHandler\s*cursorShape: Qt\.ArrowCursor/);
assert.match(
	card,
	/id: defaultActionMouse[\s\S]*?cursorShape: Qt\.ArrowCursor[\s\S]*?onClicked: card\.actionInvoked\(card\.defaultAction\)/,
);
assert.match(
	popup,
	/setNotificationPopupHovered\(popup\.hoverOwnerId, popup\.popupData\.id,[\s\S]*?cardHovered\)/,
);
assert.doesNotMatch(popup, /\bTimer\s*\{|closeNotificationPopup\(popup\.popupData\.id\)[\s\S]*?onTriggered/);

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
