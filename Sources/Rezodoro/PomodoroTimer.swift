import Foundation
import Combine
import AppKit
import UserNotifications

final class PomodoroTimer: ObservableObject {
    @Published var focusMinutes: Int = 25 {
        didSet {
            resetIfIdle()
            logSettingChange("focusMinutes", focusMinutes, oldValue)
        }
    }
    @Published var shortBreakMinutes: Int = 5 {
        didSet {
            resetIfIdle()
            logSettingChange("shortBreakMinutes", shortBreakMinutes, oldValue)
        }
    }
    @Published var longBreakMinutes: Int = 15 {
        didSet {
            resetIfIdle()
            logSettingChange("longBreakMinutes", longBreakMinutes, oldValue)
        }
    }
    @Published var sessionsUntilLongBreak: Int = 4 {
        didSet {
            logSettingChange("sessionsUntilLongBreak", sessionsUntilLongBreak, oldValue)
        }
    }

    @Published private(set) var currentKind: SessionKind = .focus
    @Published private(set) var remainingSeconds: Int = 25 * 60
    @Published private(set) var isRunning: Bool = false
    /// Sessions completed today (local calendar day) — the "#N" shown in
    /// the UI. Rolls back to 0 at local midnight.
    @Published private(set) var completedFocusSessions: Int = 0

    private var completedFocusSessionsDay: Date = Calendar.current.startOfDay(for: Date())

    /// Completed (not skipped) focus sessions since the last long break.
    /// Resets to 0 every time a long break is taken, so it always counts
    /// actual focus sessions only — short breaks never advance it.
    private var focusSessionsSinceLongBreak: Int = 0

    private var timer: Timer?
    private var sessionStartedAt: Date?
    private let log = LogStore()
    private let events = EventStore()

    var logFileURL: URL { log.logFileURL }
    var eventsFileURL: URL { events.eventsFileURL }

    func exportCSVAndReturn(to destination: URL) throws {
        try log.exportCSV(to: destination)
    }

    var plannedMinutes: Int {
        switch currentKind {
        case .focus: return focusMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }

    /// "24:59" — shown next to the logo in the menu bar while running.
    var countdownText: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("Rezodoro: notification authorization error: \(error)")
            } else {
                print("Rezodoro: notification authorization granted = \(granted)")
            }
        }
        remainingSeconds = focusMinutes * 60
        events.append(ActionEvent(type: .appLaunched))
    }

    private func resetIfIdle() {
        guard !isRunning else { return }
        remainingSeconds = plannedMinutes * 60
    }

    /// Rolls the "#N completed today" counter back to 0 when the local
    /// calendar day has changed since it was last touched. Cheap (one
    /// Calendar comparison), so it's safe to call from any user-facing
    /// entry point rather than needing a dedicated midnight timer.
    ///
    /// A new day resets everything: the "#N today" badge, the long-break
    /// progress, and the current session itself — so the app never sits
    /// on a stale Short/Long Break carried over from the night before.
    /// Only called from idle-time entry points (never mid-finishSession),
    /// so it's safe to freely reset currentKind here.
    private func rollOverDayIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today != completedFocusSessionsDay else { return }
        completedFocusSessionsDay = today
        completedFocusSessions = 0
        focusSessionsSinceLongBreak = 0
        if !isRunning {
            currentKind = .focus
            remainingSeconds = plannedMinutes * 60
        }
    }

    /// Called when the dropdown is opened, so the "#N" counter reflects a
    /// local-midnight rollover immediately even if the app sat idle
    /// overnight with no session activity to trigger the check otherwise.
    func checkForNewDay() {
        rollOverDayIfNeeded()
    }

    private func logSettingChange(_ name: String, _ newValue: Int, _ oldValue: Int) {
        guard newValue != oldValue else { return }
        events.append(ActionEvent(type: .settingsChanged, settingName: name, settingValue: newValue))
    }

    func logQuit() {
        events.append(currentEvent(.appQuit))
    }

    private func currentEvent(_ type: ActionType) -> ActionEvent {
        ActionEvent(
            type: type,
            sessionKind: currentKind,
            plannedMinutes: plannedMinutes,
            remainingSeconds: remainingSeconds
        )
    }

    func start() {
        guard !isRunning else { return }
        rollOverDayIfNeeded()
        let isResuming = sessionStartedAt != nil
        if sessionStartedAt == nil {
            sessionStartedAt = Date()
        }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        events.append(currentEvent(isResuming ? .resume : .start))
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        timer?.invalidate()
        timer = nil
        events.append(currentEvent(.pause))
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func reset() {
        let wasRunning = isRunning
        pause()
        if wasRunning || sessionStartedAt != nil {
            events.append(currentEvent(.reset))
        }
        sessionStartedAt = nil
        remainingSeconds = plannedMinutes * 60
    }

    func skip() {
        finishSession(completed: false)
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            finishSession(completed: true)
            return
        }
        remainingSeconds -= 1
    }

    private func finishSession(completed: Bool) {
        isRunning = false
        timer?.invalidate()
        timer = nil

        let start = sessionStartedAt ?? Date()
        log.append(LogEntry(
            kind: currentKind,
            startedAt: start,
            endedAt: Date(),
            plannedMinutes: plannedMinutes,
            completed: completed
        ))
        events.append(currentEvent(completed ? .complete : .skip))

        if currentKind == .focus {
            completedFocusSessions += 1
            // Only a fully completed (not skipped) focus session counts
            // toward the long-break threshold.
            if completed {
                focusSessionsSinceLongBreak += 1
            }
        }

        notify(finishedKind: currentKind, completed: completed)
        advance()
        sessionStartedAt = nil
        remainingSeconds = plannedMinutes * 60
    }

    private func advance() {
        switch currentKind {
        case .focus:
            if focusSessionsSinceLongBreak >= sessionsUntilLongBreak {
                currentKind = .longBreak
                focusSessionsSinceLongBreak = 0
            } else {
                currentKind = .shortBreak
            }
        case .shortBreak, .longBreak:
            currentKind = .focus
        }
    }

    private func notify(finishedKind: SessionKind, completed: Bool) {
        let content = UNMutableNotificationContent()
        content.title = completed ? "\(finishedKind.rawValue) complete" : "\(finishedKind.rawValue) skipped"
        content.body = completed ? "Time for the next session." : "Moving on to the next session."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Rezodoro: failed to deliver notification: \(error)")
            }
        }
    }
}
