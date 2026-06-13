import SwiftUI
import UIKit

struct DebugLogView: View {
    @ObservedObject private var logStore = DebugLogStore.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var exportItem: ExportItem?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func exportLog() {
        guard let url = logStore.exportURLForSelectedSession() else {
            DebugLogStore.shared.append("导出日志失败: 未找到当前日志文件")
            return
        }
        exportItem = ExportItem(url: url)
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
