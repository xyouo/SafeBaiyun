import SwiftUI
import UIKit

struct DebugLogView: View {
    @ObservedObject private var logStore = DebugLogStore.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var exportURL: URL?
    @State private var showExportSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                Text(logStore.entries.isEmpty ? "暂无日志" : logStore.entries.joined(separator: "\n"))
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
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
                            logStore.clear()
                        }
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let exportURL = exportURL {
                    ActivityView(activityItems: [exportURL])
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func exportLog() {
        let text = logStore.entries.isEmpty ? "暂无日志\n" : logStore.entries.joined(separator: "\n")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "SafeBaiyun-log-\(formatter.string(from: Date())).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
            showExportSheet = true
        } catch {
            DebugLogStore.shared.append("导出日志失败: \(error.localizedDescription)")
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
