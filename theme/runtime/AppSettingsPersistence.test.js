const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const facade = fs.readFileSync(path.join(__dirname, "AppSettings.qml"), "utf8");
const persistence = fs.readFileSync(
	path.join(__dirname, "AppSettingsPersistence.qml"),
	"utf8",
);
const qmldir = fs.readFileSync(path.join(__dirname, "qmldir"), "utf8");

assert.match(qmldir, /^singleton AppSettings 1\.0 AppSettings\.qml$/m);
assert.match(
	qmldir,
	/^internal AppSettingsPersistence AppSettingsPersistence\.qml$/m,
);
assert.match(facade, /^pragma Singleton/m);
assert.match(facade, /property string currentTheme: ""/);
assert.match(facade, /property string currentWallpaper: ""/);
assert.match(facade, /Component\.onCompleted: persistence\.start\(\)/);
assert.match(facade, /AppSettingsPersistence\s*\{/);
assert.match(facade, /if \(currentTheme === name\)\s*return false/);
assert.match(facade, /if \(currentWallpaper === path\)\s*return false/);
assert.match(facade, /property bool startupThemeChanged: false/);
assert.match(facade, /property bool startupWallpaperChanged: false/);
assert.match(facade, /if \(!appSettings\.startupThemeChanged/);
assert.match(facade, /if \(!appSettings\.startupWallpaperChanged/);
assert.equal(
	(facade.match(/persistence\.persist\(/g) || []).length,
	3,
	"startup settles through one coalesced persist and ready changes persist directly",
);
assert.doesNotMatch(
	facade,
	/Quickshell|FileView|JsonAdapter|writeAdapter|configDirReady|configFile/,
);

assert.match(
	persistence,
	/signal loaded\(string currentTheme, string currentWallpaper\)/,
);
assert.match(persistence, /property bool configDirReady: false/);
assert.match(persistence, /property bool startupStarted: false/);
assert.match(persistence, /readonly property bool ready: configDirReady \&\& startupSettledEmitted/);
assert.match(persistence, /if \(!ready\)\s*return false/);
assert.match(persistence, /Quickshell\.env\("XDG_CONFIG_HOME"\)/);
assert.match(persistence, /Quickshell\.env\("HOME"\).*\/\.config/);
assert.match(persistence, /`\$\{configDir\}\/hyprshell`/);
assert.match(persistence, /`\$\{configRoot\}\/settings\.json`/);

// One directory, and no memory of the ones before it.
//
// The shell used to walk a list of every name it had ever had, so an older
// config could be copied forward. That is gone on purpose. A chain like it has
// to be extended at every rename and kept in step with two other lists in other
// files, and a list that must be edited in three places to stay correct is a
// list that will be edited in two.
//
// So this asserts the absence, not just the presence. Reading the current name
// would still pass with a migration bolted back on beside it; naming nothing
// but the current one is what says the decision held.
const configNames = new Set([...persistence.matchAll(/\$\{configDir\}\/([A-Za-z0-9_-]+)/g)].map(m => m[1]));
assert.deepEqual([...configNames], ["hyprshell"], "the settings live in exactly one directory");

// The names, not the words. Forbidding the word "migration" here would also
// forbid the comment above explaining why there is no longer one, and an
// assertion whose only remedy is deleting the explanation is worse than none.
for (const gone of ["qsrice", "qscomponents"])
	assert.ok(!persistence.includes(gone), `${gone} is not read from any more`);

// The directories the isolated session starts empty are exactly the ones the
// shell reads or writes. A name left here after the shell stopped using it is a
// directory in the list for no reason anyone can reconstruct.
const isolated = fs.readFileSync(`${__dirname}/../../scripts/isolated-session.sh`, "utf8");
const ownedMatch = isolated.match(/^readonly OWNED_CONFIG=\(([^)]*)\)/m);
assert.ok(ownedMatch, "the isolated session declares the directories it owns");
const owned = new Set(ownedMatch[1].trim().split(/\s+/));
for (const name of configNames)
	assert.ok(owned.has(name), `the isolated session must own ${name}, or a run reads the developer's real one`);
assert.ok(!owned.has("qsrice") && !owned.has("qscomponents"), "OWNED_CONFIG lists only directories the shell still reads");

assert.match(
	persistence,
	/path: persistence\.configDirReady \? persistence\.configFile : ""/,
);
assert.match(persistence, /printErrors: false/);
assert.match(persistence, /watchChanges: true/);
assert.match(persistence, /atomicWrites: true/);
assert.match(persistence, /interval: 100/);
assert.match(persistence, /repeat: false/);
assert.match(persistence, /settingsReloadTimer\.restart\(\)/);
assert.match(persistence, /settingsFileView\.reload\(\)/);
// One process, and only one. Making the directory is the whole of startup now:
// the test for an existing settings file and the copy that followed it are both
// gone with the migration, and a file that is not there yet reaches the view as
// FileNotFound, which the load-failure path already answers with the defaults.
assert.match(persistence, /\["mkdir", "-p", configRoot\]/);
assert.equal((persistence.match(/\.exec\(/g) || []).length, 1, "startup runs one process");
assert.match(persistence, /property string currentTheme: ""/);
assert.match(persistence, /property string currentWallpaper: ""/);
assert.match(persistence, /settingsFileView\.writeAdapter\(\)/);
// The parameter is declared rather than injected. Qt 6 deprecates injection,
// and the warning only ever fires when the load actually fails -- which is to
// say on a first launch, long after the settings file exists on any machine the
// shell has run on once.
assert.match(
	persistence,
	/onLoadFailed: error => persistence\.deliverLoadFailed\(error\)/,
);
assert.match(persistence, /signal startupSettled/);
assert.match(persistence, /startupSettled\(\)/);
assert.match(persistence, /FileViewError\.FileNotFound/);

console.log("AppSettings persistence extraction contract: PASS");
