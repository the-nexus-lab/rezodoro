import Foundation

/// Append-only, fine-grained action log kept in the background for future
/// behavior analysis (idle gaps between sessions, skip/reset frequency,
/// time-of-day patterns, etc). Not shown in the simple CSV export — this is
/// the enriched data set that export summarizes from.
///
/// Stored as JSONL (one JSON object per line) since events have varying
/// shapes and this is meant for programmatic analysis, not manual reading.
final class EventStore {
    private let fileURL: URL
    private let encoder: JSONEncoder

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Rezodoro", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("events.jsonl")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    func append(_ event: ActionEvent) {
        guard var data = try? encoder.encode(event) else { return }
        data.append(0x0A) // newline
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        }
    }

    var eventsFileURL: URL { fileURL }
}
