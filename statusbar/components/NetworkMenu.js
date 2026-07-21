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

function networkSignalText(network) {
	if (!network) return "0%";
	if (network.stateChanging) return "…";
	return Math.round((Number(network.signalStrength) || 0) * 100) + "%";
}

function wifiSummary(network, wifiHardwareEnabled) {
	if (network) return network.name + " · " + networkSignalText(network);
	return wifiHardwareEnabled ? "Not connected" : "Disabled by hardware";
}
