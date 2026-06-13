import SwiftUI

struct DeviceEditView: View {
    let device: Device?
    @ObservedObject var viewModel: DeviceViewModel
    var wrapsNavigation = true
    private let forceNew: Bool
    @Environment(\.presentationMode) private var presentationMode

    @State private var name: String
    @State private var mac: String
    @State private var key: String
    @State private var bluetoothName: String
    @State private var cachedPeripheralId: String

    init(device: Device?, viewModel: DeviceViewModel, wrapsNavigation: Bool = true, forceNew: Bool = false) {
        self.device = device
        self.viewModel = viewModel
        self.wrapsNavigation = wrapsNavigation
        self.forceNew = forceNew
        _name = State(initialValue: device?.name ?? "")
        _mac = State(initialValue: device?.mac ?? "")
        _key = State(initialValue: device?.key ?? "")
        _bluetoothName = State(initialValue: device?.bluetoothName ?? "")
        let cachedId = device.flatMap { DataService.shared.cachedPeripheralId(for: $0.id)?.uuidString } ?? ""
        _cachedPeripheralId = State(initialValue: cachedId)
    }

    private var isNew: Bool { forceNew || device == nil }
    private var canSave: Bool {
        ByteUtil.macToBytes(mac).count == 6
            && ByteUtil.hexToBytes(key).count > 0
            && isCachedPeripheralValid
    }
    private var isCachedPeripheralValid: Bool {
        let trimmed = cachedPeripheralId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || UUID(uuidString: trimmed) != nil
    }

    var body: some View {
        Group {
            if wrapsNavigation {
                NavigationView {
                    content
                }
                .navigationViewStyle(StackNavigationViewStyle())
            } else {
                content
            }
        }
    }

    private var content: some View {
        List {
            Section(header: Text("设备信息")) {
                TextField("address", text: $name)
                TextField("macNum，如 12:34:56:78:9A:BC", text: $mac)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                TextField("productKey，如 1234567890ABCDEF", text: $key)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                TextField("bluetoothName，如 BY1A9EDA38F", text: $bluetoothName)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
            }
            Section(header: Text("缓存外设")) {
                TextField("iOS 外设 UUID", text: $cachedPeripheralId)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                if !isCachedPeripheralValid {
                    Text("UUID 格式不正确")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(isNew ? "添加设备" : "编辑设备")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isNew ? "添加" : "保存") { save() }
                    .disabled(!canSave)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? viewModel.generateUniqueName() : trimmedName
        let normalizedMac = ByteUtil.normalizeMac(mac)
        let normalizedBluetoothName = ByteUtil.normalizeBluetoothName(bluetoothName)
        let finalBluetoothName = normalizedBluetoothName.isEmpty ? ByteUtil.derivedBluetoothName(fromMac: normalizedMac) : normalizedBluetoothName
        let newDevice = Device(
            id: device?.id ?? UUID().uuidString,
            name: finalName,
            mac: normalizedMac,
            key: key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            bluetoothName: finalBluetoothName
        )
        viewModel.saveDevice(newDevice, isNew: isNew)
        saveCachedPeripheral(for: newDevice)
        dismiss()
    }

    private func saveCachedPeripheral(for device: Device) {
        let trimmedCache = cachedPeripheralId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCache.isEmpty {
            DataService.shared.clearCachedPeripheral(for: device.id)
        } else {
            _ = DataService.shared.saveCachedPeripheralIdString(trimmedCache, for: device.id)
        }
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}
