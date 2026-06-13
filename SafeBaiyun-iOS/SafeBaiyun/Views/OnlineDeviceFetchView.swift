import SwiftUI

struct OnlineDeviceFetchView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var phone = ""
    @State private var idCard = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var devices: [RemoteDoorDevice] = []

    let onPick: (Device) -> Void

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("账号信息")) {
                    TextField("手机号", text: $phone)
                        .keyboardType(.numberPad)
                    SecureField("身份证号", text: $idCard)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                    Button {
                        Task { await fetch() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                            }
                            Text(isLoading ? "获取中" : "获取门禁")
                        }
                    }
                    .disabled(isLoading || phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || idCard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                if !devices.isEmpty {
                    Section(header: Text("获取结果")) {
                        ForEach(devices) { device in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(device.name.isEmpty ? "门禁" : device.name)
                                    .font(.headline)
                                Text("macNum: \(device.mac)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("productKey: \(device.key)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                if !device.bluetoothName.isEmpty {
                                    Text("bluetoothName: \(device.bluetoothName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Button("填入添加") {
                                    onPick(device.device)
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("在线获取")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func fetch() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = ""
        devices = []
        do {
            let result = try await EntranceGuardAPI.shared.fetchDevices(phone: phone, idCard: idCard)
            devices = result
            if result.isEmpty {
                errorMessage = "没有获取到可用门禁"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
