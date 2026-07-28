const assert = require("node:assert/strict");
const activity = require("./NotificationTimeActivity.js");

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
