import Foundation
import Combine
import AppKit
import UserNotifications

final class PomodoroTimer: ObservableObject {
    @Published var focusMinutes: Int = 25 { didSet { resetIfIdle() } }
    @Published var shortBreakMinutes: Int = 5 { didSet { resetIfIdle() } }
    @Published var longBreakMinutes: Int = 15 { didSet { resetIfIdle() } }
    @Published var sessionsUntilLongBreak: Int = 4

    @Published private(set) var currentKind: SessionKind = .focus
    @Published private(set) var remainingSeconds: Int = 25 * 60
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var completedFocusSessions: Int = 0

    /// Completed (not skipped) focus sessions since the last long break.
    /// Resets to 0 every time a long break is taken, so it always counts
    /// actual focus sessions only — short breaks never advance it.
    private var focusSessionsSinceLongBreak: Int = 0

    private var timer: Timer?
    private var sessionStartedAt: Date?
    private let log = LogStore()

    var logFileURL: URL { log.logFileURL }

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

    var menuBarText: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        let icon: String
        switch currentKind {
        case .focus: icon = "🍅"
        case .shortBreak: icon = "☕️"
        case .longBreak: icon = "🌿"
        }
        if isRunning {
            return String(format: "%@ %02d:%02d", icon, m, s)
        } else {
            return "🍅"
        }
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
    }

    private func resetIfIdle() {
        guard !isRunning else { return }
        remainingSeconds = plannedMinutes * 60
    }

    func start() {
        guard !isRunning else { return }
        if sessionStartedAt == nil {
            sessionStartedAt = Date()
        }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func reset() {
        pause()
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
        pause()
        let start = sessionStartedAt ?? Date()
        log.append(LogEntry(
            kind: currentKind,
            startedAt: start,
            endedAt: Date(),
            plannedMinutes: plannedMinutes,
            completed: completed
        ))

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
