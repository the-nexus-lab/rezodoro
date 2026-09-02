import SwiftUI

@main
struct RezodoroApp: App {
    @StateObject private var timer = PomodoroTimer()

    var body: some Scene {
        MenuBarExtra(timer.menuBarText) {
            ContentView(timer: timer)
        }
        .menuBarExtraStyle(.window)
    }
}
