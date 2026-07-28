import QtQuick
import Quickshell
import Quickshell.Services.UPower

Scope {
    readonly property var powerProfiles: [PowerProfile.Performance, PowerProfile.Balanced, PowerProfile.PowerSaver]
    readonly property var batteries: UPower.devices.values.filter(device => device && device.isLaptopBattery)
    readonly property var readyBatteries: batteries.filter(device => device.ready)
    readonly property bool batteryAvailable: batteries.length > 0
    readonly property bool batteryCharging: hasBatteryState(UPowerDeviceState.Charging)
    readonly property bool batteryEmpty: hasBatteryState(UPowerDeviceState.Empty)
    readonly property bool batteryFull: readyBatteries.length > 0 && readyBatteries.every(device => device.state === UPowerDeviceState.FullyCharged)
    readonly property bool batteryPendingCharge: hasBatteryState(UPowerDeviceState.PendingCharge)
    readonly property bool batteryPendingDischarge: hasBatteryState(UPowerDeviceState.PendingDischarge)
    readonly property bool batteryUnknown: !batteryAvailable || readyBatteries.length === 0 || readyBatteries.every(device => device.state === UPowerDeviceState.Unknown)
    readonly property bool batteryLow: !batteryUnknown && batteryLevel <= 30
    readonly property bool batteryCritical: !batteryUnknown && batteryLevel <= 15
    readonly property int batteryLevel: computeBatteryLevel()
    readonly property string powerProfile: profileSlug(PowerProfiles.profile)

    function computeBatteryLevel() {
        if (readyBatteries.length === 0)
            return 0
        const capacity = readyBatteries.reduce((sum, device) => sum + device.energyCapacity, 0)
        let level = 0
        if (capacity > 0) {
            const energy = readyBatteries.reduce((sum, device) => sum + device.energy, 0)
            level = Math.round((energy * 100) / capacity)
        } else {
            const percentage = readyBatteries.reduce((sum, device) => sum + normalizePercentage(device.percentage), 0) / readyBatteries.length
            level = Math.round(percentage)
        }
        return Math.max(0, Math.min(100, level))
    }
    function hasBatteryState(state) {
        return readyBatteries.some(device => device.state === state)
    }
    function normalizePercentage(value) {
        const percentage = Number(value) || 0
        return percentage <= 1 ? percentage * 100 : percentage
    }
    function nextPowerProfile() {
        const currentIndex = Math.max(0, powerProfiles.indexOf(PowerProfiles.profile))
        PowerProfiles.profile = powerProfiles[(currentIndex + 1) % powerProfiles.length]
    }
    function profileSlug(profile) {
        switch (profile) {
        case PowerProfile.Performance:
            return "performance"
        case PowerProfile.PowerSaver:
            return "power-saver"
        default:
            return "balanced"
        }
    }
}
