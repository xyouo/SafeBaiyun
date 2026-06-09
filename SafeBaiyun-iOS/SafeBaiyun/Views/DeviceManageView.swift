import SwiftUI

struct DeviceManageView: View {
    @ObservedObject var viewModel: DeviceViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var showAdd = false

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
                        NavigationLink(destination: DeviceEditView(device: device, viewModel: viewModel, wrapsNavigation: false)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.headline)
                                Text("MAC: \(device.mac)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Key: \(device.key)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                        }
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
                    Button(action: { showAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd, onDismiss: viewModel.loadDevices) {
                DeviceEditView(device: nil, viewModel: viewModel)
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
}
