import SwiftUI
import UIKit

private struct CacheRow: Identifiable, Equatable {
    let deviceId: String
    let deviceName: String
    let mac: String
    var value: String

    var id: String { deviceId }
}

struct DebugLogView: View {
    @ObservedObject private var logStore = DebugLogStore.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var exportItem: ExportItem?
    @State private var cacheRows: [CacheRow] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                cacheSection

                Divider()

                Picker("日志", selection: $logStore.selectedSessionId) {
                    ForEach(logStore.sessions) { session in
                        Text(session.title).tag(session.id)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    Text(logStore.entries.isEmpty ? "暂无日志" : logStore.entries.joined(separator: "\n"))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("调试日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("导出") {
                            exportLog()
                        }
                        Button("复制") {
                            UIPasteboard.general.string = logStore.entries.joined(separator: "\n")
                        }
                        Button("清空") {
                            logStore.clearSelectedSession()
                        }
                    }
                }
            }
            .sheet(item: $exportItem) { item in
                ActivityView(activityItems: [item.url])
            }
            .onAppear {
                refreshCacheInfos()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("缓存外设")
                    .font(.headline)
                Spacer()
                Button("刷新") {
                    refreshCacheInfos()
                }
                if cacheRows.contains(where: { !$0.value.isEmpty }) {
                    Button("全部清除", role: .destructive) {
                        DataService.shared.clearAllCachedPeripherals()
                        DebugLogStore.shared.append("已清除全部缓存外设")
                        refreshCacheInfos()
                    }
                }
            }

            if cacheRows.isEmpty {
                Text("暂无设备")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach($cacheRows) { $row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.deviceName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Spacer()
                            Button("保存") {
                                saveCache(row)
                            }
                            .disabled(row.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Button("清除", role: .destructive) {
                                DataService.shared.clearCachedPeripheral(for: row.deviceId)
                                DebugLogStore.shared.append("已清除缓存外设: device=\(row.deviceName)")
                                row.value = ""
                                refreshCacheInfos()
                            }
                        }
                        Text("MAC: \(row.mac)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                        TextField("iOS 外设 UUID", text: $row.value)
                            .font(.caption2.monospaced())
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private func exportLog() {
        guard let url = logStore.exportURLForSelectedSession() else {
            DebugLogStore.shared.append("导出日志失败: 未找到当前日志文件")
            return
        }
        exportItem = ExportItem(url: url)
    }

    private func refreshCacheInfos() {
        cacheRows = DataService.shared.readDevices().map { device in
            CacheRow(
                deviceId: device.id,
                deviceName: device.name,
                mac: device.mac,
                value: DataService.shared.cachedPeripheralId(for: device.id)?.uuidString ?? ""
            )
        }
    }

    private func saveCache(_ row: CacheRow) {
        if DataService.shared.saveCachedPeripheralIdString(row.value, for: row.deviceId) {
            DebugLogStore.shared.append("已保存缓存外设: device=\(row.deviceName), uuid=\(row.value)")
            refreshCacheInfos()
        } else {
            DebugLogStore.shared.append("保存缓存外设失败，UUID 格式不正确: device=\(row.deviceName), value=\(row.value)")
        }
    }
}

struct ExportItem: Identifiable {
    let url: URL
    var id: String { url.path }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
