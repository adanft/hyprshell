const assert = require("node:assert/strict");
const fs = require("node:fs");

const center = fs.readFileSync(`${__dirname}/NotificationCenter.qml`, "utf8");
const card = fs.readFileSync(`${__dirname}/NotificationCard.qml`, "utf8");

assert.match(center, /Shortcut \{\s*sequence: "Escape"/);
assert.equal((center.match(/activeFocusOnTab: true/g) || []).length, 2);
assert.match(center, /Accessible\.role: Accessible\.CheckBox/);
assert.match(center, /Accessible\.checked: popup\.services\.notification\.notificationDnd/);
assert.match(center, /Accessible\.name: "Clear all notifications"/);

assert.ok((card.match(/activeFocusOnTab:/g) || []).length >= 4);
assert.ok((card.match(/Accessible\.role: Accessible\.Button/g) || []).length >= 4);
assert.ok((card.match(/Keys\.onSpacePressed:/g) || []).length >= 4);
assert.ok((card.match(/Keys\.onReturnPressed:/g) || []).length >= 4);
assert.match(card, /Accessible\.pressed: card\.expanded/);
assert.match(card, /containsMouse \|\| \w+\.activeFocus/g);

console.log("Notifications: keyboard and accessibility contracts are complete");
