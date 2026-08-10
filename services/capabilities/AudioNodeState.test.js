const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const state = {};
vm.createContext(state);
vm.runInContext(
	fs.readFileSync(`${__dirname}/AudioNodeState.js`, "utf8"),
	state,
);

const output = {
	id: 7,
	nickname: "Desk",
	audio: {},
	isSink: true,
	isStream: false,
};
const stream = {
	id: 8,
	nickname: "Player",
	audio: {},
	isSink: true,
	isStream: true,
};
const source = { audio: {}, isSink: false, isStream: false };
const capture = { audio: {}, isSink: false, isStream: true };
const transientStream = {
	nickname: "Transient",
	audio: null,
	isSink: true,
	isStream: true,
};
stream.audio.muted = true;
assert.equal(
	state.isPlaybackStream(stream),
	true,
	"mute state must not affect topology membership",
);
assert.equal(
	state.isPlaybackStream(transientStream),
	false,
	"DMS-style projection excludes streams without current audio state",
);
const malformed = [
	null,
	{},
	{ isSink: true },
	{ audio: {}, isSink: false },
	capture,
];

assert.equal(state.isPhysicalOutput(output), true);
assert.equal(state.isPlaybackStream(output), false);
assert.equal(state.isPhysicalOutput(stream), false);
assert.equal(state.isPlaybackStream(stream), true);
assert.equal(state.isPhysicalOutput(source), false);
assert.equal(state.isPlaybackStream(source), false);
for (const node of malformed) {
	assert.equal(state.isPhysicalOutput(node), false);
	assert.equal(state.isPlaybackStream(node), false);
}

const alphaOutput = {
	nickname: " alpha ",
	audio: {},
	isSink: true,
	isStream: false,
};
const zetaStream = {
	nickname: "Zeta",
	audio: {},
	isSink: true,
	isStream: true,
};
const alphaStream = {
	properties: { "application.name": " alpha " },
	audio: {},
	isSink: true,
	isStream: true,
};
const nodes = [
	source,
	output,
	zetaStream,
	alphaOutput,
	stream,
	alphaStream,
	transientStream,
	capture,
];
assert.deepEqual(Array.from(state.physicalOutputs(nodes)), [
	alphaOutput,
	output,
]);
assert.deepEqual(Array.from(state.physicalOutputs(nodes, output)), [
	output,
	alphaOutput,
]);
assert.deepEqual(Array.from(state.playbackStreams(nodes)), [
	alphaStream,
	stream,
	zetaStream,
]);
assert.deepEqual(
	Array.from(state.playbackStreams(nodes.filter((node) => node !== stream))),
	[alphaStream, zetaStream],
	"a playback stream disappears when its node is absent",
);
assert.equal(
	state.containsCurrentNode(nodes, transientStream, state.isPlaybackStream),
	false,
);
assert.equal(
	state.containsCurrentNode(
		nodes.filter((node) => node !== transientStream),
		transientStream,
		state.isPlaybackStream,
	),
	false,
);
assert.equal(state.canControlPlaybackStream(nodes, transientStream), false);
assert.equal(state.canControlPlaybackStream(nodes, stream), true);
assert.equal(
	state.canControlPlaybackStream(
		nodes.filter((node) => node !== stream),
		stream,
	),
	false,
);
assert.deepEqual(Array.from(state.physicalOutputs(null)), []);
assert.deepEqual(Array.from(state.playbackStreams(undefined)), []);
assert.equal(
	state.containsCurrentNode(nodes, output, state.isPhysicalOutput),
	true,
);
assert.equal(
	state.containsCurrentNode(nodes, { ...output }, state.isPhysicalOutput),
	false,
	"equal metadata must not replace strict object identity",
);
assert.equal(
	state.containsCurrentNode([stream], output, state.isPhysicalOutput),
	false,
);
assert.equal(
	state.containsCurrentNode(nodes, stream, state.isPhysicalOutput),
	false,
);
output.isStream = true;
assert.equal(
	state.containsCurrentNode(nodes, output, state.isPhysicalOutput),
	false,
);
output.isStream = false;
let predicateCalls = 0;
assert.equal(
	state.containsCurrentNode([output], output, () => ++predicateCalls === 1),
	false,
);
assert.equal(
	predicateCalls,
	2,
	"candidate and current member must both be classified",
);

console.log(
	"AudioNodeState: classification, ordering, and strict identity passed",
);
