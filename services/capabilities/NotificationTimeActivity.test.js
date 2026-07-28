const assert = require("node:assert/strict");
const fs = require("node:fs");
const activitySource = fs.readFileSync(
	`${__dirname}/NotificationTimeActivity.js`,
	"utf8",
);
const activity = require("./NotificationTimeActivity.js");

assert.match(
	activitySource,
	/if \(typeof module !== "undefined"\) \{\s*module\.exports\s*=\s*\{/s,
);
const unguardedSource = activitySource.replace(
	/if \(typeof module !== "undefined"\) \{[\s\S]*?\n\}/,
	"",
);
assert.doesNotMatch(unguardedSource, /module\.exports\s*=/);

assert.equal(activity.shouldUpdateNotificationTime({}), false);
assert.equal(activity.shouldUpdateNotificationTime({ history: true }), false);
assert.equal(activity.shouldUpdateNotificationTime({ centerOpen: true }), true);
assert.equal(
	activity.shouldUpdateNotificationTime({ visiblePopup: true }),
	true,
);
assert.equal(
	activity.shouldUpdateNotificationTime({ queuedPopup: true }),
	true,
);
assert.equal(
	activity.shouldUpdateNotificationTime({
		centerOpen: false,
		visiblePopup: false,
		queuedPopup: false,
	}),
	false,
);
