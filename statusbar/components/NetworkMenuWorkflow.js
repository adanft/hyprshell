function initialState() {
	return {
		pendingNetwork: null,
		suppressedPasswordNetwork: null,
		scannerDevice: null,
		scannerOwnedDevice: null,
		wifiActivationPending: false,
		wifiActivationRequested: false,
		wifiActivationGeneration: 0,
		connectionError: "",
		expandedNetworkSection: "",
		detailsSubscribed: false,
	};
}

function canSubmitPassword(pendingNetwork, password) {
	return Boolean(
		pendingNetwork &&
			password !== null &&
			password !== undefined &&
			String(password).length > 0 &&
			!pendingNetwork.stateChanging,
	);
}

function effect(effects, type, values) {
	effects.push(Object.assign({ type: type }, values || {}));
}

function releaseScanner(state, effects) {
	if (!state.scannerOwnedDevice) return;
	effect(effects, "setScannerEnabled", {
		device: state.scannerOwnedDevice,
		enabled: false,
		claimOwnership: false,
	});
	state.scannerOwnedDevice = null;
}

function eligible(event) {
	return Boolean(
		event.menuOpen &&
			event.expandedNetworkSection === "wifi" &&
			event.wifiEnabled &&
			event.wifiHardwareEnabled &&
			event.wifiDevice,
	);
}

function syncScanner(state, event, effects) {
	effect(effects, "stopScannerDelay");
	var device = event.wifiDevice || null;
	if (state.scannerOwnedDevice && state.scannerOwnedDevice !== device)
		releaseScanner(state, effects);
	state.scannerDevice = device;
	if (!eligible(event)) {
		releaseScanner(state, effects);
		if (!state.wifiActivationRequested) {
			state.wifiActivationPending = false;
			effect(effects, "stopActivationSettle");
		}
		return;
	}
	if (event.forceRestart) {
		releaseScanner(state, effects);
		effect(effects, "startScannerDelay", {
			device: device,
			generation: state.wifiActivationGeneration,
		});
	} else if (state.scannerOwnedDevice !== device && !device.scannerEnabled) {
		effect(effects, "setScannerEnabled", {
			device: device,
			enabled: true,
			claimOwnership: true,
		});
		state.scannerOwnedDevice = device;
	}
}

function cancelPassword(state) {
	if (state.pendingNetwork && state.pendingNetwork.stateChanging)
		state.suppressedPasswordNetwork = state.pendingNetwork;
	state.pendingNetwork = null;
	state.connectionError = "";
}

function transition(currentState, event) {
	if (!event || !event.type) return { state: currentState, effects: [] };
	var known = [
		"beginWifiActivation",
		"toggleWifi",
		"syncScanner",
		"scannerDelayElapsed",
		"activationSettleElapsed",
		"menuOpenChanged",
		"wifiEnabledChanged",
		"wifiHardwareEnabledChanged",
		"wifiDeviceChanged",
		"toggleSection",
		"prepareOpen",
		"requestClose",
		"completeClose",
		"connectRequested",
		"submitPassword",
		"cancelPassword",
		"forgetRequested",
		"wifiConnectedChanged",
		"wifiConnectionFailed",
		"pendingConnectedChanged",
		"pendingConnectionFailed",
		"ethernetConnectionFailed",
		"destroy",
	];
	if (known.indexOf(event.type) < 0)
		return { state: currentState, effects: [] };
	var base = currentState || initialState();
	if (
		event.type === "activationSettleElapsed" &&
		event.generation !== base.wifiActivationGeneration
	)
		return { state: base, effects: [] };
	if (
		event.type === "scannerDelayElapsed" &&
		(event.scheduledDevice !== event.wifiDevice ||
			event.scheduledDevice !== base.scannerDevice ||
			event.scheduledGeneration !== base.wifiActivationGeneration ||
			!eligible(event))
	)
		return { state: base, effects: [] };
	if (event.type === "destroy" && base._destroyed)
		return { state: base, effects: [] };

	var state = Object.assign({}, initialState(), base);
	var effects = [];
	switch (event.type) {
		case "beginWifiActivation":
			state.wifiActivationGeneration += 1;
			state.wifiActivationRequested = state.wifiActivationPending = true;
			effect(effects, "startActivationSettle", {
				generation: state.wifiActivationGeneration,
			});
			break;
		case "toggleWifi":
			if (!event.wifiEnabled) {
				state.wifiActivationGeneration += 1;
				state.wifiActivationRequested = state.wifiActivationPending = true;
				effect(effects, "startActivationSettle", {
					generation: state.wifiActivationGeneration,
				});
				effect(effects, "setWifiEnabled", { enabled: true });
			} else {
				state.wifiActivationGeneration += 1;
				state.wifiActivationRequested = state.wifiActivationPending = false;
				effect(effects, "stopScannerDelay");
				effect(effects, "stopActivationSettle");
				releaseScanner(state, effects);
				effect(effects, "setWifiEnabled", { enabled: false });
			}
			break;
		case "syncScanner":
			syncScanner(state, event, effects);
			break;
		case "scannerDelayElapsed":
			effect(effects, "setScannerEnabled", {
				device: event.wifiDevice,
				enabled: true,
				claimOwnership: true,
			});
			state.scannerOwnedDevice = event.wifiDevice;
			if (state.wifiActivationPending)
				effect(effects, "startActivationSettle", {
					generation: state.wifiActivationGeneration,
				});
			break;
		case "activationSettleElapsed":
			state.wifiActivationRequested = state.wifiActivationPending = false;
			break;
		case "menuOpenChanged":
			if (!event.menuOpen) {
				state.wifiActivationGeneration += 1;
				state.wifiActivationRequested = state.wifiActivationPending = false;
			}
			syncScanner(state, event, effects);
			if (event.menuOpen && !state.detailsSubscribed) {
				effect(effects, "enableNetworkDetails");
				state.detailsSubscribed = true;
			} else if (!event.menuOpen && state.detailsSubscribed) {
				effect(effects, "disableNetworkDetails");
				state.detailsSubscribed = false;
			}
			break;
		case "wifiEnabledChanged":
			if (state.wifiActivationRequested && !event.wifiEnabled) break;
			if (event.wifiEnabled && !state.wifiActivationRequested) {
				state.wifiActivationGeneration += 1;
				state.wifiActivationRequested = state.wifiActivationPending = true;
				effect(effects, "startActivationSettle", {
					generation: state.wifiActivationGeneration,
				});
			} else if (!event.wifiEnabled) {
				state.wifiActivationGeneration += 1;
				state.wifiActivationRequested = state.wifiActivationPending = false;
				cancelPassword(state);
				state.suppressedPasswordNetwork = null;
				effect(effects, "stopActivationSettle");
			}
			syncScanner(state, event, effects);
			break;
		case "wifiHardwareEnabledChanged":
		case "wifiDeviceChanged":
			if (event.type === "wifiDeviceChanged" || !event.wifiHardwareEnabled) {
				state.wifiActivationGeneration += 1;
				state.wifiActivationRequested = state.wifiActivationPending = false;
				cancelPassword(state);
				state.suppressedPasswordNetwork = null;
				effect(effects, "stopActivationSettle");
			}
			syncScanner(
				state,
				Object.assign({}, event, {
					forceRestart:
						event.type === "wifiDeviceChanged"
							? event.wifiEnabled
							: event.wifiHardwareEnabled,
				}),
				effects,
			);
			break;
		case "toggleSection":
			state.expandedNetworkSection =
				state.expandedNetworkSection === event.section ? "" : event.section;
			state.connectionError = "";
			state.pendingNetwork = null;
			syncScanner(
				state,
				Object.assign({}, event, {
					expandedNetworkSection: state.expandedNetworkSection,
					forceRestart: state.expandedNetworkSection === "wifi",
				}),
				effects,
			);
			break;
		case "prepareOpen":
			state.connectionError = "";
			break;
		case "requestClose":
			cancelPassword(state);
			break;
		case "completeClose":
			state.expandedNetworkSection = "";
			state.pendingNetwork = null;
			state.connectionError = "";
			break;
		case "connectRequested":
			state.connectionError = "";
			state.suppressedPasswordNetwork = null;
			if (!event.network) break;
			if (event.network.connected)
				effect(effects, "disconnectNetwork", { network: event.network });
			else if (
				event.network.known ||
				event.network.security === event.openSecurityValue
			)
				effect(effects, "connectNetwork", { network: event.network });
			else state.pendingNetwork = event.network;
			break;
		case "submitPassword":
			if (canSubmitPassword(state.pendingNetwork, event.password)) {
				state.connectionError = "";
				effect(effects, "connectNetworkWithPsk", {
					network: state.pendingNetwork,
					password: event.password,
				});
			}
			break;
		case "cancelPassword":
			cancelPassword(state);
			break;
		case "forgetRequested":
			if (
				event.network &&
				event.network.known &&
				!event.network.connected &&
				!event.network.stateChanging
			) {
				if (state.pendingNetwork === event.network) state.pendingNetwork = null;
				state.connectionError = "";
				effect(effects, "forgetNetwork", { network: event.network });
			}
			break;
		case "wifiConnectedChanged":
			if (
				event.network &&
				event.network.connected !== false &&
				state.suppressedPasswordNetwork === event.network
			)
				state.suppressedPasswordNetwork = null;
			break;
		case "wifiConnectionFailed":
			if (state.pendingNetwork === event.network) break;
			if (state.suppressedPasswordNetwork === event.network)
				state.suppressedPasswordNetwork = null;
			else {
				state.connectionError = event.errorText || "";
				if (
					event.noSecretsValue !== undefined &&
					event.reason === event.noSecretsValue
				)
					state.pendingNetwork = event.network;
			}
			break;
		case "pendingConnectedChanged":
			if (state.pendingNetwork && state.pendingNetwork.connected)
				cancelPassword(state);
			break;
		case "pendingConnectionFailed":
			if (state.pendingNetwork) state.connectionError = event.errorText || "";
			break;
		case "ethernetConnectionFailed":
			state.connectionError = event.errorText || "";
			break;
		case "destroy":
			state.wifiActivationGeneration += 1;
			state.wifiActivationRequested = state.wifiActivationPending = false;
			effect(effects, "stopScannerDelay");
			effect(effects, "stopActivationSettle");
			releaseScanner(state, effects);
			if (state.detailsSubscribed) effect(effects, "disableNetworkDetails");
			state.scannerDevice = null;
			state.detailsSubscribed = false;
			state._destroyed = true;
			break;
	}
	return { state: state, effects: effects };
}
