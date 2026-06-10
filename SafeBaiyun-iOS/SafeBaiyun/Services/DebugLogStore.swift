import Foundation

final class DebugLogStore: ObservableObject {
    static let shared = DebugLogStore()

    @Published private(set) var entries: [String] = []
    private let storageKey = "debugLogEntries"

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private init() {
        #if DEBUG
        entries = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        #endif
    }

    func append(_ message: String) {
        #if DEBUG
        let line = "[\(formatter.string(from: Date()))] \(message)"
        entries.append(line)
        if entries.count > 300 {
            entries.removeFirst(entries.count - 300)
        }
        persist()
        print(line)
        #endif
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    private func persist() {
        #if DEBUG
        UserDefaults.standard.set(entries, forKey: storageKey)
        #endif
    }
}
