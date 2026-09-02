import SwiftUI

@main
struct RezodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var timer = PomodoroTimer()

    var body: some Scene {
        appDelegate.timer = timer // idempotent; ensures the delegate can log appQuit
        return MenuBarExtra(timer.menuBarText) {
            ContentView(timer: timer)
        }
        .menuBarExtraStyle(.window)
    }
}
