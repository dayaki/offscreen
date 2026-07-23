import SwiftUI
import Charts

struct StatsView: View {
    let stats: StatsStore

    @State private var history: [DayStats] = []
    @State private var topApps: [(name: String, seconds: Int)] = []

    private var today: DayStats { history.last ?? DayStats(day: StatsStore.dayString()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    statTile("Screen Score", value: "\(today.score)", detail: scoreCaption(today.score))
                    statTile("Active Today", value: Format.duration(today.activeSeconds), detail: "on screen")
                    statTile(
                        "Breaks Today",
                        value: "\(today.completed)",
                        detail: "\(today.skipped) skipped · \(today.snoozes) snoozed"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Active hours — last 7 days")
                        .font(.headline)
                    Chart(history) { day in
                        BarMark(
                            x: .value("Day", shortLabel(day.day)),
                            y: .value("Hours", Double(day.activeSeconds) / 3600),
                            width: .ratio(0.55)
                        )
                        .foregroundStyle(Theme.violet)
                        .cornerRadius(3)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine().foregroundStyle(.quaternary)
                            AxisValueLabel {
                                if let hours = value.as(Double.self) {
                                    Text("\(hours, specifier: "%.0f")h").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 160)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top apps today").font(.headline)
                    if topApps.isEmpty {
                        Text("No usage recorded yet.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(topApps, id: \.name) { app in
                        HStack {
                            Text(app.name)
                                .frame(width: 160, alignment: .leading)
                                .lineLimit(1)
                            GeometryReader { geo in
                                let maxSeconds = topApps.first?.seconds ?? 1
                                Capsule()
                                    .fill(Theme.amber.opacity(0.85))
                                    .frame(
                                        width: max(4, geo.size.width * CGFloat(app.seconds) / CGFloat(max(1, maxSeconds))),
                                        height: 8
                                    )
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            Text(Format.duration(app.seconds))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .frame(height: 20)
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 480, height: 560)
        .onAppear(perform: refresh)
        .task {
            // Keep the window fresh while it stays open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                refresh()
            }
        }
    }

    private func refresh() {
        history = stats.history(days: 7)
        topApps = stats.topApps()
    }

    private func statTile(_ title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func scoreCaption(_ score: Int) -> String {
        switch score {
        case 85...: "great habits"
        case 60..<85: "decent — take your breaks"
        default: "your eyes need more breaks"
        }
    }

    private func shortLabel(_ day: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day) else { return day }
        let out = DateFormatter()
        out.dateFormat = "EEE"
        return out.string(from: date)
    }
}
