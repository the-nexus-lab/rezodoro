import SwiftUI

@main
struct RezodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var timer = PomodoroTimer()

    var body: some Scene {
        appDelegate.timer = timer // idempotent; ensures the delegate can log appQuit
        return MenuBarExtra {
            ContentView(timer: timer)
        } label: {
            MenuBarLabel(timer: timer)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar status item's contents: the Rezodoro logo (as a template
/// image, so it adapts to light/dark menu bars) plus the countdown text
/// while a session is running.
private struct MenuBarLabel: View {
    @ObservedObject var timer: PomodoroTimer

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarLabel.icon)
            if timer.isRunning {
                Text(timer.countdownText)
                    .monospacedDigit()
            }
        }
    }

    static let icon: NSImage = {
        let image = Bundle.module.image(forResource: "MenuBarIcon") ?? NSImage()
        image.isTemplate = true
        image.size = NSSize(width: 12, height: image.size.height / image.size.width * 12)
        return image
    }()
}
