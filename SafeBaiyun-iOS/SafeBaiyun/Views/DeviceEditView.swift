import SwiftUI

struct DeviceEditView: View {
    let device: Device?
    @ObservedObject var viewModel: DeviceViewModel
    var wrapsNavigation = true
    @Environment(\.presentationMode) private var presentationMode

    @State private var name: String
    @State private var mac: String
    @State private var key: String
    @State private var cachedPeripheralId: String

    init(device: Device?, viewModel: DeviceViewModel, wrapsNavigation: Bool = true) {
        self.device = device
        self.viewModel = viewModel
        self.wrapsNavigation = wrapsNavigation
        _name = State(initialValue: device?.name ?? "")
        _mac = State(initialValue: device?.mac ?? "")
        _key = State(initialValue: device?.key ?? "")
        let cachedId = device.flatMap { DataService.shared.cachedPeripheralId(for: $0.id)?.uuidString } ?? ""
        _cachedPeripheralId = State(initialValue: cachedId)
    }

    private var isNew: Bool { device == nil }
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
                TextField("macNum", text: $mac)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                TextField("productKey", text: $key)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
            }
            Section(header: Text("缓存外设")) {
                TextField("iOS 外设 UUID，可不填", text: $cachedPeripheralId)
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
        let newDevice = Device(
            id: device?.id ?? UUID().uuidString,
            name: finalName,
            mac: ByteUtil.normalizeMac(mac),
            key: key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
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
