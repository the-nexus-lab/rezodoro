import SwiftUI
import Charts

/// Focus minutes per day for the last 10 days. Hover a bar to see that
/// day's details in the header line.
struct HistoryView: View {
    static let dayCount = 10

    let timer: PomodoroTimer
    /// Only here so SwiftUI re-runs `.task(id:)` when a session is logged.
    let revision: Int

    @ViewState private var days: [DaySummary] = []
    @ViewState private var selectedDate: Date?

    private var selectedDay: DaySummary? {
        guard let selectedDate else { return nil }
        return days.first { Calendar.current.isDate($0.day, inSameDayAs: selectedDate) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.day, unit: .day),
                    y: .value("Focus minutes", day.focusMinutes),
                    width: .ratio(0.6)
                )
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3))
                .foregroundStyle(Color.accentColor.opacity(isDimmed(day) ? 0.35 : 1))
                .accessibilityLabel(day.day.formatted(.dateTime.weekday(.wide).month().day()))
                .accessibilityValue("\(Self.duration(day.focusSeconds)) focus, \(day.completed) completed, \(day.skipped) skipped")
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) {
                    AxisValueLabel(format: .dateTime.day(), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYScale(domain: 0...max(30, days.map(\.focusMinutes).max() ?? 0))
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                let x = location.x - (proxy.plotFrame.map { geometry[$0].minX } ?? 0)
                                selectedDate = proxy.value(atX: x, as: Date.self)
                            case .ended:
                                selectedDate = nil
                            }
                        }
                }
            }
            .overlay {
                if days.allSatisfy({ $0.focusSeconds == 0 }) {
                    Text("No focus sessions yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 110)
        }
        .task(id: revision) {
            days = timer.history(days: Self.dayCount)
        }
    }

    @ViewBuilder
    private var header: some View {
        if let day = selectedDay {
            let date = Text(day.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .fontWeight(.semibold)
            let skipped = day.skipped > 0 ? ", \(day.skipped) skipped" : ""
            Text("\(date)  \(Self.duration(day.focusSeconds)) · \(day.completed) done\(skipped)")
        } else {
            let total = days.reduce(0) { $0 + $1.focusSeconds }
            let sessions = days.reduce(0) { $0 + $1.completed }
            let title = Text("Last \(Self.dayCount) days").fontWeight(.semibold)
            Text("\(title)  \(Self.duration(total)) · \(sessions) sessions")
        }
    }

    private func isDimmed(_ day: DaySummary) -> Bool {
        guard let selectedDay else { return false }
        return selectedDay.day != day.day
    }

    /// "1h 40m", "25m", "0m".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
