import Foundation
import Combine

class DeviceViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var showManageSheet = false
    @Published var bluetoothStatus = ""
    @Published var isUnlocking = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadDevices()
        BluetoothService.shared.$statusMessage
            .receive(on: RunLoop.main)
            .assign(to: &$bluetoothStatus)
        BluetoothService.shared.$isUnlocking
            .receive(on: RunLoop.main)
            .assign(to: &$isUnlocking)
    }

    func loadDevices() {
        devices = DataService.shared.readDevices()
    }

    func moveUp(_ id: String) {
        DataService.shared.moveDeviceUp(id)
        loadDevices()
    }

    func moveDown(_ id: String) {
        DataService.shared.moveDeviceDown(id)
        loadDevices()
    }

    func move(from source: IndexSet, to destination: Int) {
        DataService.shared.moveDevices(from: source, to: destination)
        loadDevices()
    }

    func deleteDevice(_ id: String) {
        DataService.shared.deleteDevice(id)
        loadDevices()
    }

    func saveDevice(_ device: Device, isNew: Bool) {
        if isNew {
            DataService.shared.addDevice(device)
        } else {
            DataService.shared.updateDevice(device)
        }
        loadDevices()
    }

    func generateUniqueName() -> String {
        DataService.shared.generateUniqueName()
    }

    func unlock(_ device: Device) {
        guard !isUnlocking else { return }
        BluetoothService.shared.unlock(device: device)
    }
}
