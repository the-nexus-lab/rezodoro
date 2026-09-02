import AppKit

/// Logs an appQuit event whenever the app terminates, regardless of whether
/// that's via the Quit menu item or the system shutting it down — so the
/// event log always has a clean end-of-session marker.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var timer: PomodoroTimer?

    func applicationWillTerminate(_ notification: Notification) {
        timer?.logQuit()
    }
}
