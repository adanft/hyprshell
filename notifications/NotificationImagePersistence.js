const MAX_SAVE_RETRIES = 1;

function createState() {
	return {
		pending: Object.create(null),
		owned: Object.create(null),
		removedPending: Object.create(null),
		retries: Object.create(null),
	};
}

function isLiveImage(source) {
	return String(source || "").startsWith("image://qsimage/");
}

function historyImageSource(source) {
	return isLiveImage(source) ? "" : String(source || "");
}

function canMaterialize(state, entry, ready) {
	return Boolean(
		ready &&
			entry &&
			entry.id &&
			isLiveImage(entry.image) &&
			!state.pending[entry.id] &&
			!state.owned[entry.id],
	);
}

function begin(state, entryId, path) {
	state.pending[entryId] = path;
	return path;
}

function complete(state, entryId, path, saved, entryStillExists, active) {
	const pendingPath = state.pending[entryId];
	const removedPendingPath = state.removedPending[entryId];
	const ownsPath = pendingPath === path || removedPendingPath === path;
	delete state.pending[entryId];
	delete state.removedPending[entryId];

	if (saved && ownsPath && entryStillExists && active) {
		delete state.retries[entryId];
		state.owned[entryId] = path;
		return { persisted: true, orphan: "", retry: false };
	}

	const retry =
		!saved &&
		ownsPath &&
		entryStillExists &&
		active &&
		(state.retries[entryId] || 0) < MAX_SAVE_RETRIES;
	if (retry) state.retries[entryId] = (state.retries[entryId] || 0) + 1;
	else delete state.retries[entryId];
	return {
		persisted: false,
		orphan: saved && ownsPath ? path : "",
		retry: retry,
	};
}

function removeEntry(state, entryId) {
	const path = state.owned[entryId] || "";
	if (state.pending[entryId])
		state.removedPending[entryId] = state.pending[entryId];
	delete state.owned[entryId];
	delete state.pending[entryId];
	delete state.retries[entryId];
	return path;
}

    function notificationImagePath(entry, cacheDirectory) {
        const normalize = value => {
            const number = Number(value);
            return Number.isFinite(number) && number >= 0 ? Math.floor(number) : 0;
        };
        const timestamp = entry && (entry.timestamp || entry.createdAt) || 0;
        const nativeId = entry && entry.notification && entry.notification.id || 0;
        return `${cacheDirectory}/notif_${normalize(timestamp)}_${normalize(nativeId)}.png`;
    }

function isOwnedPath(path, cacheDirectory) {
	const prefix = `${cacheDirectory}/notif_`;
	return (
		typeof path === "string" &&
		path.startsWith(prefix) &&
		/^notif_[A-Za-z0-9._-]+_[A-Za-z0-9._-]+\.png$/.test(path.slice(cacheDirectory.length + 1))
	);
}

function orphanPaths(paths, history, cacheDirectory) {
	const referenced = new Set(
		(history || [])
			.filter((entry) => entry && entry.ownedImage === true)
			.map((entry) => entry.persistedImagePath)
			.filter((path) => isOwnedPath(path, cacheDirectory)),
	);
	return (paths || []).filter(
		(path) => isOwnedPath(path, cacheDirectory) && !referenced.has(path),
	);
}

if (typeof module !== "undefined") {
	module.exports = {
		begin,
		canMaterialize,
		complete,
		createState,
		historyImageSource,
		isLiveImage,
		notificationImagePath,
		isOwnedPath,
		orphanPaths,
		removeEntry,
	};
}
