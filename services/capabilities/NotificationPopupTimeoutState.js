function createState() {
	return {
		popups: Object.create(null),
		claims: Object.create(null),
	};
}

function addPopup(state, popupId, timeoutMs, now) {
	const timeout = Math.max(0, Number(timeoutMs) || 0);
	state.popups[popupId] = {
		remainingMs: timeout,
		lastUpdatedAt: Number(now),
		active: true,
		expirable: timeout > 0,
	};
}

function removePopup(state, popupId) {
	delete state.popups[popupId];
	for (const ownerId of Object.keys(state.claims))
		delete state.claims[ownerId][popupId];
}

function setActive(state, popupId, active, now) {
	const popup = state.popups[popupId];
	if (!popup)
		return;
	updatePopup(state, popupId, now);
	popup.active = Boolean(active);
	popup.lastUpdatedAt = Number(now);
}

function setHovered(state, ownerId, popupId, hovered, now) {
	const popup = state.popups[popupId];
	if (!popup || !ownerId)
		return;
	updatePopup(state, popupId, now);
	if (hovered) {
		if (!state.claims[ownerId])
			state.claims[ownerId] = Object.create(null);
		state.claims[ownerId][popupId] = true;
	} else if (state.claims[ownerId]) {
		delete state.claims[ownerId][popupId];
		if (Object.keys(state.claims[ownerId]).length === 0)
			delete state.claims[ownerId];
	}
	popup.lastUpdatedAt = Number(now);
}

function releaseOwner(state, ownerId, now) {
	const claims = state.claims[ownerId];
	if (!claims)
		return;
	for (const popupId of Object.keys(claims))
		updatePopup(state, popupId, now);
	delete state.claims[ownerId];
	for (const popupId of Object.keys(claims)) {
		if (state.popups[popupId])
			state.popups[popupId].lastUpdatedAt = Number(now);
	}
}

function isHovered(state, popupId) {
	return Object.values(state.claims).some(claims => claims[popupId] === true);
}

function updatePopup(state, popupId, now) {
	const popup = state.popups[popupId];
	if (!popup)
		return;
	const current = Number(now);
	if (popup.expirable && popup.active && !isHovered(state, popupId))
		popup.remainingMs = Math.max(0, popup.remainingMs - Math.max(0, current - popup.lastUpdatedAt));
	popup.lastUpdatedAt = current;
}

function tick(state, now) {
	const expired = [];
	for (const popupId of Object.keys(state.popups)) {
		updatePopup(state, popupId, now);
		const popup = state.popups[popupId];
		if (popup.expirable && popup.active && popup.remainingMs <= 0) {
			expired.push(Number(popupId));
			removePopup(state, popupId);
		}
	}
	return expired;
}

function remaining(state, popupId, now) {
	updatePopup(state, popupId, now);
	return state.popups[popupId] ? state.popups[popupId].remainingMs : 0;
}

if (typeof module !== "undefined") {
	module.exports = {
		addPopup,
		createState,
		isHovered,
		releaseOwner,
		remaining,
		removePopup,
		setActive,
		setHovered,
		tick,
	};
}
