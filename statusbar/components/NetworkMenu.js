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

function shouldStopBluetoothScan(menuOpen, expandedSection, discovering) {
	return Boolean(discovering && (!menuOpen || expandedSection !== "bluetooth"));
}

function bluetoothSummary(available, powered, connectedCount) {
	if (!available) return "Unavailable";
	if (!powered) return "Off";
	var count = Math.max(0, Number(connectedCount) || 0);
	return count > 0 ? count + " connected" : "Enabled";
}

function bluetoothVisibleDevices(devices, discovering) {
	if (!Array.isArray(devices)) return [];
	return devices.filter((device) =>
		Boolean(
			device &&
				(discovering || device.paired || device.connected || device.pairing),
		),
	);
}

function bluetoothEmptyState(available, powered, discovering) {
	if (!available) return "Bluetooth adapter unavailable";
	if (!powered) return "Bluetooth is off";
	if (discovering) return "Searching for nearby devices…";
	return "No paired devices";
}

function microphoneSummary(available, muted, volume) {
	if (!available) return "Unavailable";
	if (muted) return "Muted";
	var value = Math.max(0, Math.min(100, Math.round(Number(volume) || 0)));
	return value + "%";
}

function bluetoothDeviceStatus(device) {
	if (!device) return "Unavailable";
	if (device.pairing) return "Pairing…";
	if (device.connected)
		return device.batteryAvailable
			? "Connected · " + Math.round(device.battery * 100) + "%"
			: "Connected";
	if (device.paired) return "Paired";
	return "Available";
}

function bluetoothDeviceAction(device) {
	if (!device) return "none";
	if (device.pairing) return "cancelPair";
	if (!device.paired) return "pair";
	return device.connected ? "disconnect" : "connect";
}

function bluetoothActionLabel(device) {
	var action = bluetoothDeviceAction(device);
	if (action === "cancelPair") return "Cancel";
	if (action === "pair") return "Pair";
	if (action === "disconnect") return "Disconnect";
	if (action === "connect") return "Connect";
	return "Unavailable";
}

function runBluetoothDeviceAction(device, action) {
	if (!device || bluetoothDeviceAction(device) !== action) return false;
	if (action === "pair") device.pair();
	else if (action === "cancelPair") device.cancelPair();
	else if (action === "connect") device.connect();
	else if (action === "disconnect") device.disconnect();
	else return false;
	return true;
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
