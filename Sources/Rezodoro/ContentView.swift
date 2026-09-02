import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var timer: PomodoroTimer
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(timer.currentKind.rawValue)
                    .font(.headline)
                Spacer()
                Text("#\(timer.completedFocusSessions)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Text(timeString)
                .font(.system(size: 40, weight: .medium, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 10) {
                Button(timer.isRunning ? "Pause" : "Start") {
                    timer.toggle()
                }
                .keyboardShortcut(.defaultAction)

                Button("Reset") {
                    timer.reset()
                }

                Button("Skip") {
                    timer.skip()
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Divider()

            DisclosureGroup("Intervals", isExpanded: $showingSettings) {
                VStack(alignment: .leading, spacing: 8) {
                    IntervalStepper(label: "Focus", minutes: $timer.focusMinutes, step: 5)
                    IntervalStepper(label: "Short Break", minutes: $timer.shortBreakMinutes, step: 5)
                    IntervalStepper(label: "Long Break", minutes: $timer.longBreakMinutes, step: 5)
                    IntervalStepper(label: "Sessions / long break", minutes: $timer.sessionsUntilLongBreak, step: 1, suffix: "")
                }
                .padding(.top, 4)
            }

            Divider()

            HStack {
                Button("Export Logs as CSV…") {
                    exportCSV()
                }

                Spacer()

                Button("Quit Rezodoro") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 260)
    }

    private var timeString: String {
        let m = timer.remainingSeconds / 60
        let s = timer.remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "rezodoro-sessions.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            try? timer.exportCSVAndReturn(to: url)
        }
    }
}

struct IntervalStepper: View {
    let label: String
    @Binding var minutes: Int
    var step: Int = 1
    var suffix: String = "min"

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Stepper(value: $minutes, in: step...180, step: step) {
                Text("\(minutes)\(suffix.isEmpty ? "" : " \(suffix)")")
                    .monospacedDigit()
                    .frame(minWidth: 50, alignment: .trailing)
            }
        }
        .font(.subheadline)
    }
}
