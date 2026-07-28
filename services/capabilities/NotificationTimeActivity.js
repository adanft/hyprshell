function shouldUpdateNotificationTime(state) {
	return Boolean(
		state && (state.centerOpen || state.visiblePopup || state.queuedPopup),
	);
}

if (typeof module !== "undefined") {
	module.exports = {
		shouldUpdateNotificationTime,
	};
}
