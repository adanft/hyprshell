const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
	path.join(__dirname, "NotificationCard.qml"),
	"utf8",
);

assert.match(source, /property string failedImageSource: ""/);
assert.match(
	source,
	/readonly property bool iconSourceQuarantined:\s*failedImageSource\.length > 0 && iconSource === failedImageSource/,
);
assert.match(
	source,
	/onIconSourceChanged:\s*\{\s*if \(failedImageSource\.length > 0 && iconSource !== failedImageSource\)\s*failedImageSource = "";?\s*\}/,
);
assert.match(
	source,
	/source:\s*card\.iconSourceQuarantined \? "" : card\.iconSource/,
);
assert.match(
	source,
	/asynchronous:\s*!card\.iconSource\.startsWith\("image:\/\/qsimage\/"\)/,
);
assert.match(
	source,
	/onStatusChanged:\s*\{\s*const failedSource = source\.toString\(\);\s*if \(status === Image\.Error && failedSource\.startsWith\("image:\/\/qsimage\/"\)\)\s*card\.failedImageSource = failedSource;?\s*\}/,
);
assert.match(
	source,
	/visible:\s*card\.fallbackIconSource\.length > 0 && \(!card\.iconSourceIsImageFile \|\| card\.iconSourceQuarantined \|\| notificationImage\.status === Image\.Error\)/,
);
assert.doesNotMatch(
	source,
	/Timer\s*\{[^}]*failedImageSource|retry|blacklist/i,
);

console.log("NotificationCard image quarantine contract: PASS");
