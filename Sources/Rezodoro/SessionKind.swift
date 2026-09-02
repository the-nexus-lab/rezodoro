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

    func csvRow() -> String {
        let formatter = ISO8601DateFormatter()
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
