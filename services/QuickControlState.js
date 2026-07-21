function clampPercent(value) {
    var numeric = Number(value);
    if (!Number.isFinite(numeric))
        return null;
    return Math.max(0, Math.min(100, Math.round(numeric)));
}

function validBrightnessDevicePath(value) {
    return typeof value === "string"
        && value.length <= 4096
        && /^\/sys\/class\/backlight\/[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(value);
}

function parseUnsignedInteger(text, allowZero) {
    if (typeof text !== "string")
        return null;
    var trimmed = text.trim();
    var pattern = allowZero ? /^(0|[1-9][0-9]*)$/ : /^[1-9][0-9]*$/;
    if (!pattern.test(trimmed))
        return null;
    var value = Number(trimmed);
    return Number.isSafeInteger(value) ? value : null;
}

function normalizedReadback(currentText, maximumText) {
    var current = parseUnsignedInteger(currentText, true);
    var maximum = parseUnsignedInteger(maximumText, false);
    if (current === null || maximum === null || current > maximum)
        return null;
    return {
        rawCurrent: current,
        rawMaximum: maximum,
        percent: clampPercent(current * 100 / maximum)
    };
}

function rawForPercent(percent, maximum) {
    var normalized = clampPercent(percent);
    if (normalized === null || !Number.isSafeInteger(maximum) || maximum <= 0)
        return null;
    return Math.max(0, Math.min(maximum, Math.round(normalized * maximum / 100)));
}

function unavailableCapability(errorText) {
    return {
        availability: "unavailable",
        authoritativePercent: null,
        draftPercent: null,
        lastKnownPercent: null,
        activeRequestId: null,
        errorCode: "authority_unavailable",
        errorText: errorText || null
    };
}

function syncConfirmed(capability, percent) {
    var normalized = clampPercent(percent);
    if (normalized === null)
        return { state: unavailableCapability("Unavailable"), effect: null };
    var next = Object.assign({}, capability, {
        availability: "ready",
        authoritativePercent: normalized,
        lastKnownPercent: normalized,
        errorCode: null,
        errorText: null
    });
    if (capability.availability !== "interacting" && capability.availability !== "pending_confirmation")
        next.draftPercent = null;
    return { state: next, effect: null };
}

function beginInteraction(capability, percent) {
    var normalized = clampPercent(percent);
    if (normalized === null)
        return { state: capability, effect: null };
    return {
        state: Object.assign({}, capability, {
            availability: "interacting",
            draftPercent: normalized,
            errorCode: null,
            errorText: null
        }),
        effect: null
    };
}

function completeInteraction(capability, requestId) {
    if (capability.availability !== "interacting"
            || capability.draftPercent === null
            || !Number.isSafeInteger(requestId)
            || requestId < 1)
        return { state: capability, effect: null };
    var percent = capability.draftPercent;
    return {
        state: Object.assign({}, capability, {
            availability: "pending_confirmation",
            activeRequestId: requestId
        }),
        effect: { type: "request", percent: percent, requestId: requestId }
    };
}

function confirmRequest(capability, requestId, percent) {
    if (capability.activeRequestId !== requestId)
        return { state: capability, accepted: false };
    var synced = syncConfirmed(capability, percent).state;
    synced.activeRequestId = null;
    synced.draftPercent = null;
    return { state: synced, accepted: true };
}

function failRequest(capability, requestId, errorCode, errorText) {
    if (capability.activeRequestId !== requestId)
        return capability;
    var known = capability.lastKnownPercent;
    return Object.assign({}, capability, {
        availability: known === null ? "unavailable" : "failed",
        authoritativePercent: known,
        draftPercent: null,
        activeRequestId: null,
        errorCode: errorCode,
        errorText: errorText || "Adjustment failed"
    });
}
