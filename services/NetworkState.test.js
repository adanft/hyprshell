const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(
	new URL("./NetworkState.js", `file://${__dirname}/`),
	"utf8",
);
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

const parsed = context.parseNmcliDeviceInfo(`GENERAL.CONNECTION:Office LAN
GENERAL.CON-UUID:cb89613f-ca03-39f0-9bce-dca5619093d7
GENERAL.HWADDR:C8:7F:54:5C:6E:A3
IP4.ADDRESS[1]:192.168.1.12/24
IP4.GATEWAY:192.168.1.1
IP4.DNS[1]:192.168.1.100
IP4.DNS[2]:1.1.1.1
IP6.ADDRESS[1]:fe80::1234/64
IP6.GATEWAY:fe80::1
IP6.DNS[1]:fe80::1
`);
assert.equal(parsed.connectionName, "Office LAN");
assert.equal(parsed.activeUuid, "cb89613f-ca03-39f0-9bce-dca5619093d7");
assert.equal(parsed.macAddress, "C8:7F:54:5C:6E:A3");
assert.equal(parsed.ipv4Address, "192.168.1.12/24");
assert.equal(parsed.ipv4Gateway, "192.168.1.1");
assert.deepEqual(Array.from(parsed.ipv4Dns), ["192.168.1.100", "1.1.1.1"]);
assert.equal(parsed.ipv6Address, "fe80::1234/64");
assert.equal(parsed.ipv6Gateway, "fe80::1");
assert.deepEqual(Array.from(parsed.ipv6Dns), ["fe80::1"]);

assert.equal(
	context.validConnectionUuid("cb89613f-ca03-39f0-9bce-dca5619093d7"),
	true,
);
assert.equal(context.validConnectionUuid("uuid; shutdown now"), false);
const profileUuid = "cb89613f-ca03-39f0-9bce-dca5619093d7";
assert.equal(
	context.ethernetProfileAction(profileUuid, profileUuid, false),
	"disable",
);
assert.equal(
	context.ethernetProfileAction(
		"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		profileUuid,
		false,
	),
	"enable",
);
assert.equal(context.ethernetProfileAction("", profileUuid, true), null);

console.log(
	"NetworkState: nmcli parsing, UUID validation, and profile actions passed",
);
