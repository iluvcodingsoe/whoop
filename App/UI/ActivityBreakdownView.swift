import SwiftUI
import Charts

extension AppModel {
    /// Heart-rate breakdown of a time range, using the day before and after
    /// so windows across midnight still work.
    func activityAnalysis(start: Date, end: Date) -> ActivityAnalysis {
        let key = DayKey.string(from: start)
        let keys = [DayKey.addDays(key, -1), key, DayKey.addDays(key, 1)]
        let samples = keys.flatMap { store.days[$0]?.hrSamples ?? [] }
        let rhr = store.days[key]?.restingHR ?? store.days[DayKey.addDays(key, -1)]?.restingHR ?? 60
        return ActivityAnalysis.analyze(samples: samples, start: start, end: end, restingHR: rhr, maxHR: strainConfig.maxHR)
    }

    /// Stretching, breathwork, yoga and other calm activities.
    static func isCalmActivity(_ name: String) -> Bool {
        if ActivityCatalog.kind(named: name)?.section == .recovery { return true }
        let calm = ["yoga", "stretch", "meditat", "breath", "pilates", "mobility", "massage", "sauna"]
        return calm.contains { name.lowercased().contains($0) }
    }
}

let zonePalette: [Color] = [Theme.textSecondary, Theme.teal, Theme.green, Theme.yellow, Theme.orange, Theme.red]

/// Heart rate chart, zones and recovery or calm-down for one activity.
struct ActivityHeartRateSections: View {
    @Environment(AppModel.self) private var model
    let analysis: ActivityAnalysis
    let calm: Bool
    var name: String = "this activity"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !analysis.hasData {
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("No heart rate for this time", systemImage: "heart.slash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Pulse loads minute-by-minute heart rate for the last \(model.hrDaysBack) days. Sync again, or check that your Fitbit was worn.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                stats
                SectionHeading(text: "Heart Rate")
                    .padding(.top, 28)
                Panel(padding: 18) {
                    ActivityHRChart(analysis: analysis)
                }
                .padding(.top, 14)

                if calm {
                    SectionHeading(text: "Calm-Down")
                        .padding(.top, 28)
                    calmPanel
                        .padding(.top, 14)
                }

                SectionHeading(text: "Heart Rate Zones")
                    .padding(.top, 28)
                zonesPanel
                    .padding(.top, 14)

                if !calm, analysis.recovery1 != nil {
                    SectionHeading(text: "Heart Rate Recovery")
                        .padding(.top, 28)
                    recoveryPanel
                        .padding(.top, 14)
                }

                if let insight {
                    InsightCard(text: insight)
                        .padding(.top, 20)
                }
            }
        }
    }

    // MARK: Kennzahlen

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(label: "Avg HR", value: bpm(analysis.averageHR), unit: "bpm")
            StatTile(label: "Max HR", value: bpm(analysis.peakHR), unit: "bpm",
                     sub: analysis.peakEffort.map { "\(Int(($0 * 100).rounded()))% of reserve" })
            StatTile(label: "Lowest HR", value: bpm(analysis.lowestHR), unit: "bpm",
                     sub: analysis.lowestMinute.map { "at \(Int($0.rounded())) min" })
            StatTile(label: "Resting HR", value: bpm(analysis.restingHR), unit: "bpm", sub: "Today")
        }
    }

    private func bpm(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()))" } ?? "–"
    }

    // MARK: Ruhephase

    private var calmPanel: some View {
        let drop = zip2(analysis.startHR, analysis.endHR).map { $0 - $1 }
        let duration = max(analysis.durationMinutes, 1)
        return Panel(padding: 20) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        CapsLabel(text: "Start", color: Theme.textSecondary, size: 11)
                        Text(bpm(analysis.startHR))
                            .font(.system(size: 30, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        CapsLabel(text: "End", color: Theme.textSecondary, size: 11)
                        Text(bpm(analysis.endHR))
                            .font(.system(size: 30, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                .padding(.bottom, 14)
                PanelDivider()
                row("Change", drop.map { $0 >= 0 ? "−\(Int($0.rounded())) bpm" : "+\(Int((-$0).rounded())) bpm" } ?? "–",
                    color: (drop ?? 0) >= 3 ? Theme.green : Theme.textPrimary)
                PanelDivider()
                row("Trend", analysis.trendPerMinute.map { String(format: "%+.1f bpm per min", $0) } ?? "–")
                PanelDivider()
                row("Near resting", analysis.settleMinute.map { "after \(Int($0.rounded())) min" } ?? "Not reached")
                PanelDivider()
                row("Time calm", "\(Int(analysis.calmMinutes.rounded())) of \(Int(duration.rounded())) min")
                Text("Calm means within \(Int(ActivityAnalysis.calmMargin)) bpm of your resting heart rate (\(Int(analysis.calmThreshold.rounded())) bpm or lower).")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
        }
    }

    private func zip2(_ a: Double?, _ b: Double?) -> (Double, Double)? {
        guard let a, let b else { return nil }
        return (a, b)
    }

    // MARK: Zonen

    private var zonesPanel: some View {
        let total = max(analysis.durationMinutes, 1)
        return Panel(padding: 20) {
            VStack(spacing: 0) {
                ForEach((0..<6).reversed(), id: \.self) { index in
                    if index < 5 { PanelDivider() }
                    let minutes = analysis.zoneMinutes.indices.contains(index) ? analysis.zoneMinutes[index] : 0
                    HStack(spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(zonePalette[index]))
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(StrainEngine.zoneLabels[index])
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(range(index))
                                    .font(.system(size: 13).monospacedDigit())
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text("\(Int(minutes.rounded())) min")
                                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.07))
                                    Capsule().fill(zonePalette[index])
                                        .frame(width: minutes > 0 ? max(6, geo.size.width * CGFloat(min(minutes / total, 1))) : 0)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                    .padding(.vertical, 11)
                }
            }
        }
    }

    private func range(_ index: Int) -> String {
        let low = Int(analysis.zoneStart(index).rounded())
        if index == 5 { return "\(low)+" }
        return "\(low)–\(Int(analysis.zoneStart(index + 1).rounded()))"
    }

    // MARK: Erholung

    private var recoveryPanel: some View {
        Panel(padding: 20) {
            VStack(spacing: 0) {
                row("Heart rate at end", bpm(analysis.endHR).appending(" bpm"))
                PanelDivider()
                row("1 minute after", analysis.recovery1.map { dropText($0) } ?? "–", color: recoveryColor(analysis.recovery1))
                PanelDivider()
                row("2 minutes after", analysis.recovery2.map { dropText($0) } ?? "–")
                Text("A bigger drop in the first minute after hard effort usually means better fitness. 20+ bpm is strong, under 12 is low.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
        }
    }

    private func dropText(_ value: Double) -> String {
        value >= 0 ? "−\(Int(value.rounded())) bpm" : "+\(Int((-value).rounded())) bpm"
    }

    private func recoveryColor(_ value: Double?) -> Color {
        guard let value else { return Theme.textPrimary }
        if value >= 20 { return Theme.green }
        if value < 12 { return Theme.orange }
        return Theme.yellow
    }

    private func row(_ title: String, _ value: String, color: Color = Theme.textPrimary) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.vertical, 12)
    }

    // MARK: Fazit

    private var insight: String? {
        if calm {
            guard let start = analysis.startHR, let end = analysis.endHR else { return nil }
            let drop = Int((start - end).rounded())
            var text: String
            if drop >= 3 {
                text = "Your heart rate came down \(drop) bpm during \(name.lowercased())"
            } else if drop <= -3 {
                text = "Your heart rate rose \(-drop) bpm during \(name.lowercased()), so your body did not fully relax"
            } else {
                text = "Your heart rate stayed about the same during \(name.lowercased())"
            }
            if let settle = analysis.settleMinute {
                text += " and settled near resting after \(Int(settle.rounded())) min."
            } else {
                text += ". It stayed above \(Int(analysis.calmThreshold.rounded())) bpm, so try slower breathing or a longer hold."
            }
            return text
        }
        let hard = analysis.zoneMinutes.suffix(2).reduce(0, +)
        let share = hard / max(analysis.durationMinutes, 1)
        var text = "You spent \(Int(hard.rounded())) min in the Hard and Max zones (\(Int((share * 100).rounded()))% of the session)."
        if let r1 = analysis.recovery1 {
            text += r1 >= 20
                ? " Your heart rate dropped \(Int(r1.rounded())) bpm in the first minute after, a strong recovery."
                : " Your heart rate dropped \(Int(max(r1, 0).rounded())) bpm in the first minute after."
        }
        return text
    }
}

/// Heart rate over the activity, with a few minutes before and after.
struct ActivityHRChart: View {
    let analysis: ActivityAnalysis

    var body: some View {
        let values = analysis.window.map(\.bpm)
        let low = min(values.min() ?? 50, analysis.restingHR) - 6
        let high = (values.max() ?? 150) + 6
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                if let first = analysis.window.first?.t, first < analysis.start {
                    RectangleMark(xStart: .value("t", first), xEnd: .value("t", analysis.start), yStart: .value("bpm", low), yEnd: .value("bpm", high))
                        .foregroundStyle(Color.white.opacity(0.04))
                }
                if let last = analysis.window.last?.t, last > analysis.end {
                    RectangleMark(xStart: .value("t", analysis.end), xEnd: .value("t", last), yStart: .value("bpm", low), yEnd: .value("bpm", high))
                        .foregroundStyle(Color.white.opacity(0.04))
                }
                RuleMark(y: .value("Resting", analysis.restingHR))
                    .foregroundStyle(Theme.textSecondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Resting \(Int(analysis.restingHR.rounded()))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                ForEach(analysis.window, id: \.t) { sample in
                    LineMark(x: .value("Time", sample.t), y: .value("bpm", sample.bpm))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineStyle(StrokeStyle(lineWidth: 1.6))
                        .interpolationMethod(.monotone)
                }
                ForEach(analysis.during, id: \.t) { sample in
                    PointMark(x: .value("Time", sample.t), y: .value("bpm", sample.bpm))
                        .foregroundStyle(zonePalette[analysis.zone(for: sample.bpm) ?? 0])
                        .symbolSize(18)
                }
            }
            .chartYScale(domain: low...high)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel().foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(height: 220)

            HStack(spacing: 14) {
                legend(color: Color.white.opacity(0.75), text: "Heart rate")
                legend(color: Color.white.opacity(0.15), text: "Before and after")
                Spacer()
            }
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 8)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - Aktivitäts-Detail

/// Full activity page: strain, heart-rate breakdown and edit options.
struct ActivityBreakdownView: View {
    @Environment(AppModel.self) private var model
    let workout: Workout
    let dayKey: String
    var onChangeType: () -> Void
    var onLogExercises: () -> Void
    var onDelete: () -> Void

    @State private var start = Date()
    @State private var end = Date()

    private var isLogged: Bool { AppModel.loggedID(workout.id) != nil }

    var body: some View {
        let analysis = model.activityAnalysis(start: workout.start, end: workout.end)
        let calm = AppModel.isCalmActivity(workout.name)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ActivityHeartRateSections(analysis: analysis, calm: calm, name: workout.name)
                    .padding(.top, 20)
                manage
                    .padding(.top, 30)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            start = workout.start
            end = workout.end
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat((workout.strain ?? 0) / 21))
                    .stroke(Theme.strainBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(workout.strain.map { String(format: "%.1f", $0) } ?? "–")
                        .font(.system(size: 26, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                    Text("STRAIN")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(1.2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 6) {
                Label(workout.name, systemImage: ActivityCatalog.symbol(for: workout.name))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text("\(workout.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · \(Fmt.clock(workout.start)) – \(Fmt.clock(workout.end))")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(Int(workout.durationMinutes.rounded())) min\(workout.calories.map { " · \(Int($0.rounded())) kcal" } ?? "") · \(isLogged ? "Logged by you" : "Google Health")")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var manage: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(text: "Edit")
            if isLogged {
                Panel(padding: 18) {
                    VStack(spacing: 10) {
                        DatePicker("Start", selection: $start, in: ...Date())
                        DatePicker("End", selection: $end, in: start...Date())
                        Button("Save times") {
                            model.updateActivityTimes(workout.id, start: start, end: end, on: dayKey)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .foregroundStyle(Theme.textPrimary)
                }
                .padding(.top, 14)
            }
            VStack(spacing: 10) {
                action("Change activity type", symbol: "arrow.triangle.2.circlepath", run: onChangeType)
                action("Log exercises for muscular load", symbol: "dumbbell", run: onLogExercises)
                action("Delete activity", symbol: "trash", destructive: true, run: onDelete)
            }
            .padding(.top, 14)
            if !isLogged {
                Text("Deleting hides it in Pulse. It stays in Google Health and won\u{2019}t come back on the next sync.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 10)
            }
        }
    }

    private func action(_ title: String, symbol: String, destructive: Bool = false, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(destructive ? Theme.red : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}
