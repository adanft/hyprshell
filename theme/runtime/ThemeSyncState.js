function effectiveSignature(theme) {
	return JSON.stringify(theme);
}

function createHyprlandState() {
	return {
		busy: false,
		active: null,
		lastApplied: "",
		pending: null,
		automaticRetries: 0,
	};
}

function requestHyprland(state, theme, force) {
	var request = {
		theme: theme,
		force: Boolean(force),
		signature: effectiveSignature(theme),
	};
	if (
		!state.busy &&
		!request.force &&
		request.signature === state.lastApplied
	)
		return { action: "skip" };

	if (
		state.busy &&
		state.active &&
		request.signature === state.active.signature
	) {
		if (request.force) {
			state.pending = state.pending || {
				theme: request.theme,
				signature: request.signature,
				force: false,
			};
			state.pending.theme = request.theme;
			state.pending.signature = request.signature;
			state.pending.force = true;
		}
		return { action: "queued" };
	}

	state.pending = request;
	if (state.busy) return { action: "queued" };

	state.busy = true;
	state.active = request;
	state.automaticRetries = 0;
	return { action: "start", request };
}

function finishHyprland(state, signature, succeeded) {
	state.busy = false;
	if (succeeded) state.lastApplied = signature;

	var next = state.pending;
	if (
		!succeeded &&
		state.automaticRetries === 0 &&
		(!next || next.signature === signature)
	) {
		state.automaticRetries = 1;
		state.busy = true;
		return { action: "start", request: state.active };
	}

	if (
		!succeeded &&
		state.automaticRetries > 0 &&
		next &&
		next.signature === signature &&
		!next.force
	)
		next = null;
	state.pending = null;
	if (!next || (!next.force && next.signature === state.lastApplied)) {
		state.active = null;
		return { action: "idle" };
	}

	state.busy = true;
	state.active = next;
	state.automaticRetries = 0;
	return { action: "start", request: next };
}

function shouldSyncExternal(appSettingsReady, sourceReady) {
	return Boolean(appSettingsReady && sourceReady);
}

function ghosttyNeedsReload(bytesChanged, force) {
	return Boolean(bytesChanged || force);
}

function createGhosttyState() {
	return { busy: false, retries: 0, pending: null };
}

function requestGhostty(state, force) {
	if (state.busy) {
		state.pending = state.pending || { force: false };
		state.pending.force = state.pending.force || Boolean(force);
		return { action: "queued" };
	}
	state.busy = true;
	state.retries = 0;
	return { action: "start", force: Boolean(force) };
}

function finishGhostty(state, succeeded) {
	state.busy = false;
	if (!succeeded && state.retries === 0) {
		state.retries = 1;
		state.busy = true;
		return { action: "start", force: false };
	}
	var next = state.pending;
	state.pending = null;
	if (!next) {
		state.retries = 0;
		return { action: "idle" };
	}
	state.busy = true;
	state.retries = 0;
	return { action: "start", force: next.force };
}
