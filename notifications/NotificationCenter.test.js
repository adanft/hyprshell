const assert = require("node:assert/strict");
const fs = require("node:fs");

const source = fs.readFileSync(__dirname + "/NotificationCenter.qml", "utf8");
const serviceSource = fs.readFileSync(
	__dirname + "/../services/capabilities/NotificationService.qml",
	"utf8",
);

assert.match(
	source,
	/model:\s*popup\.visible && popup\.services\.notification\.hasNotifications\s*\?\s*popup\.services\.notification\.notifications\s*:\s*\[\]/,
);
assert.match(
	source,
	/timeText:\s*popup\.services\.notification\.notificationTimeText\(entryData\)/,
);
assert.match(
	serviceSource,
	/if \(root\.notificationCenterOpen\) \{[\s\S]*root\.notificationTimeUpdateTick = !root\.notificationTimeUpdateTick/,
);
