import SwiftUI
import Charts

extension AppModel {
    /// Heart rate around the main sleep that ended on `key`.
    func nightHeartRate(for key: String) -> NightHeartRate? {
        guard let session = record(for: key)?.mainSleep else { return nil }
        let samples = (record(for: DayKey.addDays(key, -1))?.hrSamples ?? []) + (record(for: key)?.hrSamples ?? [])
        let result = NightHeartRate.analyze(samples: samples, session: session)
        return result.sleepSamples == 0 && result.beforeBed == nil ? nil : result
    }

    /// Before-bed heart rate for the last `days` nights ending on `key`, oldest first.
    func beforeBedHistory(endingOn key: String, days: Int) -> [(key: String, value: Double)] {
        (0..<days).reversed().compactMap { offset in
            let day = DayKey.addDays(key, -offset)
            guard let value = nightHeartRate(for: day)?.beforeBed else { return nil }
            return (day, value)
        }
    }
}

/// Stats under the sleep heart-rate chart.
struct SleepHeartRateStats: View {
    @Environment(AppModel.self) private var model
    let key: String

    var body: some View {
        if let night = model.nightHeartRate(for: key) {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    StatTile(label: "Asleep avg", value: bpm(night.sleepingAverage), unit: "bpm")
                    StatTile(label: "Lowest", value: bpm(night.sleepingLowest), unit: "bpm",
                             sub: night.lowestAt.map { Fmt.clock($0) })
                    StatTile(label: "Before bed", value: bpm(night.beforeBed), unit: "bpm")
                }
                Text("From your Fitbit\u{2019}s minute-by-minute heart rate. Awake minutes during the night are left out. Resting HR in Recovery and Health is Fitbit\u{2019}s own daily resting heart rate, so it can differ from these.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func bpm(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()))" } ?? "–"
    }
}

/// Home card at the bottom: heart rate in the 30 minutes before falling asleep.
struct BeforeBedHeartRateCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let key = model.selectedDayKey
        let night = model.nightHeartRate(for: key)
        let history = model.beforeBedHistory(endingOn: key, days: 14)
        let earlier = history.dropLast().map(\.value)
        let average = earlier.isEmpty ? nil : earlier.reduce(0, +) / Double(earlier.count)
        let resting = model.record(for: key)?.restingHR

        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(text: "Heart Rate Before Bed")
            Panel(padding: 20) {
                if let value = night?.beforeBed {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                CapsLabel(text: "30 min before sleep", color: Theme.textSecondary, size: 11)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(Int(value.rounded()))")
                                        .font(.system(size: 40, weight: .bold).monospacedDigit())
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("bpm")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                if let average {
                                    compare(value - average, label: "vs 2-week avg")
                                }
                                if let resting {
                                    compare(value - resting, label: "above resting", plain: true)
                                }
                            }
                        }
                        if history.count >= 2 {
                            Chart(history, id: \.key) { item in
                                BarMark(
                                    x: .value("Night", DayKey.date(from: item.key) ?? Date(), unit: .day),
                                    yStart: .value("Base", (history.map(\.value).min() ?? 50) - 8),
                                    yEnd: .value("BPM", item.value)
                                )
                                .foregroundStyle(item.key == key ? Theme.sleepPurple : Theme.sleepPurple.opacity(0.4))
                                .cornerRadius(3)
                            }
                            .chartYScale(domain: ((history.map(\.value).min() ?? 50) - 8)...((history.map(\.value).max() ?? 90) + 4))
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                                    AxisValueLabel().foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .frame(height: 120)
                        }
                        Text(insight(value: value, average: average, resting: resting, earlier: night?.earlierEvening))
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("No heart rate for the half hour before last night\u{2019}s sleep yet. Wear your Fitbit into the evening and sync in the morning.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func compare(_ delta: Double, label: String, plain: Bool = false) -> some View {
        let rounded = Int(delta.rounded())
        let color: Color = plain ? Theme.textSecondary : (rounded > 2 ? Theme.orange : rounded < -2 ? Theme.green : Theme.textSecondary)
        return Text("\(rounded >= 0 ? "+" : "−")\(abs(rounded)) \(label)")
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .foregroundStyle(color)
    }

    private func insight(value: Double, average: Double?, resting: Double?, earlier: Double?) -> String {
        var parts: [String] = []
        if let resting {
            let gap = value - resting
            parts.append(gap > 20
                ? "Your heart rate was still well above resting when you went to sleep, which usually means it took longer to wind down."
                : "Your heart rate was close to resting when you went to sleep, a good sign your body was winding down.")
        }
        if let earlier, earlier - value >= 3 {
            parts.append("It dropped \(Int((earlier - value).rounded())) bpm in the hour before sleep.")
        }
        if let average, value - average > 4 {
            parts.append("Higher than usual. Late meals, caffeine, screens, stress or evening workouts can raise it.")
        }
        return parts.joined(separator: " ")
    }
}
