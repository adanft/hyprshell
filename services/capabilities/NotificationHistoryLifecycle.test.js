const assert = require("node:assert/strict");
const fs = require("node:fs");

const source = fs.readFileSync(`${__dirname}/NotificationService.qml`, "utf8");
assert.match(source, /property bool notificationHistoryWritePending: false/);
assert.match(source, /blockWrites: true/);
assert.match(source, /atomicWrites: true/);
assert.match(
	source,
	/function scheduleNotificationHistorySave\(\) \{\s*root\.notificationHistoryWritePending = true\s*saveTimer\.restart\(\)/,
);
assert.match(
	source,
	/Component\.onDestruction: \{[\s\S]*if \(root\.notificationHistoryWritePending\)\s*root\.saveNotificationHistory\(\)/,
);
assert.match(
	source,
	/historyFileView\.writeAdapter\(\)\s*root\.notificationHistoryWritePending = false/,
);

console.log("Notification history: pending lifecycle flush is blocking and auditable");
