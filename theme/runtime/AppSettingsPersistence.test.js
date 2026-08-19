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
assert.match(qmldir, /^internal AppSettingsPersistence AppSettingsPersistence\.qml$/m);
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
assert.equal((facade.match(/persistence\.persist\(/g) || []).length, 3);
assert.doesNotMatch(facade, /Quickshell|FileView|JsonAdapter|writeAdapter|configDirReady|configFile/);

assert.match(persistence, /signal loaded\(string currentTheme, string currentWallpaper\)/);
assert.match(persistence, /property bool configDirReady: false/);
assert.match(persistence, /property bool startupStarted: false/);
assert.match(persistence, /readonly property bool ready: configDirReady && startupSettledEmitted/);
assert.match(persistence, /if \(!ready\)\s*return false/);
assert.match(persistence, /Quickshell\.env\("XDG_CONFIG_HOME"\)/);
assert.match(persistence, /Quickshell\.env\("HOME"\).*\/\.config/);
assert.match(persistence, /property string configFile: `\$\{configRoot\}\/settings\.json`/);
assert.match(persistence, /`\$\{configDir\}\/hyprshell`/);
assert.match(persistence, /path: persistence\.configDirReady \? persistence\.configFile : ""/);
assert.match(persistence, /printErrors: false/);
assert.match(persistence, /watchChanges: true/);
assert.match(persistence, /atomicWrites: true/);
assert.match(persistence, /interval: 100/);
assert.match(persistence, /repeat: false/);
assert.match(persistence, /settingsReloadTimer\.restart\(\)/);
assert.match(persistence, /settingsFileView\.reload\(\)/);
assert.match(persistence, /\["mkdir", "-p", configRoot\]/);
assert.equal((persistence.match(/\.exec\(/g) || []).length, 1);
assert.match(persistence, /settingsFileView\.writeAdapter\(\)/);
assert.match(persistence, /onLoadFailed: error => persistence\.deliverLoadFailed\(error\)/);
assert.match(persistence, /signal startupSettled/);
assert.match(persistence, /startupSettled\(\)/);
assert.match(persistence, /FileViewError\.FileNotFound/);

const isolated = fs.readFileSync(path.join(__dirname, "../../scripts/isolated-session.sh"), "utf8");
assert.match(isolated, /^readonly OWNED_CONFIG=\(hypr hyprshell\)$/m);

console.log("AppSettings persistence current ownership contract: PASS");
