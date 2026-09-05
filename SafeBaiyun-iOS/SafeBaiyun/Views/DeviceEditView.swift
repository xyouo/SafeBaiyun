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

    init(device: Device?, viewModel: DeviceViewModel, wrapsNavigation: Bool = true, forceNew: Bool = false) {
        self.device = device
        self.viewModel = viewModel
        self.wrapsNavigation = wrapsNavigation
        self.forceNew = forceNew
        _name = State(initialValue: device?.name ?? "")
        _mac = State(initialValue: device?.mac ?? "")
        _key = State(initialValue: device?.key ?? "")
        _bluetoothName = State(initialValue: device?.bluetoothName ?? "")
    }

    private var isNew: Bool { forceNew || device == nil }
    private var canSave: Bool {
        ByteUtil.macToBytes(mac).count == 6
            && ByteUtil.hexToBytes(key).count > 0
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
                VariableTextField(label: "address", placeholder: "门禁地址", text: $name)
                VariableTextField(label: "macNum", placeholder: "12:34:56:78:9A:BC", text: $mac)
                VariableTextField(label: "productKey", placeholder: "1234567890ABCDEF", text: $key)
                VariableTextField(label: "bluetoothName", placeholder: "BY456789ABC", text: $bluetoothName)
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
        dismiss()
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

private struct VariableTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )
            TextField(placeholder, text: $text)
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .multilineTextAlignment(.trailing)
        }
    }
}
