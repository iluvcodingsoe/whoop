import SwiftUI

/// Recovery-Deep-Dive: Score, was ihn bestimmt, Vitalwerte gegen Baseline und Trends.
struct RecoveryDetailView: View {
    @Environment(AppModel.self) private var model
    @State private var range = 30

    @State private var showTrends = false

    var body: some View {
        DeepDiveScroll {
            VStack(alignment: .leading, spacing: 0) {
                DetailHeader()
                if let recovery = model.recovery(for: model.selectedDayKey) {
                    BigRing(
                        value: "\(recovery.score)",
                        unit: "%",
                        label: "Recovery",
                        fraction: Double(recovery.score) / 100,
                        color: Theme.recoveryColor(zone: recovery.zone)
                    )
                    .padding(.top, 14)

                    ComparisonPanel(items: comparisonItems, footer: footerText)
                        .padding(.top, 18)

                    InsightCard(
                        text: insightText(recovery),
                        linkTitle: "Explore your trends",
                        action: { showTrends = true }
                    )
                    .padding(.top, 22)

                    if recovery.calibrating {
                        PillBadge(text: "Baseline still calibrating", color: Theme.yellow)
                            .padding(.top, 14)
                    }

                    SectionHeading(text: "What drove it")
                        .id("drivers")
                        .padding(.top, 34)
                    contributorsPanel(recovery)
                        .padding(.top, 14)

                    SectionHeading(text: "Trends")
                        .id("trends")
                        .padding(.top, 34)
                    trendPanel
                        .padding(.top, 14)

                    SectionHeading(text: "HRV")
                        .id("hrv")
                        .padding(.top, 34)
                    baselinePanel(
                        points: trendPoints(model.trend(range) { $0.hrvRmssd }),
                        baseline: recovery.hrvBaseline,
                        isLog: true,
                        color: Theme.accent,
                        note: "Band = your baseline. Above the band is good, below points to stress or fatigue."
                    )
                    .padding(.top, 14)

                    SectionHeading(text: "Resting heart rate")
                        .padding(.top, 34)
                    baselinePanel(
                        points: trendPoints(model.trend(range) { $0.restingHR }),
                        baseline: recovery.rhrBaseline,
                        isLog: false,
                        color: Theme.red,
                        note: "A resting heart rate above your band is an early sign of stress, illness or too little recovery."
                    )
                    .padding(.top, 14)
                } else {
                    EmptyDataHint(text: "No recovery data for this day.")
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(ScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showTrends) {
            TrendsView(embedded: true)
        }
    }

    private var footerText: String {
        let key = model.selectedDayKey
        let day = key == DayKey.today() ? "Today" : Fmt.dayShort(key)
        return "\(day) vs. last 30 days"
    }

    // MARK: - Vergleich mit 30 Tagen

    private var comparisonItems: [ComparisonItem] {
        let key = model.selectedDayKey
        let record = model.selectedRecord
        let sleep = model.sleep(for: key)
        let perf: Double? = (sleep?.hasData == true) ? sleep?.performance : nil
        let hrvAvg = model.average30(before: key) { $0.hrvRmssd }
        let rhrAvg = model.average30(before: key) { $0.restingHR }
        let respAvg = model.average30(before: key) { $0.respiratoryRate }
        let perfAvg = model.average30(before: key) { r in
            model.sleep(for: r.date).flatMap { $0.hasData ? $0.performance : nil }
        }

        return [
            ComparisonItem(id: "hrv", symbol: "waveform.path.ecg", title: "Heart rate variability",
                           value: record?.hrvRmssd.map { "\(Int($0.rounded()))" } ?? "–",
                           average: hrvAvg.map { "\(Int($0.rounded()))" },
                           direction: comparisonDirection(record?.hrvRmssd, hrvAvg), higherIsBetter: true),
            ComparisonItem(id: "rhr", symbol: "heart", title: "Resting heart rate",
                           value: record?.restingHR.map { "\(Int($0.rounded()))" } ?? "–",
                           average: rhrAvg.map { "\(Int($0.rounded()))" },
                           direction: comparisonDirection(record?.restingHR, rhrAvg), higherIsBetter: false),
            ComparisonItem(id: "resp", symbol: "lungs", title: "Respiratory rate",
                           value: record?.respiratoryRate.map { String(format: "%.1f", $0) } ?? "–",
                           average: respAvg.map { String(format: "%.1f", $0) },
                           direction: comparisonDirection(record?.respiratoryRate, respAvg), higherIsBetter: false),
            ComparisonItem(id: "sleep", symbol: "moon", title: "Sleep performance",
                           value: perf.map { "\(Int($0.rounded()))%" } ?? "–",
                           average: perfAvg.map { "\(Int($0.rounded()))%" },
                           direction: comparisonDirection(perf, perfAvg), higherIsBetter: true),
        ]
    }

    private func insightText(_ recovery: RecoveryResult) -> String {
        let key = model.selectedDayKey
        let zone: String
        switch recovery.zone {
        case .green: zone = "green"
        case .yellow: zone = "yellow"
        case .red: zone = "red"
        }
        let advice: String
        switch recovery.zone {
        case .green: advice = "Your body is ready to take on strain today."
        case .yellow: advice = "If you can, spend extra time on recovery today, like hydrating and eating well."
        case .red: advice = "Keep strain low today and make time for rest and an early night."
        }

        if let hrv = model.selectedRecord?.hrvRmssd, let avg = model.average30(before: key, { $0.hrvRmssd }), avg > 0 {
            let pct = Int(((hrv - avg) / avg * 100).rounded())
            if abs(pct) >= 3 {
                let dir = pct > 0 ? "above" : "below"
                return "Your HRV is \(abs(pct))% \(dir) its usual range, resulting in a \(zone) Recovery. \(advice)"
            }
            return "Your HRV is right in its usual range, resulting in a \(zone) Recovery. \(advice)"
        }
        return "You have a \(zone) Recovery. \(advice)"
    }

    // MARK: - Einflussfaktoren

    private func contributorsPanel(_ recovery: RecoveryResult) -> some View {
        Panel(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(recovery.components.enumerated()), id: \.element.key) { index, component in
                    if index > 0 { PanelDivider() }
                    ProgressRow(
                        title: recoveryComponentLabel(component.key, fallback: component.label, model.language),
                        value: "\(Int((component.score01 * 100).rounded()))",
                        fraction: component.score01,
                        color: componentColor(component.score01),
                        detail: component.detail(model.language)
                            + model.loc(" · Gewicht \(Int((component.weight * 100).rounded())) %", " · weight \(Int((component.weight * 100).rounded())) %")
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func componentColor(_ score: Double) -> Color {
        if score >= 0.62 { return Theme.green }
        if score >= 0.38 { return Theme.yellow }
        return Theme.red
    }

    // MARK: - Vitalwerte gegen Baseline

    private var vitalsPanel: some View {
        let statuses = model.healthStatuses

        return Panel(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(statuses.enumerated()), id: \.element.kind) { index, status in
                    if index > 0 { PanelDivider() }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(status.kind.label(model.language))
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            if let value = status.value, let avg = status.baseline?.mean {
                                HStack(spacing: 6) {
                                    VersusLabel(
                                        current: value,
                                        average: avg,
                                        higherIsBetter: status.kind == .hrv || status.kind == .spo2,
                                        format: status.kind == .hrv || status.kind == .restingHR ? "%.0f" : "%.1f",
                                        suffix: ""
                                    )
                                    Text(model.loc("vs. Ø \(status.kind.formatted(avg))", "vs. avg \(status.kind.formatted(avg))"))
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            } else {
                                Text(Theme.bandLabel(status.state))
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(status.value.map { status.kind.formatted($0) } ?? "–")
                                .font(.system(size: 24, weight: .bold).monospacedDigit())
                                .foregroundStyle(Theme.textPrimary)
                            Text(status.kind.unit(model.language))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Trends

    private var trendPanel: some View {
        let points = trendPoints(model.trend(range) { record in
            model.recovery(for: record.date).map { Double($0.score) }
        })
        let values = points.map(\.value)
        let avg = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        let green = values.filter { $0 >= 67 }.count
        let yellow = values.filter { $0 >= 34 && $0 < 67 }.count
        let red = values.filter { $0 < 34 }.count

        return Panel {
            VStack(alignment: .leading, spacing: 18) {
                RangePicker(days: $range)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        CapsLabel(text: model.loc("Ø Recovery", "Avg recovery"), color: Theme.textSecondary, size: 11)
                        Text(avg.map { "\(Int($0.rounded())) %" } ?? "–")
                            .font(.system(size: 28, weight: .bold).monospacedDigit())
                            .foregroundStyle(avg.map { Theme.recoveryColor(score: Int($0)) } ?? Theme.textPrimary)
                    }
                    Spacer()
                    HStack(spacing: 14) {
                        zoneCount(green, Theme.green)
                        zoneCount(yellow, Theme.yellow)
                        zoneCount(red, Theme.red)
                    }
                }
                if points.count >= 2 {
                    RecoveryBarsChart(points: points, height: 180)
                } else {
                    EmptyDataHint(text: model.loc("Noch zu wenige Tage für den Trend.", "Not enough days for a trend yet."))
                }
            }
        }
    }

    private func zoneCount(_ count: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
            Capsule().fill(color).frame(width: 22, height: 4)
        }
    }

    private func baselinePanel(points: [TrendPoint], baseline: Baseline?, isLog: Bool, color: Color, note: String) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                CapsLabel(text: model.loc("Letzte \(range) Tage", "Last \(range) days"), color: Theme.textSecondary, size: 12)
                if points.count >= 2 {
                    BaselineLineChart(points: points, baseline: baseline, color: color, isLogBaseline: isLog, height: 180)
                } else {
                    EmptyDataHint(text: model.loc("Noch zu wenige Werte.", "Not enough readings yet."))
                }
                Text(note)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
