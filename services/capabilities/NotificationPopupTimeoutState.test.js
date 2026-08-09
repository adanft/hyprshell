const assert = require("node:assert/strict");
const TimeoutState = require("./NotificationPopupTimeoutState.js");

function stateWithPopup(timeout = 1000) {
	const state = TimeoutState.createState();
	TimeoutState.addPopup(state, 7, timeout, 0);
	return state;
}

{
	const state = stateWithPopup();
	assert.equal(TimeoutState.remaining(state, 7, 300), 700);
	TimeoutState.setHovered(state, "monitor-a", 7, true, 300);
	assert.deepEqual(TimeoutState.tick(state, 1500), []);
	assert.equal(TimeoutState.remaining(state, 7, 1500), 700);
	TimeoutState.setHovered(state, "monitor-a", 7, false, 1500);
	assert.deepEqual(TimeoutState.tick(state, 2199), []);
	assert.deepEqual(TimeoutState.tick(state, 2200), [7]);
}

{
	const state = stateWithPopup();
	TimeoutState.setHovered(state, "monitor-a", 7, true, 100);
	TimeoutState.setHovered(state, "monitor-b", 7, true, 200);
	TimeoutState.setHovered(state, "monitor-a", 7, false, 500);
	assert.equal(TimeoutState.isHovered(state, 7), true);
	TimeoutState.releaseOwner(state, "monitor-b", 1200);
	assert.equal(TimeoutState.isHovered(state, 7), false);
	assert.equal(TimeoutState.remaining(state, 7, 1200), 900);
	assert.deepEqual(TimeoutState.tick(state, 2100), [7]);
}

{
	const state = stateWithPopup(0);
	assert.deepEqual(TimeoutState.tick(state, 60000), []);
	assert.equal(TimeoutState.remaining(state, 7, 60000), 0);
}

{
	const state = stateWithPopup(100);
	assert.deepEqual(TimeoutState.tick(state, 100), [7]);
	assert.deepEqual(TimeoutState.tick(state, 200), []);
}

console.log("NotificationPopupTimeoutState: aggregate hover and single-owner expiry passed");
