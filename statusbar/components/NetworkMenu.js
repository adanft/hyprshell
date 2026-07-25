function menuOuterHeight(availableHeight, preferredMinimum, naturalHeight) {
	return Math.max(
		0,
		Math.min(
			Math.max(0, Number(availableHeight) || 0),
			Math.max(
				Math.max(0, Number(preferredMinimum) || 0),
				Math.max(0, Number(naturalHeight) || 0),
			),
		),
	);
}

function detailViewportHeight(
	active,
	detailHeight,
	remainingCapacity,
	bootstrapHeight,
) {
	if (!active) return 0;
	var capacity = Math.max(0, Number(remainingCapacity) || 0);
	var measuredDetail = Math.max(0, Number(detailHeight) || 0);
	var desiredHeight =
		measuredDetail > 0
			? measuredDetail
			: Math.max(0, Number(bootstrapHeight) || 0);
	return Math.min(desiredHeight, capacity);
}

function menuCenterHeight(
	monitorHeight,
	safetyMargin,
	preferredInactiveMinimum,
	padding,
	fixedShellHeight,
	detailGap,
	active,
	detailHeight,
	bootstrapHeight,
) {
	var windowHeight = Math.max(0, Number(monitorHeight) || 0);
	var margin = Math.max(0, Number(safetyMargin) || 0);
	var safeAvailable = Math.max(0, windowHeight - margin);
	var outerPadding = Math.max(0, Number(padding) || 0);
	var fixedHeight = Math.max(0, Number(fixedShellHeight) || 0);
	if (!active)
		return menuOuterHeight(
			safeAvailable,
			preferredInactiveMinimum,
			outerPadding + fixedHeight,
		);

	var gap = Math.max(0, Number(detailGap) || 0);
	var activeTotalCap = Math.min(safeAvailable, windowHeight * 0.7);
	var detailCapacity = Math.max(
		0,
		activeTotalCap - outerPadding - fixedHeight - gap,
	);
	var detailAllocation = detailViewportHeight(
		true,
		detailHeight,
		detailCapacity,
		bootstrapHeight,
	);
	return menuOuterHeight(
		activeTotalCap,
		0,
		outerPadding + fixedHeight + gap + detailAllocation,
	);
}

function clampDetailContentY(active, contentY, contentHeight, viewportHeight) {
	var viewport = Math.max(0, Number(viewportHeight) || 0);
	if (!active || viewport <= 0) return 0;
	var maximum = Math.max(0, (Number(contentHeight) || 0) - viewport);
	return Math.min(Math.max(0, Number(contentY) || 0), maximum);
}

function normalizedText(value) {
	return value === undefined || value === null ? "" : String(value).trim();
}

function userInitial(username) {
	var value = normalizedText(username);
	return value.length > 0 ? value.charAt(0).toUpperCase() : "U";
}

function hostnameOrFallback(hostname) {
	var value = normalizedText(hostname);
	return value.length > 0 ? value : "localhost";
}

function formatUptime(seconds) {
	var numericSeconds = Number(seconds);
	if (!Number.isFinite(numericSeconds) || numericSeconds < 0)
		numericSeconds = 0;

	var totalMinutes = Math.floor(numericSeconds / 60);
	var days = Math.floor(totalMinutes / 1440);
	var hours = Math.floor((totalMinutes % 1440) / 60);
	var minutes = totalMinutes % 60;
	if (days > 0) return "Up " + days + "d " + hours + "h";
	if (hours > 0) return "Up " + hours + "h " + minutes + "m";
	return "Up " + minutes + "m";
}

function networkStatus(network) {
	if (!network) return "Unavailable";
	if (network.connected) return "Connected";
	return network.known ? "Saved" : "Available";
}

function canForgetNetwork(network) {
	return Boolean(
		network && network.known && !network.connected && !network.stateChanging,
	);
}

function networkSignalText(network) {
	if (!network) return "0%";
	if (network.stateChanging) return "…";
	return Math.round((Number(network.signalStrength) || 0) * 100) + "%";
}

function wifiSummary(network, wifiHardwareEnabled) {
	if (network) return network.name + " · " + networkSignalText(network);
	return wifiHardwareEnabled ? "Not connected" : "Disabled by hardware";
}

function wifiSignalQualityText(network) {
	if (!network) return "";
	return Math.round((Number(network.signalStrength) || 0) * 100) + "%";
}

function wifiSecurityLabel(network, openSecurityValue) {
	if (!network) return "";
	return network.security === openSecurityValue ? "Open" : "Secured";
}

function wifiNetworkMeta(network, openSecurityValue) {
	if (!network) return "";
	return (
		wifiSecurityLabel(network, openSecurityValue) +
		" · " +
		wifiSignalQualityText(network)
	);
}

function sortedWifiNetworks(networks) {
	return Array.from(networks || [])
		.map((network, index) => ({ network: network, index: index }))
		.sort((left, right) => {
			var connectedDifference =
				Number(Boolean(right.network.connected)) -
				Number(Boolean(left.network.connected));
			if (connectedDifference !== 0) return connectedDifference;

			var signalDifference =
				(Number(right.network.signalStrength) || 0) -
				(Number(left.network.signalStrength) || 0);
			return signalDifference !== 0
				? signalDifference
				: left.index - right.index;
		})
		.map((entry) => entry.network);
}

function nextExpandedSection(currentSection, requestedSection) {
	return currentSection === requestedSection ? "" : requestedSection;
}

function ethernetToggleAction(network) {
	if (!network || network.stateChanging) return null;
	return network.connected ? "disconnect" : "connect";
}

function ethernetProfileLabel(profile) {
	if (!profile) return "Unnamed profile";
	return profile.id || profile.uuid || "Unnamed profile";
}

function shouldScanWifi(
	menuOpen,
	expandedSection,
	wifiEnabled,
	wifiHardwareEnabled,
) {
	return Boolean(
		menuOpen &&
			expandedSection === "wifi" &&
			wifiEnabled &&
			wifiHardwareEnabled,
	);
}

function bluetoothSummary(available, powered, connectedCount) {
	if (!available) return "Unavailable";
	if (!powered) return "Off";
	var count = Math.max(0, Number(connectedCount) || 0);
	return count > 0 ? count + " connected" : "Enabled";
}

function microphoneSummary(available, muted, volume) {
	if (!available) return "Unavailable";
	if (muted) return "Muted";
	var value = Math.max(0, Math.min(100, Math.round(Number(volume) || 0)));
	return value + "%";
}

function outputAvailable(sink, quickVolume) {
	if (!sink || !sink.audio || !quickVolume) return false;
	var percent = quickVolume.authoritativePercent;
	return (
		percent !== null &&
		percent !== undefined &&
		Number.isFinite(Number(percent)) &&
		quickVolume.availability !== "unavailable"
	);
}

function outputPercent(authoritativePercent) {
	var numeric = Number(authoritativePercent);
	if (!Number.isFinite(numeric)) numeric = 0;
	return Math.max(0, Math.min(100, Math.round(numeric)));
}

function outputSummary(available, muted, authoritativePercent) {
	if (!available) return "Unavailable";
	if (muted) return "Muted";
	return outputPercent(authoritativePercent) + "%";
}

function audioOutputLabel(node, fallback) {
	var fallbackLabel = normalizedText(fallback) || "Default output";
	if (!node) return fallbackLabel;
	for (var value of [node.nickname, node.description, node.name]) {
		var label = normalizedText(value);
		if (label.length > 0) return label;
	}
	return fallbackLabel;
}

function audioOutputStatus(node, active) {
	if (active)
		return node && node.audio && node.audio.muted
			? "Active · Muted"
			: "Active output";
	return node && node.audio && node.audio.muted ? "Muted" : "Available";
}

function audioNodePercent(node) {
	var volume = Number(node && node.audio && node.audio.volume);
	if (!Number.isFinite(volume)) return null;
	return Math.max(0, Math.min(100, Math.round(volume * 100)));
}

function nodeProperty(node, name) {
	if (!node || !node.properties) return "";
	try {
		return normalizedText(node.properties[name]);
	} catch (_) {
		return "";
	}
}

function playbackStreamLabel(node) {
	var application = nodeProperty(node, "application.name");
	if (application) return application;
	if (node) {
		for (var value of [node.nickname, node.description, node.name]) {
			var label = normalizedText(value);
			if (label) return label;
		}
	}
	return "Audio stream";
}

function playbackStreamDescription(node) {
	var media = nodeProperty(node, "media.name");
	return media && media !== playbackStreamLabel(node)
		? media
		: "Playback stream";
}

function volumeIconKind(available, muted, percentValue) {
	if (!available) return "unavailable";
	var percent = outputPercent(percentValue);
	if (muted || percent === 0) return "muted";
	if (percent < 34) return "low";
	if (percent < 67) return "medium";
	return "high";
}

function audioNodeIconKind(node) {
	var percent = audioNodePercent(node);
	return volumeIconKind(
		percent !== null,
		Boolean(node && node.audio && node.audio.muted),
		percent,
	);
}

function audioSourceLabel(node) {
	if (!node) return "Unknown input";
	return node.nickname || node.description || node.name || "Unknown input";
}

function audioSourceStatus(node, activeNode) {
	if (node === activeNode)
		return node && node.audio && node.audio.muted
			? "Active · Muted"
			: "Active input";
	return node && node.audio && node.audio.muted ? "Muted" : "Available";
}
