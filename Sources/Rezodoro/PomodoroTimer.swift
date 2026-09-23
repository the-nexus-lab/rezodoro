import Foundation
import Observation
import UserNotifications

/// `@Observable` (rather than ObservableObject) so SwiftUI tracks each
/// property individually: the once-a-second `remainingSeconds` tick only
/// re-renders the views that actually read it (the menu bar label and the
/// countdown text), not the whole dropdown.
@MainActor
@Observable
final class PomodoroTimer {
    var focusMinutes: Int = 25 {
        didSet {
            resetIfIdle()
            logSettingChange("focusMinutes", focusMinutes, oldValue)
        }
    }
    var shortBreakMinutes: Int = 5 {
        didSet {
            resetIfIdle()
            logSettingChange("shortBreakMinutes", shortBreakMinutes, oldValue)
        }
    }
    var longBreakMinutes: Int = 15 {
        didSet {
            resetIfIdle()
            logSettingChange("longBreakMinutes", longBreakMinutes, oldValue)
        }
    }
    var sessionsUntilLongBreak: Int = 4 {
        didSet {
            logSettingChange("sessionsUntilLongBreak", sessionsUntilLongBreak, oldValue)
        }
    }

    private(set) var currentKind: SessionKind = .focus
    private(set) var remainingSeconds: Int = 25 * 60
    private(set) var isRunning: Bool = false
    /// Sessions completed today (local calendar day) — the "#N" shown in
    /// the UI. Rolls back to 0 at local midnight.
    private(set) var completedFocusSessions: Int = 0
    /// Bumped whenever a session is written to the log or the day rolls
    /// over, so the history chart knows to reload without polling.
    private(set) var historyRevision: Int = 0

    @ObservationIgnored private var completedFocusSessionsDay: Date = Calendar.current.startOfDay(for: Date())

    /// Completed (not skipped) focus sessions since the last long break.
    /// Resets to 0 every time a long break is taken, so it always counts
    /// actual focus sessions only — short breaks never advance it.
    @ObservationIgnored private var focusSessionsSinceLongBreak: Int = 0

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var sessionStartedAt: Date?
    /// Wall-clock moment the running session ends. The countdown is derived
    /// from this rather than decremented per tick, so it stays exact even if
    /// ticks are delayed (App Nap, timer coalescing) or the Mac sleeps.
    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private let log = LogStore()
    @ObservationIgnored private let events = EventStore()

    private static let endNotificationID = "rezodoro.session-end"

    var logFileURL: URL { log.logFileURL }
    var eventsFileURL: URL { events.eventsFileURL }

    func exportCSVAndReturn(to destination: URL) throws {
        try log.exportCSV(to: destination)
    }

    func history(days: Int) -> [DaySummary] {
        log.dailySummaries(days: days)
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
        historyRevision += 1
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

    /// Logs the quit and withdraws any pending "complete" banner, so it
    /// doesn't pop up later for a session that no longer exists.
    func prepareForQuit() {
        events.append(currentEvent(.appQuit))
        cancelEndNotification()
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
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Lets macOS coalesce our wakeups with other timers; the countdown
        // is computed from endDate, so a late tick never skews it.
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        scheduleEndNotification()
        events.append(currentEvent(isResuming ? .resume : .start))
    }

    func pause() {
        guard isRunning else { return }
        syncRemaining()
        stopTicking()
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
        syncRemaining()
        if remainingSeconds <= 0 {
            finishSession(completed: true)
        }
    }

    /// Recomputes remainingSeconds from endDate, only touching the
    /// observed property when the displayed value actually changes.
    private func syncRemaining() {
        guard let endDate else { return }
        let remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        if remaining != remainingSeconds {
            remainingSeconds = remaining
        }
    }

    /// `keepNotification` is for natural completion: the pre-scheduled
    /// banner is due right now, and cancelling it could race its delivery.
    private func stopTicking(keepNotification: Bool = false) {
        isRunning = false
        timer?.invalidate()
        timer = nil
        endDate = nil
        if !keepNotification {
            cancelEndNotification()
        }
    }

    private func finishSession(completed: Bool) {
        let scheduledEnd = endDate
        if isRunning { syncRemaining() }
        stopTicking(keepNotification: completed)

        let start = sessionStartedAt ?? Date()
        // A completed session ended at its scheduled time, even if the tick
        // that noticed it arrived late (e.g. right after the Mac woke up).
        let end = completed ? min(scheduledEnd ?? Date(), Date()) : Date()
        log.append(LogEntry(
            kind: currentKind,
            startedAt: start,
            endedAt: end,
            plannedMinutes: plannedMinutes,
            completed: completed
        ))
        historyRevision += 1
        events.append(currentEvent(completed ? .complete : .skip))

        if currentKind == .focus {
            completedFocusSessions += 1
            // Only a fully completed (not skipped) focus session counts
            // toward the long-break threshold.
            if completed {
                focusSessionsSinceLongBreak += 1
            }
        }

        // Completion notifications are pre-scheduled with the system at
        // start() so they fire on time regardless of our own tick; only a
        // skip needs one posted now.
        if !completed {
            notify(Self.notificationContent(kind: currentKind, completed: false))
        }
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

    // MARK: - Notifications

    private static func notificationContent(kind: SessionKind, completed: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = completed ? "\(kind.rawValue) complete" : "\(kind.rawValue) skipped"
        content.body = completed ? "Time for the next session." : "Moving on to the next session."
        content.sound = .default
        return content
    }

    /// Hands the "session complete" banner to the system for delivery at
    /// endDate, so it arrives on time even if the app is napping.
    private func scheduleEndNotification() {
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(max(1, remainingSeconds)),
            repeats: false
        )
        notify(Self.notificationContent(kind: currentKind, completed: true), id: Self.endNotificationID, trigger: trigger)
    }

    /// Withdraws a not-yet-delivered completion banner (pause/reset/skip).
    private func cancelEndNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.endNotificationID])
    }

    private func notify(_ content: UNNotificationContent, id: String = UUID().uuidString, trigger: UNNotificationTrigger? = nil) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Rezodoro: failed to deliver notification: \(error)")
            }
        }
    }
}
