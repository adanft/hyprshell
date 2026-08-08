const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const childProcess = require("node:child_process");

const directory = fs.mkdtempSync(path.join(os.tmpdir(), "qsrice-qmlrunner-"));
const pathRunner = path.join(directory, "qmltestrunner");
fs.writeFileSync(pathRunner, "#!/bin/sh\nexit 0\n", { mode: 0o755 });
const finder = path.join(__dirname, "find-qmltestrunner.sh");

try {
	const fromPath = childProcess.execFileSync("/bin/bash", [finder], {
		env: { ...process.env, PATH: directory, QMLTESTRUNNER: "" },
		encoding: "utf8",
	});
	assert.equal(fromPath.trim(), pathRunner);

	const override = path.join(directory, "custom-runner");
	fs.copyFileSync(pathRunner, override);
	fs.chmodSync(override, 0o755);
	const fromOverride = childProcess.execFileSync("/bin/bash", [finder], {
		env: { ...process.env, PATH: "", QMLTESTRUNNER: override },
		encoding: "utf8",
	});
	assert.equal(fromOverride.trim(), override);
} finally {
	fs.rmSync(directory, { recursive: true, force: true });
}

console.log("qmltestrunner discovery: override and temporary PATH passed");
