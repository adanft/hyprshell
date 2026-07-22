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
