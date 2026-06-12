import SwiftUI

struct DeviceEditView: View {
    let device: Device?
    @ObservedObject var viewModel: DeviceViewModel
    var wrapsNavigation = true
    @Environment(\.presentationMode) private var presentationMode

    @State private var name: String
    @State private var mac: String
    @State private var key: String

    init(device: Device?, viewModel: DeviceViewModel, wrapsNavigation: Bool = true) {
        self.device = device
        self.viewModel = viewModel
        self.wrapsNavigation = wrapsNavigation
        _name = State(initialValue: device?.name ?? "")
        _mac = State(initialValue: device?.mac ?? "")
        _key = State(initialValue: device?.key ?? "")
    }

    private var isNew: Bool { device == nil }
    private var canSave: Bool {
        ByteUtil.macToBytes(mac).count == 6 && ByteUtil.hexToBytes(key).count > 0
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
                TextField("设备名称", text: $name)
                TextField("MAC 地址，如 12:34:56:78:9A:BC", text: $mac)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                TextField("加密 Key，如 1234567890ABCDEF", text: $key)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(isNew ? "添加设备" : "编辑设备")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") { presentationMode.wrappedValue.dismiss() }
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
        presentationMode.wrappedValue.dismiss()
    }
}
