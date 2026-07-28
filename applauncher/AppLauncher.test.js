const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const read = (file) => fs.readFileSync(path.join(__dirname, file), "utf8");
const qml = read("AppLauncher.qml");
const workflowSource = read("AppLauncherOpenWorkflow.js");
const workflow = {};
vm.createContext(workflow);
vm.runInContext(`${workflowSource}\nthis.open = open;`, workflow);

assert.match(
	qml,
	/import "AppLauncherOpenWorkflow\.js" as AppLauncherOpenWorkflow/,
);
assert.match(qml, /AppLauncherOpenWorkflow\.open\(searchText,\s*\{/);
const openBody = qml.match(
	/function open\(\)[\s\S]*?\n {4}function close\(\)/,
)[0];
assert.doesNotMatch(openBody, /applySearchFilter\(/);
assert.match(
	qml,
	/function refreshApplications\(\)[\s\S]*?searchFilterTimer\.stop\(\)[\s\S]*?applySearchFilter\(/,
	"refreshApplications must use applySearchFilter, which stops the debounce timer",
);

for (const searchText of ["", "calculator"]) {
	const calls = [];
	const state = { searchText };
	workflow.open(searchText, {
		clearSearch: () => {
			state.searchText = "";
			calls.push("clearSearch");
		},
		refreshApplications: () => calls.push("refreshApplications"),
		resetSelection: () => calls.push("resetSelection"),
		show: () => calls.push("show"),
		scheduleFocus: () => calls.push("scheduleFocus"),
	});

	assert.deepEqual(
		calls,
		searchText === ""
			? ["refreshApplications", "resetSelection", "show", "scheduleFocus"]
			: [
					"clearSearch",
					"refreshApplications",
					"resetSelection",
					"show",
					"scheduleFocus",
				],
		`open order for searchText=${JSON.stringify(searchText)}`,
	);
	assert.equal(
		calls.filter((call) => call === "refreshApplications").length,
		1,
	);
	assert.equal(
		calls.filter((call) => call === "clearSearch").length,
		searchText ? 1 : 0,
	);
	assert.equal(state.searchText, "");
}

console.log("AppLauncher: open workflow has one refresh path");
