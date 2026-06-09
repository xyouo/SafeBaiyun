import Foundation

final class DebugLogStore: ObservableObject {
    static let shared = DebugLogStore()

    @Published private(set) var entries: [String] = []

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private init() {}

    func append(_ message: String) {
        #if DEBUG
        let line = "[\(formatter.string(from: Date()))] \(message)"
        entries.append(line)
        if entries.count > 300 {
            entries.removeFirst(entries.count - 300)
        }
        print(line)
        #endif
    }

    func clear() {
        entries.removeAll()
    }
}
