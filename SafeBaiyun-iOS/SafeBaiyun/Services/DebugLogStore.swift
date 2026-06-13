import Foundation

struct DebugLogSession: Identifiable, Equatable {
    let id: String
    let title: String
    let fileURL: URL
}

final class DebugLogStore: ObservableObject {
    static let shared = DebugLogStore()

    @Published private(set) var sessions: [DebugLogSession] = []
    @Published var selectedSessionId: String {
        didSet { loadSelectedSession() }
    }
    @Published private(set) var entries: [String] = []

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private let fileFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()

    private let logsDirectory: URL
    private let currentSession: DebugLogSession

    private init() {
        #if DEBUG
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        logsDirectory = baseURL.appendingPathComponent("SafeBaiyunLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        let now = Date()
        let id = fileFormatter.string(from: now)
        let title = titleFormatter.string(from: now)
        let fileURL = logsDirectory.appendingPathComponent("SafeBaiyun-log-\(id).txt")
        currentSession = DebugLogSession(id: id, title: title, fileURL: fileURL)
        selectedSessionId = id

        if FileManager.default.fileExists(atPath: fileURL.path) == false {
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        reloadSessions()
        loadSelectedSession()
        #else
        logsDirectory = FileManager.default.temporaryDirectory
        currentSession = DebugLogSession(id: "release", title: "Release", fileURL: logsDirectory)
        selectedSessionId = "release"
        #endif
    }

    func append(_ message: String) {
        #if DEBUG
        let line = "[\(formatter.string(from: Date()))] \(message)"
        appendLine(line, to: currentSession.fileURL)
        if selectedSessionId == currentSession.id {
            entries.append(line)
        }
        reloadSessions()
        print(line)
        #endif
    }

    func clearSelectedSession() {
        #if DEBUG
        guard let session = selectedSession else { return }
        try? "".write(to: session.fileURL, atomically: true, encoding: .utf8)
        entries.removeAll()
        #endif
    }

    func deleteSelectedSession() {
        #if DEBUG
        guard let session = selectedSession else { return }
        if session.id == currentSession.id {
            try? "".write(to: session.fileURL, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: session.fileURL)
        }
        reloadSessions()
        loadSelectedSession()
        #endif
    }

    func deleteAllSessions() {
        #if DEBUG
        for session in sessions {
            try? FileManager.default.removeItem(at: session.fileURL)
        }
        if FileManager.default.fileExists(atPath: currentSession.fileURL.path) == false {
            try? "".write(to: currentSession.fileURL, atomically: true, encoding: .utf8)
        }
        selectedSessionId = currentSession.id
        reloadSessions()
        loadSelectedSession()
        #endif
    }

    func exportURLForSelectedSession() -> URL? {
        selectedSession?.fileURL
    }

    private var selectedSession: DebugLogSession? {
        sessions.first { $0.id == selectedSessionId }
    }

    private func reloadSessions() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        sessions = urls
            .filter { $0.pathExtension == "txt" && $0.lastPathComponent.hasPrefix("SafeBaiyun-log-") }
            .map { url in
                let id = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "SafeBaiyun-log-", with: "")
                return DebugLogSession(id: id, title: title(from: id), fileURL: url)
            }
            .sorted { $0.id > $1.id }

        if sessions.contains(where: { $0.id == selectedSessionId }) == false {
            selectedSessionId = sessions.first?.id ?? currentSession.id
        }
    }

    private func loadSelectedSession() {
        #if DEBUG
        guard let session = selectedSession else {
            entries = []
            return
        }
        let text = (try? String(contentsOf: session.fileURL, encoding: .utf8)) ?? ""
        entries = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.isEmpty }
        #endif
    }

    private func appendLine(_ line: String, to fileURL: URL) {
        let data = Data((line + "\n").utf8)
        if FileManager.default.fileExists(atPath: fileURL.path),
           let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func title(from id: String) -> String {
        guard let date = fileFormatter.date(from: id) else { return id }
        return titleFormatter.string(from: date)
    }
}
