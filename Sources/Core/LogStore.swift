import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let category: String
    let message: String

    var line: String {
        "\(LogStore.timeFormatter.string(from: date)) [\(category)] \(message)"
    }
}

final class LogStore: ObservableObject {
    static let shared = LogStore()

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    @Published private(set) var entries: [LogEntry] = []
    let fileURL: URL
    private let maxInMemory = 3000

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        fileURL = docs.appendingPathComponent("probe-\(f.string(from: Date())).log")
    }

    func add(_ category: String, _ message: String) {
        let entry = LogEntry(date: Date(), category: category, message: message)
        DispatchQueue.main.async {
            self.entries.append(entry)
            if self.entries.count > self.maxInMemory {
                self.entries.removeFirst(self.entries.count - self.maxInMemory)
            }
            self.appendToFile(entry.line)
        }
    }

    func clear() {
        DispatchQueue.main.async { self.entries.removeAll() }
    }

    var text: String {
        entries.map { $0.line }.joined(separator: "\n")
    }

    private func appendToFile(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: fileURL)
        }
    }
}

enum Log {
    static func add(_ category: String, _ message: String) {
        LogStore.shared.add(category, message)
    }
}
