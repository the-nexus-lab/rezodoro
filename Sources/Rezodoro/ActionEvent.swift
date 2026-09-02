import Foundation

/// Every discrete action the user (or the timer itself) takes, timestamped.
/// This is the raw, fine-grained record — separate from the simple
/// per-session CSV export — kept so future analysis can reconstruct exact
/// timelines, idle gaps between sessions, how often sessions get skipped or
/// reset, etc.
enum ActionType: String, Codable {
    case start
    case pause
    case resume
    case complete
    case skip
    case reset
    case settingsChanged
    case appLaunched
    case appQuit
}

struct ActionEvent: Codable {
    let type: ActionType
    let timestamp: Date
    /// The session kind this action applies to (nil for app lifecycle / settings events).
    let sessionKind: SessionKind?
    /// Planned length of the current session, in minutes, at the time of the action.
    let plannedMinutes: Int?
    /// Seconds remaining in the current session at the time of the action.
    let remainingSeconds: Int?
    /// For settingsChanged: which setting, and its new value.
    let settingName: String?
    let settingValue: Int?

    init(
        type: ActionType,
        timestamp: Date = Date(),
        sessionKind: SessionKind? = nil,
        plannedMinutes: Int? = nil,
        remainingSeconds: Int? = nil,
        settingName: String? = nil,
        settingValue: Int? = nil
    ) {
        self.type = type
        self.timestamp = timestamp
        self.sessionKind = sessionKind
        self.plannedMinutes = plannedMinutes
        self.remainingSeconds = remainingSeconds
        self.settingName = settingName
        self.settingValue = settingValue
    }
}
