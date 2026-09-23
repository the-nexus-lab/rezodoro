import Foundation

enum SessionKind: String, Codable, CaseIterable {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
}

struct LogEntry: Codable {
    let kind: SessionKind
    let startedAt: Date
    let endedAt: Date
    let plannedMinutes: Int
    let completed: Bool

    static let csvHeader = "kind,started_at,ended_at,planned_minutes,actual_minutes,completed"

    /// Shared: ISO8601DateFormatter is expensive to create and thread-safe to reuse.
    nonisolated(unsafe) private static let formatter = ISO8601DateFormatter()

    init(kind: SessionKind, startedAt: Date, endedAt: Date, plannedMinutes: Int, completed: Bool) {
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedMinutes = plannedMinutes
        self.completed = completed
    }

    /// Parses one row written by csvRow(); nil for the header or malformed lines.
    init?(csvRow row: Substring) {
        let fields = row.split(separator: ",", omittingEmptySubsequences: false)
        guard fields.count == 6,
              let kind = SessionKind(rawValue: String(fields[0])),
              let startedAt = Self.formatter.date(from: String(fields[1])),
              let endedAt = Self.formatter.date(from: String(fields[2])),
              let planned = Int(fields[3]),
              let completed = Bool(String(fields[5])) else { return nil }
        self.init(kind: kind, startedAt: startedAt, endedAt: endedAt, plannedMinutes: planned, completed: completed)
    }

    func csvRow() -> String {
        let formatter = Self.formatter
        let actualMinutes = Int(endedAt.timeIntervalSince(startedAt) / 60.0)
        return [
            kind.rawValue,
            formatter.string(from: startedAt),
            formatter.string(from: endedAt),
            String(plannedMinutes),
            String(actualMinutes),
            String(completed)
        ].map { field in
            field.contains(",") ? "\"\(field)\"" : field
        }.joined(separator: ",")
    }
}
