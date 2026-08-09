const assert = require("node:assert/strict");
const fs = require("node:fs");

const source = fs.readFileSync(`${__dirname}/NotificationPopupManager.qml`, "utf8");

assert.doesNotMatch(source, /isFocusedScreen|focusedNotificationScreenName/);
assert.match(source, /"active": true/);
assert.match(source, /"hoverOwnerId": root\.hoverOwnerId/);
assert.match(source, /registerNotificationPopupManager\(\)/);
assert.match(source, /unregisterNotificationPopupManager\(hoverOwnerId\)/);
assert.match(source, /visible: stackHeight > 0/);
assert.match(source, /readonly property real maxStackHeight:/);
assert.match(source, /implicitHeight: Math\.max\(1, Math\.min\(stackHeight, maxStackHeight\)\)/);
assert.match(source, /id: popupLayer\s*anchors\.fill: parent\s*clip: true/);

console.log("NotificationPopupManager: every monitor renders a bounded popup stack");
