import SwiftUI

struct DeviceEditView: View {
    let device: Device?
    @ObservedObject var viewModel: DeviceViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var name = ""
    @State private var mac = ""
    @State private var key = ""

    private var isNew: Bool { device == nil }
    private var canSave: Bool {
        ByteUtil.macToBytes(mac).count == 6 && ByteUtil.hexToBytes(key).count > 0
    }

    var body: some View {
        NavigationView {
            Form {
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
            .navigationTitle(isNew ? "添加设备" : "编辑设备")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isNew ? "添加" : "保存") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let d = device {
                    name = d.name
                    mac = d.mac
                    key = d.key
                }
            }
        }
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
