import Foundation

class DataService {
    static let shared = DataService()

    private let defaults = UserDefaults.standard
    private let devicesKey = "devices"
    private let cachedPeripheralPrefix = "cachedPeripheral.v2."

    func readDevices() -> [Device] {
        guard let data = defaults.data(forKey: devicesKey) else { return [] }
        return (try? JSONDecoder().decode([Device].self, from: data)) ?? []
    }

    func saveDevices(_ devices: [Device]) {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        defaults.set(data, forKey: devicesKey)
    }

    func addDevice(_ device: Device) {
        var devices = readDevices()
        devices.append(device)
        saveDevices(devices)
    }

    func updateDevice(_ device: Device) {
        var devices = readDevices()
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx] = device
            saveDevices(devices)
        }
    }

    func deleteDevice(_ id: String) {
        saveDevices(readDevices().filter { $0.id != id })
        defaults.removeObject(forKey: cachedPeripheralPrefix + id)
    }

    func moveDeviceUp(_ id: String) {
        var devices = readDevices()
        guard let idx = devices.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        devices.swapAt(idx, idx - 1)
        saveDevices(devices)
    }

    func moveDeviceDown(_ id: String) {
        var devices = readDevices()
        guard let idx = devices.firstIndex(where: { $0.id == id }), idx < devices.count - 1 else { return }
        devices.swapAt(idx, idx + 1)
        saveDevices(devices)
    }

    func moveDevices(from source: IndexSet, to destination: Int) {
        var devices = readDevices()
        let moving = source.sorted().map { devices[$0] }
        for index in source.sorted(by: >) {
            devices.remove(at: index)
        }
        let adjustment = source.filter { $0 < destination }.count
        let target = min(max(0, destination - adjustment), devices.count)
        devices.insert(contentsOf: moving, at: target)
        saveDevices(devices)
    }

    func generateUniqueName(base: String = "门禁") -> String {
        let existing = readDevices()
        if !existing.contains(where: { $0.name == base }) { return base }
        var i = 2
        while existing.contains(where: { $0.name == "\(base)\(i)" }) { i += 1 }
        return "\(base)\(i)"
    }

    func cachedPeripheralId(for deviceId: String) -> UUID? {
        guard let value = defaults.string(forKey: cachedPeripheralPrefix + deviceId) else { return nil }
        return UUID(uuidString: value)
    }

    func saveCachedPeripheralId(_ peripheralId: UUID, for deviceId: String) {
        defaults.set(peripheralId.uuidString, forKey: cachedPeripheralPrefix + deviceId)
    }
}
