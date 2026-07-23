function safeText(fileView, label, reloadFile) {
	try {
		if (!fileView) return null;
		if (reloadFile) fileView.reload();
		return String(fileView.text() || "");
	} catch (error) {
		console.warn(`Failed to read ${label}: ${error}`);
		return null;
	}
}
