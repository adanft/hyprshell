const MAX_SAVE_RETRIES = 1;

function createState() {
	return {
		pending: Object.create(null),
		owned: Object.create(null),
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

function begin(state, entryId, generation, finalPath, tempPath) {
	const reservation = { generation, finalPath, tempPath };
	state.pending[entryId] = reservation;
	return reservation;
}

function complete(state, entryId, generation, committed, entryStillExists, active) {
	const pending = state.pending[entryId];
	const current = pending && pending.generation === generation;
	if (current) delete state.pending[entryId];

	if (committed && current && entryStillExists && active) {
		delete state.retries[entryId];
		state.owned[entryId] = {
			generation,
			path: pending.finalPath,
		};
		return { persisted: true, retry: false };
	}

	const retry =
		!committed &&
		current &&
		entryStillExists &&
		active &&
		(state.retries[entryId] || 0) < MAX_SAVE_RETRIES;
	if (retry) state.retries[entryId] = (state.retries[entryId] || 0) + 1;
	else delete state.retries[entryId];
	return {
		persisted: false,
		retry: retry,
	};
}

function removeEntry(state, entryId) {
	const owned = state.owned[entryId];
	delete state.owned[entryId];
	delete state.pending[entryId];
	delete state.retries[entryId];
	return owned ? owned.path : "";
}

function notificationImagePath(entry, cacheDirectory, generation) {
	const normalize = (value) => {
		const number = Number(value);
		return Number.isFinite(number) && number >= 0 ? Math.floor(number) : 0;
	};
	const timestamp = (entry && (entry.timestamp || entry.createdAt)) || 0;
	const nativeId =
		(entry && entry.notification && entry.notification.id) || 0;
	return `${cacheDirectory}/notif_${normalize(timestamp)}_${normalize(nativeId)}_${normalize(generation)}.png`;
}

function notificationImageTempPath(finalPath, entryId, generation) {
	const safeEntryId = String(entryId || "entry").replace(/[^A-Za-z0-9._-]/g, "_");
	const slash = finalPath.lastIndexOf("/");
	const directory = slash >= 0 ? finalPath.slice(0, slash + 1) : "";
	const filename = slash >= 0 ? finalPath.slice(slash + 1) : finalPath;
	return `${directory}.${filename}.part-${safeEntryId}-${generation}.png`;
}

function isOwnedPath(path, cacheDirectory) {
	const prefix = `${cacheDirectory}/notif_`;
	return (
		typeof path === "string" &&
		path.startsWith(prefix) &&
			/^notif_[A-Za-z0-9._-]+_[A-Za-z0-9._-]+(?:_[A-Za-z0-9._-]+)?\.png$/.test(
			path.slice(cacheDirectory.length + 1),
		)
	);
}

function isReservedPath(state, path) {
	return Object.values(state.pending).some(
		(reservation) =>
			reservation &&
			(reservation.finalPath === path || reservation.tempPath === path),
	);
}

function isReferencedPath(history, path, cacheDirectory) {
	return (history || []).some(
		(entry) =>
			entry &&
			entry.ownedImage === true &&
			entry.persistedImagePath === path &&
			isOwnedPath(path, cacheDirectory),
	);
}

function canDeleteOrphan(state, history, path, cacheDirectory) {
	return (
		isOwnedPath(path, cacheDirectory) &&
		!isReservedPath(state, path) &&
		!isReferencedPath(history, path, cacheDirectory)
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
		canDeleteOrphan,
		canMaterialize,
		complete,
		createState,
		historyImageSource,
		isLiveImage,
		notificationImagePath,
		notificationImageTempPath,
		isOwnedPath,
		orphanPaths,
		removeEntry,
	};
}
