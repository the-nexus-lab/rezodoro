import Foundation

final class LogStore {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Rezodoro", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("sessions.csv")

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? (LogEntry.csvHeader + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    func append(_ entry: LogEntry) {
        let line = entry.csvRow() + "\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        }
    }

    var logFileURL: URL { fileURL }

    func exportCSV(to destination: URL) throws {
        let data = try Data(contentsOf: fileURL)
        try data.write(to: destination)
    }
}
