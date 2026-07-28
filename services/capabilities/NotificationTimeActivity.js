function shouldUpdateNotificationTime(state) {
	return Boolean(
		state && (state.centerOpen || state.visiblePopup || state.queuedPopup),
	);
}

module.exports = {
	shouldUpdateNotificationTime,
};
