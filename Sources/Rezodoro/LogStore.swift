import Foundation

/// Focus totals for one local calendar day, as shown in the history chart.
struct DaySummary: Identifiable, Equatable {
    let day: Date
    var focusSeconds: TimeInterval = 0
    var completed: Int = 0
    var skipped: Int = 0

    var id: Date { day }
    var focusMinutes: Int { Int((focusSeconds / 60).rounded()) }
}

@MainActor
final class LogStore {
    private let fileURL: URL
    /// Recently logged entries, parsed from disk on first use and then kept
    /// current by append(), so the history chart never re-reads the file.
    private var recentEntries: [LogEntry]?

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
        recentEntries?.append(entry)
        FileAppender.append(Data((entry.csvRow() + "\n").utf8), to: fileURL)
    }

    var logFileURL: URL { fileURL }

    func exportCSV(to destination: URL) throws {
        let data = try Data(contentsOf: fileURL)
        try data.write(to: destination)
    }

    /// One summary per day for the last `days` days (oldest first, today
    /// last), counting focus sessions only. Completed sessions count their
    /// planned length; skipped ones the time actually spent, capped at plan.
    func dailySummaries(days: Int, now: Date = Date()) -> [DaySummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard days > 0, let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        var summaries = (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: firstDay).map { DaySummary(day: $0) }
        }
        for entry in entries(since: firstDay) where entry.kind == .focus {
            let day = calendar.startOfDay(for: entry.endedAt)
            guard let index = calendar.dateComponents([.day], from: firstDay, to: day).day,
                  summaries.indices.contains(index) else { continue }
            let planned = TimeInterval(entry.plannedMinutes * 60)
            if entry.completed {
                summaries[index].completed += 1
                summaries[index].focusSeconds += planned
            } else {
                summaries[index].skipped += 1
                summaries[index].focusSeconds += min(max(0, entry.endedAt.timeIntervalSince(entry.startedAt)), planned)
            }
        }
        return summaries
    }

    private func entries(since cutoff: Date) -> [LogEntry] {
        let entries = (recentEntries ?? loadEntries(since: cutoff)).filter { $0.endedAt >= cutoff }
        recentEntries = entries // also drops entries that aged out of the window
        return entries
    }

    /// Parses the CSV from the end backwards and stops at the first row older
    /// than `cutoff` — the log is chronological, so this only decodes the
    /// few rows the chart needs no matter how large the file grows.
    private func loadEntries(since cutoff: Date) -> [LogEntry] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        var result: [LogEntry] = []
        for line in text.split(separator: "\n").reversed() {
            guard let entry = LogEntry(csvRow: line) else { continue } // header / malformed
            if entry.endedAt < cutoff { break }
            result.append(entry)
        }
        return result.reversed()
    }
}

/// Appends bytes to an existing file using the throwing FileHandle APIs
/// (the legacy seekToEndOfFile()/write(_:) raise Objective-C exceptions on
/// I/O errors, which would crash the app instead of just dropping a line).
enum FileAppender {
    static func append(_ data: Data, to url: URL) {
        do {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            print("Rezodoro: failed to append to \(url.lastPathComponent): \(error)")
        }
    }
}
