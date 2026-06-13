import SwiftUI

private enum DeviceEditorSheet: Identifiable {
    case add
    case edit(Device)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let device):
            return "edit-\(device.id)"
        }
    }
}

struct DeviceManageView: View {
    @ObservedObject var viewModel: DeviceViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var activeSheet: DeviceEditorSheet?

    var body: some View {
        NavigationView {
            List {
                if viewModel.devices.isEmpty {
                    Text("暂无设备，点右上角添加")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ForEach(viewModel.devices) { device in
                        Button {
                            guard activeSheet == nil else { return }
                            activeSheet = .edit(device)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.headline)
                                Text("macNum: \(device.mac)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("productKey: \(device.key)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Text("cachedPeripheral: \(cachedPeripheralText(for: device))")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设备管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        guard activeSheet == nil else { return }
                        activeSheet = .add
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $activeSheet, onDismiss: editorDidDismiss) { sheet in
                switch sheet {
                case .add:
                    DeviceEditView(device: nil, viewModel: viewModel)
                case .edit(let device):
                    DeviceEditView(device: device, viewModel: viewModel)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func delete(_ indexSet: IndexSet) {
        for idx in indexSet {
            viewModel.deleteDevice(viewModel.devices[idx].id)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        viewModel.move(from: source, to: destination)
    }

    private func cachedPeripheralText(for device: Device) -> String {
        DataService.shared.cachedPeripheralId(for: device.id)?.uuidString ?? "-"
    }

    private func editorDidDismiss() {
        activeSheet = nil
        viewModel.loadDevices()
    }
}
