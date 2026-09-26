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

            MessageOfTheDayText(intervalHours: timer.messageIntervalHours)

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
                .buttonStyle(GlassPillButtonStyle(tint: timer.isRunning ? .blue : .green))

                Button {
                    timer.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(GlassPillButtonStyle(tint: .gray))

                Button {
                    timer.skip()
                } label: {
                    Label("Skip", systemImage: "forward.end.fill")
                }
                .buttonStyle(GlassPillButtonStyle(tint: .gray))
            }
            .labelStyle(.titleAndIcon)

            Divider()

            DisclosureGroup(isExpanded: $showingSettings) {
                VStack(alignment: .leading, spacing: 8) {
                    IntervalStepper(label: "Focus", minutes: $timer.focusMinutes, step: 5)
                    IntervalStepper(label: "Short Break", minutes: $timer.shortBreakMinutes, step: 5)
                    IntervalStepper(label: "Long Break", minutes: $timer.longBreakMinutes, step: 5)
                    IntervalStepper(label: "Sessions / long break", minutes: $timer.sessionsUntilLongBreak, step: 1, suffix: "")
                    IntervalStepper(label: "New message every", minutes: $timer.messageIntervalHours, step: 6, maximum: 168, suffix: "h")
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

            HStack(spacing: 10) {
                Button {
                    exportCSV()
                } label: {
                    Label("Export CSV…", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(GlassPillButtonStyle(tint: .gray))

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(GlassPillButtonStyle(tint: .gray))
            }
            .labelStyle(.titleAndIcon)
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

/// The rotating message above the countdown. The timeline fires only at
/// the moments the message switches, so it costs nothing in between.
private struct MessageOfTheDayText: View {
    let intervalHours: Int

    var body: some View {
        TimelineView(.periodic(
            from: MessageOfTheDay.slotStart(at: Date(), intervalHours: intervalHours),
            by: MessageOfTheDay.slotLength(intervalHours)
        )) { context in
            Text(MessageOfTheDay.message(at: context.date, intervalHours: intervalHours))
                .font(.callout)
                .italic()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
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
    var maximum: Int = 180
    var suffix: String = "min"

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Stepper(value: $minutes, in: step...maximum, step: step) {
                Text("\(minutes)\(suffix.isEmpty ? "" : " \(suffix)")")
                    .monospacedDigit()
                    .frame(minWidth: 50, alignment: .trailing)
            }
        }
        .font(.subheadline)
    }
}

/// The one button look used across the dropdown: a full-width capsule of
/// clear Liquid Glass (macOS 26+) lightly tinted, the tint turning vivid on
/// hover. Buttons in a row share its width equally, so they match in size.
struct GlassPillButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        GlassPill(configuration: configuration, tint: tint)
    }
}

private struct GlassPill: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color
    @Environment(\.controlSize) private var controlSize
    @ViewState private var hovering = false

    private var isSmall: Bool { controlSize == .small || controlSize == .mini }
    private var tintOpacity: Double {
        configuration.isPressed ? 0.75 : hovering ? 0.55 : 0.18
    }

    var body: some View {
        configuration.label
            .font(isSmall ? .callout : .body)
            .lineLimit(1)
            .padding(.vertical, isSmall ? 7 : 9)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .contentShape(.capsule)
            .background { background }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .onHover { hovering = $0 }
            .animation(.snappy(duration: 0.2), value: hovering)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }

    @ViewBuilder
    private var background: some View {
        if #available(macOS 26, *) {
            Color.clear
                .glassEffect(.clear.tint(tint.opacity(tintOpacity)), in: .capsule)
        } else {
            Capsule()
                .fill(tint.opacity(tintOpacity))
                .overlay(Capsule().strokeBorder(.white.opacity(0.2)))
        }
    }
}
