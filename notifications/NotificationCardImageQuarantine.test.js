const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const read = (name) => fs.readFileSync(path.join(__dirname, name), "utf8");
const source = read("NotificationCard.qml");
const serviceSource = read("../services/capabilities/NotificationService.qml");
const centerSource = read("NotificationCenter.qml");
const popupSource = read("NotificationPopup.qml");

assert.match(serviceSource, /property var invalidLiveImageSources: \(\{\}\)/);
assert.match(serviceSource, /function isInvalidLiveImageSource/);
assert.match(serviceSource, /function quarantineInvalidLiveImageSource/);
assert.match(
	centerSource,
	/notificationService:\s*popup\.services\.notification/,
);
assert.match(
	popupSource,
	/notificationService:\s*popup\.services\.notification/,
);
assert.match(source, /required property var notificationService/);
assert.match(source, /isInvalidLiveImageSource\s*\(\s*iconSource\s*\)/);
assert.match(
	source,
	/source:\s*card\.iconSourceQuarantined \? "" : card\.iconSource/,
);
assert.match(source, /quarantineInvalidLiveImageSource\(failedSource\)/);
assert.ok(
	source.includes(
		'asynchronous: !card.iconSource.startsWith("image://qsimage/")',
	),
);
assert.ok(source.includes("card.iconSourceQuarantined"));
assert.doesNotMatch(
	source,
	/Timer\s*\{[^}]*failedImageSource|retry|blacklist/i,
);

console.log("NotificationCard image quarantine contract: PASS");
