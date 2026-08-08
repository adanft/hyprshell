const assert = require("node:assert/strict");
const fs = require("node:fs");

const source = fs.readFileSync(`${__dirname}/WallpaperThumbnailCache.qml`, "utf8");
assert.match(source, /readonly property int generationTimeoutMs: 15000/);
assert.match(source, /generationTimeout\.restart\(\)/);
assert.match(source, /if \(process && process\.running\)\s*process\.signal\(9\)/);
assert.match(source, /cache\.failJob\(\)/);
assert.match(source, /activeJobs--/);
assert.match(source, /cleanup\.exec\(\["rm", "-f", "--", temporary\]\)/);
assert.match(source, /cleanup\.destroy\(\)\s*cache\.pump\(\)/);

console.log("WallpaperThumbnailCache: hung generation terminates, cleans up, and resumes queue");
