import SwiftUI
import Charts

/// Sleep-Detailseite: Stunden und erholsamer Schlaf gegen den Schnitt, Herzfrequenz
/// im Schlaf, Phasen mit typischem Bereich, Kennzahlen gegen 30 Tage und Trends.
struct SleepDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var range = 7

    private let stageOrder: [SleepStage] = [.awake, .light, .deep, .rem]

    var body: some View {
        DeepDiveScroll {
            VStack(alignment: .leading, spacing: 0) {
                if let sleep = model.sleep(for: model.selectedDayKey), sleep.hasData {
                    header(sleep)

                    headline(sleep)
                        .padding(.top, 22)

                    Text(insightText(sleep))
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)

                    if let session = model.selectedRecord?.mainSleep {
                        sleepHRChart(session)
                            .padding(.top, 20)

                        SleepHeartRateStats(key: model.selectedDayKey)
                            .padding(.top, 14)

                        stageCards(sleep, session: session)
                            .id("stages")
                            .padding(.top, 18)

                        if !session.stages.isEmpty {
                            SectionHeading(text: "Stage timeline")
                                .padding(.top, 34)
                            Panel {
                                StagesTimelineView(session: session)
                            }
                            .padding(.top, 14)
                        }
                    }

                    HStack {
                        CapsLabel(text: "Sleep metrics", size: 14)
                        Spacer()
                        CapsLabel(text: "vs. 30 day avg", color: Theme.textSecondary, size: 12)
                    }
                    .id("performance")
                    .padding(.top, 34)
                    ComparisonPanel(items: metricItems(sleep), footer: footerText, pointer: false)
                        .padding(.top, 12)

                    if let record = model.selectedRecord, !record.naps.isEmpty {
                        SectionHeading(text: "Naps")
                            .padding(.top, 34)
                        napsPanel(record.naps)
                            .padding(.top, 14)
                    }

                    SectionHeading(text: "Trends")
                        .id("vitals")
                        .padding(.top, 34)
                    trendPanel
                        .padding(.top, 14)
                } else {
                    DetailHeader(title: "Sleep")
                    EmptyDataHint(text: "No sleep recorded for this day.")
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(ScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var footerText: String {
        let key = model.selectedDayKey
        let day = key == DayKey.today() ? "Today" : Fmt.dayShort(key)
        return "\(day) vs. last 30 days"
    }

    // MARK: - Kopf

    private func header(_ sleep: SleepAnalysis) -> some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            Image(systemName: "moon")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.textPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text("SLEEP")
                    .font(.system(size: 16, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(Theme.textPrimary)
                if let bed = sleep.bedTime, let wake = sleep.wakeTime {
                    Text("\(Fmt.clock(bed)) to \(Fmt.clock(wake))")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
        }
        .frame(height: 56)
    }

    /// Stunden Schlaf und erholsamer Schlaf, jeweils mit 30-Tage-Schnitt.
    private func headline(_ sleep: SleepAnalysis) -> some View {
        let key = model.selectedDayKey
        let sleptAvg = model.average30(before: key) { r in
            model.sleep(for: r.date).flatMap { $0.hasData ? $0.sleptMinutes : nil }
        }
        let restAvg = model.average30(before: key) { r in
            model.sleep(for: r.date).flatMap { $0.hasData ? $0.restorativeMinutes : nil }
        }

        return HStack(alignment: .top, spacing: 18) {
            bigNumber(Fmt.hm(sleep.sleptMinutes), color: Theme.sleepPurple, average: sleptAvg, current: sleep.sleptMinutes, label: "Hours of sleep")
            bigNumber(Fmt.hm(sleep.restorativeMinutes), color: Theme.textPrimary, average: restAvg, current: sleep.restorativeMinutes, label: "Restorative sleep")
            Spacer(minLength: 0)
        }
    }

    private func bigNumber(_ value: String, color: Color, average: Double?, current: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text(value)
                    .font(.system(size: 42, weight: .bold).monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .fixedSize()
                if let average {
                    HStack(spacing: 3) {
                        Image(systemName: current >= average ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                        Text(Fmt.hm(average))
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    }
                    .fixedSize()
                    .foregroundStyle(Theme.textPrimary.opacity(0.75))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                }
            }
            Text(label.uppercased())
                .font(.system(size: 13, weight: .bold))
                .kerning(1.6)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Hinweis

    /// Phasenanteil in Prozent der Zeit im Bett.
    private func stagePercents(_ minutes: [SleepStage: Double]) -> [SleepStage: Double] {
        let total = stageOrder.reduce(0) { $0 + (minutes[$1] ?? 0) }
        guard total > 0 else { return [:] }
        var result: [SleepStage: Double] = [:]
        for stage in stageOrder { result[stage] = (minutes[stage] ?? 0) / total * 100 }
        return result
    }

    /// Typischer Bereich je Phase: Mittelwert ± 1 Standardabweichung der letzten 30 Nächte.
    private var typicalRanges: [SleepStage: ClosedRange<Double>] {
        let key = model.selectedDayKey
        let keys = DayKey.keys(from: DayKey.addDays(key, -30), to: DayKey.addDays(key, -1))
        var values: [SleepStage: [Double]] = [:]
        for k in keys {
            guard let s = model.sleep(for: k), s.hasData else { continue }
            for (stage, pct) in stagePercents(s.stageMinutes) { values[stage, default: []].append(pct) }
        }
        var result: [SleepStage: ClosedRange<Double>] = [:]
        for (stage, list) in values where list.count >= 3 {
            let mean = list.reduce(0, +) / Double(list.count)
            let sd = sqrt(list.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(list.count))
            result[stage] = max(0, mean - sd)...min(100, mean + max(sd, 1))
        }
        return result
    }

    private func insightText(_ sleep: SleepAnalysis) -> String {
        let pct = stagePercents(sleep.stageMinutes)
        let ranges = typicalRanges
        // Phase, die am weitesten außerhalb ihres typischen Bereichs liegt.
        var best: (stage: SleepStage, diff: Double)?
        for stage in [SleepStage.rem, .deep, .awake] {
            guard let p = pct[stage], let r = ranges[stage] else { continue }
            let diff = p > r.upperBound ? p - r.upperBound : (p < r.lowerBound ? p - r.lowerBound : 0)
            if diff != 0, abs(diff) > abs(best?.diff ?? 0) { best = (stage, diff) }
        }
        if let best, let p = pct[best.stage] {
            let share = "\(Int(p.rounded()))% of your time in bed was spent in \(stageWord(best.stage))."
            switch (best.stage, best.diff > 0) {
            case (.rem, true): return share + " This might mean your body is making up for missed REM sleep recently."
            case (.rem, false): return share + " That\u{2019}s less than usual. A consistent bedtime helps you get more REM."
            case (.deep, true): return share + " Your body is putting extra effort into physical recovery."
            case (.deep, false): return share + " That\u{2019}s less than usual. Late meals, alcohol and screens can cut deep sleep."
            case (.awake, true): return share + " You woke up more than usual. Caffeine, stress or a warm room can cause this."
            default: return share + " That\u{2019}s less time awake than usual."
            }
        }
        let short = sleep.needMinutes - sleep.sleptMinutes
        if short > 10 {
            return "You got \(Fmt.hm(sleep.sleptMinutes)) of the \(Fmt.hm(sleep.needMinutes)) hours your body needed. An earlier bedtime tonight helps you catch up."
        }
        return "Your sleep stages were in their usual ranges and you covered your sleep need."
    }

    private func stageWord(_ stage: SleepStage) -> String {
        switch stage {
        case .awake: return "an awake state"
        case .light: return "light sleep"
        case .deep: return "deep sleep"
        case .rem: return "REM sleep"
        case .unknown: return "sleep"
        }
    }

    // MARK: - Herzfrequenz im Schlaf

    private func sleepHRChart(_ session: SleepSession) -> some View {
        let key = model.selectedDayKey
        let padding: TimeInterval = 25 * 60
        let from = session.start.addingTimeInterval(-padding)
        let to = session.end.addingTimeInterval(padding)
        let samples = ((model.record(for: DayKey.addDays(key, -1))?.hrSamples ?? []) + (model.record(for: key)?.hrSamples ?? []))
            .filter { $0.t >= from && $0.t <= to }
            .sorted { $0.t < $1.t }

        return VStack(spacing: 6) {
            if samples.count >= 10 {
                Chart {
                    ForEach(samples, id: \.t) { sample in
                        LineMark(x: .value("Time", sample.t), y: .value("BPM", sample.bpm))
                            .foregroundStyle(Theme.sleepPurple)
                            .lineStyle(StrokeStyle(lineWidth: 1.2))
                    }
                    RuleMark(x: .value("Start", session.start))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    RuleMark(x: .value("End", session.end))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                .chartXScale(domain: from...to)
                .chartYScale(domain: max(0, (samples.map(\.bpm).min() ?? 40) - 8)...((samples.map(\.bpm).max() ?? 100) + 8))
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel().foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(height: 210)
                .background(
                    LinearGradient(colors: [Color.white.opacity(0.04), .clear], startPoint: .top, endPoint: .bottom)
                )

                GeometryReader { geo in
                    let total = to.timeIntervalSince(from)
                    let x1 = geo.size.width * CGFloat(session.start.timeIntervalSince(from) / total)
                    let x2 = geo.size.width * CGFloat(session.end.timeIntervalSince(from) / total)
                    ZStack(alignment: .topLeading) {
                        Text(Fmt.clock(session.start))
                            .position(x: max(28, x1), y: 8)
                        Text(Fmt.clock(session.end))
                            .position(x: min(geo.size.width - 28, x2), y: 8)
                    }
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                }
                .frame(height: 18)
            } else {
                Panel {
                    Text("No heart rate data during this sleep.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    // MARK: - Phasen

    private func stageCards(_ sleep: SleepAnalysis, session: SleepSession) -> some View {
        let pct = stagePercents(sleep.stageMinutes)
        let ranges = typicalRanges
        let inBed = stageOrder.reduce(0) { $0 + (sleep.stageMinutes[$1] ?? 0) }

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Theme.textSecondary, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: 16, height: 16)
                CapsLabel(text: "Typical range", color: Theme.textSecondary, size: 12)
                Spacer()
                CapsLabel(text: "Duration", color: Theme.textSecondary, size: 12)
                Text(Fmt.hm(inBed))
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.bottom, 4)

            ForEach(stageOrder, id: \.self) { stage in
                StageBarCard(
                    name: stage == .deep ? "Deep" : Theme.stageName(stage),
                    percent: pct[stage] ?? 0,
                    minutes: sleep.stageMinutes[stage] ?? 0,
                    color: Theme.stageColor(stage),
                    typical: ranges[stage]
                )
            }
        }
    }

    // MARK: - Kennzahlen

    private func metricItems(_ sleep: SleepAnalysis) -> [ComparisonItem] {
        let key = model.selectedDayKey
        func avg(_ f: @escaping (SleepAnalysis) -> Double?) -> Double? {
            model.average30(before: key) { r in model.sleep(for: r.date).flatMap { $0.hasData ? f($0) : nil } }
        }
        let sufficiency: (SleepAnalysis) -> Double? = { s in s.needMinutes > 0 ? min(100, s.sleptMinutes / s.needMinutes * 100) : nil }
        let perfAvg = avg { $0.performance }
        let suffAvg = avg(sufficiency)
        let consAvg = avg { $0.consistency }
        let effAvg = avg { $0.efficiency }
        let debtAvg = avg { $0.debtAfterMinutes }
        let respAvg = model.average30(before: key) { $0.respiratoryRate }
        let resp = model.selectedRecord?.respiratoryRate
        let suff = sufficiency(sleep)

        func pct(_ v: Double?) -> String { v.map { "\(Int($0.rounded()))%" } ?? "–" }

        return [
            ComparisonItem(id: "perf", symbol: "moon", title: "Sleep performance",
                           value: pct(sleep.performance), average: perfAvg.map { pct($0) },
                           direction: comparisonDirection(sleep.performance, perfAvg), higherIsBetter: true),
            ComparisonItem(id: "suff", symbol: "bed.double", title: "Hours vs. needed",
                           value: pct(suff), average: suffAvg.map { pct($0) },
                           direction: comparisonDirection(suff, suffAvg), higherIsBetter: true),
            ComparisonItem(id: "cons", symbol: "clock.arrow.circlepath", title: "Sleep consistency",
                           value: pct(sleep.consistency), average: consAvg.map { pct($0) },
                           direction: comparisonDirection(sleep.consistency, consAvg), higherIsBetter: true),
            ComparisonItem(id: "eff", symbol: "gauge.with.dots.needle.67percent", title: "Sleep efficiency",
                           value: pct(sleep.efficiency), average: effAvg.map { pct($0) },
                           direction: comparisonDirection(sleep.efficiency, effAvg), higherIsBetter: true),
            ComparisonItem(id: "debt", symbol: "hourglass", title: "Sleep debt",
                           value: Fmt.hm(sleep.debtAfterMinutes), average: debtAvg.map { Fmt.hm($0) },
                           direction: comparisonDirection(sleep.debtAfterMinutes, debtAvg), higherIsBetter: false),
            ComparisonItem(id: "resp", symbol: "lungs", title: "Respiratory rate",
                           value: resp.map { String(format: "%.1f", $0) } ?? "–", average: respAvg.map { String(format: "%.1f", $0) },
                           direction: comparisonDirection(resp, respAvg), higherIsBetter: false),
        ]
    }

    // MARK: - Nickerchen

    private func napsPanel(_ naps: [SleepSession]) -> some View {
        Panel(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(naps.enumerated()), id: \.element.id) { index, nap in
                    if index > 0 { PanelDivider() }
                    MetricRow(
                        symbol: "powersleep",
                        title: "Nap",
                        subtitle: "\(Fmt.clock(nap.start)) – \(Fmt.clock(nap.end))",
                        value: "\(Int(nap.minutesAsleep.rounded()))",
                        unit: "min",
                        showChevron: false
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Trend

    private var trendPanel: some View {
        let slept = trendPoints(model.trend(range) { record in
            model.sleep(for: record.date)?.hasData == true ? model.sleep(for: record.date)?.sleptMinutes : nil
        })
        let need = trendPoints(model.trend(range) { record in
            model.sleep(for: record.date)?.needMinutes
        })
        let perf = model.trend(range) { record in
            model.sleep(for: record.date)?.hasData == true ? model.sleep(for: record.date)?.performance : nil
        }.map(\.value)
        let avgSlept = slept.isEmpty ? nil : slept.map(\.value).reduce(0, +) / Double(slept.count)
        let avgPerf = perf.isEmpty ? nil : perf.reduce(0, +) / Double(perf.count)

        return Panel {
            VStack(alignment: .leading, spacing: 18) {
                RangePicker(days: $range)
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        CapsLabel(text: "Avg sleep", color: Theme.textSecondary, size: 11)
                        Text(avgSlept.map { "\(Fmt.hm($0)) h" } ?? "–")
                            .font(.system(size: 24, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        CapsLabel(text: "Avg performance", color: Theme.textSecondary, size: 11)
                        Text(avgPerf.map { "\(Int($0.rounded())) %" } ?? "–")
                            .font(.system(size: 24, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                if slept.count >= 2 {
                    SleepTrendChart(slept: slept, need: need, barUnit: .day, height: 180)
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.sleepPurple).frame(width: 10, height: 10)
                            Text("Slept")
                        }
                        HStack(spacing: 6) {
                            Capsule().fill(.white.opacity(0.7)).frame(width: 14, height: 2)
                            Text("Need")
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                } else {
                    EmptyDataHint(text: "Not enough nights for a trend yet.")
                }
            }
        }
    }
}

// MARK: - Phasen-Karte

/// Karte einer Schlafphase: Name, Anteil, Dauer und Balken auf schraffiertem Grund
/// mit gestricheltem typischem Bereich.
struct StageBarCard: View {
    let name: String
    let percent: Double
    let minutes: Double
    let color: Color
    let typical: ClosedRange<Double>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name.uppercased())
                    .font(.system(size: 15, weight: .bold))
                    .kerning(1.4)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(Int(percent.rounded()))%")
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(color)
                Spacer()
                Text(Fmt.hm(minutes))
                    .font(.system(size: 20, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
            }
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    HatchPattern()
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(8, w * CGFloat(min(percent, 100) / 100)))
                    if let typical {
                        let x = w * CGFloat(typical.lowerBound / 100)
                        let width = max(10, w * CGFloat((typical.upperBound - typical.lowerBound) / 100))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                            )
                            .frame(width: width, height: 26)
                            .offset(x: x)
                    }
                }
            }
            .frame(height: 22)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
    }
}

/// Schräge Schraffur für die leere Spur der Phasenbalken.
struct HatchPattern: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(0.04)))
            var path = Path()
            var x: CGFloat = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 6
            }
            context.stroke(path, with: .color(Color.white.opacity(0.10)), lineWidth: 1.5)
        }
    }
}
