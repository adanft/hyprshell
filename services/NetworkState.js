function parseNmcliDeviceInfo(output) {
	var info = {
		connectionName: "",
		activeUuid: "",
		macAddress: "",
		ipv4Address: "",
		ipv4Gateway: "",
		ipv4Dns: [],
		ipv6Address: "",
		ipv6Gateway: "",
		ipv6Dns: [],
	};

	String(output || "")
		.split(/\r?\n/)
		.forEach((line) => {
			var separator = line.indexOf(":");
			if (separator < 0) return;
			var key = line.slice(0, separator).replace(/\[\d+\]$/, "");
			var value = line.slice(separator + 1).trim();
			if (!value || value === "--") return;
			if (key === "GENERAL.CONNECTION") info.connectionName = value;
			else if (key === "GENERAL.CON-UUID") info.activeUuid = value;
			else if (key === "GENERAL.HWADDR") info.macAddress = value;
			else if (key === "IP4.ADDRESS" && !info.ipv4Address)
				info.ipv4Address = value;
			else if (key === "IP4.GATEWAY") info.ipv4Gateway = value;
			else if (key === "IP4.DNS") info.ipv4Dns.push(value);
			else if (key === "IP6.ADDRESS" && !info.ipv6Address)
				info.ipv6Address = value;
			else if (key === "IP6.GATEWAY") info.ipv6Gateway = value;
			else if (key === "IP6.DNS") info.ipv6Dns.push(value);
		});

	return info;
}

function validConnectionUuid(value) {
	return typeof value === "string" && /^[0-9a-fA-F-]{8,64}$/.test(value);
}

function ethernetProfileAction(activeUuid, profileUuid, busy) {
	if (busy || !validConnectionUuid(profileUuid)) return null;
	return activeUuid === profileUuid ? "disable" : "enable";
}
