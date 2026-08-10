function currentNodes(nodes) {
	if (!nodes) return [];
	try {
		return Array.from(nodes);
	} catch (_) {
		return [];
	}
}

function isPhysicalOutput(node) {
	return Boolean(node && node.audio && node.isSink && !node.isStream);
}

function isPlaybackStream(node) {
	return Boolean(node && node.audio && node.isSink && node.isStream);
}

function normalizedNodeKey(node, stream) {
	var properties = node && node.properties;
	var values = stream
		? [
				properties && properties["application.name"],
				node && node.nickname,
				node && node.description,
				node && node.name,
			]
		: [node && node.nickname, node && node.description, node && node.name];
	for (var value of values) {
		var normalized =
			value === undefined || value === null
				? ""
				: String(value).trim().toLowerCase();
		if (normalized) return normalized;
	}
	return stream ? "audio stream" : "default output";
}

function stableNodes(nodes, predicate, activeNode, stream) {
	return currentNodes(nodes)
		.filter(predicate)
		.map((node, index) => ({
			node,
			index,
			key: normalizedNodeKey(node, stream),
		}))
		.sort((left, right) => {
			if (activeNode && left.node === activeNode) return -1;
			if (activeNode && right.node === activeNode) return 1;
			return left.key < right.key
				? -1
				: left.key > right.key
					? 1
					: left.index - right.index;
		})
		.map((entry) => entry.node);
}

function physicalOutputs(nodes, activeNode) {
	return stableNodes(nodes, isPhysicalOutput, activeNode, false);
}

function playbackStreams(nodes) {
	return stableNodes(nodes, isPlaybackStream, null, true);
}

function containsCurrentNode(nodes, node, predicate) {
	if (!node || typeof predicate !== "function" || !predicate(node))
		return false;
	return currentNodes(nodes).some(
		(current) => current === node && predicate(current),
	);
}

function canControlPlaybackStream(nodes, node) {
	try {
		return (
			containsCurrentNode(nodes, node, isPlaybackStream) &&
			Boolean(node.audio)
		);
	} catch (_) {
		return false;
	}
}
