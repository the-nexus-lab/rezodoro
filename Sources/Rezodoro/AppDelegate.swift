import AppKit
import UserNotifications

/// Owns the timer and the menu bar UI; logs an appQuit event whenever the
/// app terminates, regardless of whether that's via the Quit menu item or
/// the system shutting it down — so the event log always has a clean
/// end-of-session marker; and routes notification clicks to the dropdown.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let timer = PomodoroTimer()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        menuBar = MenuBarController(timer: timer)
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer.prepareForQuit()
    }

    /// Show banners even while the dropdown is open (the app counts as
    /// "active" then, and macOS would otherwise silently drop them).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Clicking a Rezodoro notification opens the dropdown.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        await MainActor.run { menuBar?.open() }
    }
}
