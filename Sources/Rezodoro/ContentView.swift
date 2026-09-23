import SwiftUI
import AppKit

/// SwiftUI's classic `State` property wrapper. The macOS 27 SDK turned
/// `@State` into a macro whose compiler plugin ships only with Xcode, so a
/// Command Line Tools `swift build` fails on it; going through this alias
/// uses the (still fully supported) property wrapper directly.
typealias ViewState<Value> = SwiftUI.State<Value>

struct ContentView: View {
    @Bindable var timer: PomodoroTimer
    /// Closes the menu bar dropdown.
    let dismiss: () -> Void
    @ViewState private var showingSettings = false
    @ViewState private var showingHistory = false

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

            CountdownText(timer: timer)

            HStack(spacing: 10) {
                Button {
                    let starting = !timer.isRunning
                    timer.toggle()
                    if starting { closeDropdown() }
                } label: {
                    Label(timer.isRunning ? "Pause" : "Start",
                          systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                }
                .keyboardShortcut(.defaultAction)
                .glassButtonStyle(prominent: true)

                Button {
                    timer.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .glassButtonStyle()

                Button {
                    timer.skip()
                } label: {
                    Label("Skip", systemImage: "forward.end.fill")
                }
                .glassButtonStyle()
            }
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, alignment: .center)

            Divider()

            DisclosureGroup(isExpanded: $showingSettings) {
                VStack(alignment: .leading, spacing: 8) {
                    IntervalStepper(label: "Focus", minutes: $timer.focusMinutes, step: 5)
                    IntervalStepper(label: "Short Break", minutes: $timer.shortBreakMinutes, step: 5)
                    IntervalStepper(label: "Long Break", minutes: $timer.longBreakMinutes, step: 5)
                    IntervalStepper(label: "Sessions / long break", minutes: $timer.sessionsUntilLongBreak, step: 1, suffix: "")
                }
                .padding(.top, 4)
            } label: {
                DisclosureLabel(title: "Intervals", isExpanded: $showingSettings)
            }

            DisclosureGroup(isExpanded: $showingHistory) {
                HistoryView(timer: timer, revision: timer.historyRevision)
                    .padding(.top, 4)
            } label: {
                DisclosureLabel(title: "History", isExpanded: $showingHistory)
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
            .controlSize(.small)
        }
        .padding(14)
    }

    /// Deferred a runloop turn so the button finishes handling its click
    /// before the window it lives in goes away.
    private func closeDropdown() {
        DispatchQueue.main.async { dismiss() }
    }

    private func exportCSV() {
        dismiss()
        NSApp.activate()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "rezodoro-sessions.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            try? timer.exportCSVAndReturn(to: url)
        }
    }
}

/// The big countdown, split into its own view so the per-second tick only
/// re-renders this text rather than the whole dropdown.
private struct CountdownText: View {
    let timer: PomodoroTimer

    var body: some View {
        Text(timer.countdownText)
            .font(.system(size: 40, weight: .medium, design: .rounded))
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct DisclosureLabel: View {
    let title: String
    @Binding var isExpanded: Bool

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy) { isExpanded.toggle() }
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

private extension View {
    /// Liquid Glass buttons on macOS 26+, the closest bordered look before.
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else if prominent {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }
}
