function typedStringPayload(output, expectedType) {
	try {
		var response = JSON.parse(String(output || ""));
		if (!response || response.type !== expectedType) return "";

		var value = response.data;
		if (Array.isArray(value)) {
			if (value.length !== 1) return "";
			value = value[0];
		}

		return typeof value === "string" ? value : "";
	} catch (_) {
		return "";
	}
}

function parseUserObjectPath(output) {
	var value = typedStringPayload(output, "o");
	return /^\/org\/freedesktop\/Accounts\/User\d+$/.test(value) ? value : "";
}

function safeLocalFileUrl(path) {
	if (typeof path !== "string" || path.length === 0 || path.length > 4096)
		return "";
	if (path !== path.trim() || path.charAt(0) !== "/") return "";
	if (
		/[\u0000-\u001f\u007f]/.test(path) ||
		/^[A-Za-z][A-Za-z0-9+.-]*:/.test(path)
	)
		return "";

	var segments = path.split("/");
	if (
		segments.some(function (segment) {
			return segment === "..";
		})
	)
		return "";

	return (
		"file://" +
		segments
			.map(function (segment) {
				return encodeURIComponent(segment);
			})
			.join("/")
	);
}

function parseIconFile(output) {
	return safeLocalFileUrl(typedStringPayload(output, "s"));
}
