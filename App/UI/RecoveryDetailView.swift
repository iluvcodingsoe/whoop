import SwiftUI

/// Recovery-Deep-Dive: Score, was ihn bestimmt, Vitalwerte gegen Baseline und Trends.
struct RecoveryDetailView: View {
    @Environment(AppModel.self) private var model
    @State private var range = 30

    var body: some View {
        DeepDiveScroll {
            VStack(alignment: .leading, spacing: 0) {
                if let recovery = model.recovery(for: model.selectedDayKey) {
                    hero(recovery)
                        .padding(.top, 8)

                    SectionHeading(text: model.loc("Was zählt", "What drove it"))
                    .id("drivers")
                        .padding(.top, 34)
                    contributorsPanel(recovery)
                        .padding(.top, 14)

                    SectionHeading(text: model.loc("Vitalwerte", "Vitals"))
                    .id("vitals")
                        .padding(.top, 34)
                    vitalsPanel
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
                        note: model.loc("Band = deine Baseline. Über dem Band ist gut, darunter deutet auf Belastung hin.",
                                        "Band = your baseline. Above the band is good, below points to stress or fatigue.")
                    )
                    .padding(.top, 14)

                    SectionHeading(text: model.loc("Ruhepuls", "Resting heart rate"))
                        .padding(.top, 34)
                    baselinePanel(
                        points: trendPoints(model.trend(range) { $0.restingHR }),
                        baseline: recovery.rhrBaseline,
                        isLog: false,
                        color: Theme.red,
                        note: model.loc("Ein Ruhepuls über deinem Band ist ein frühes Zeichen für Stress, Krankheit oder zu wenig Erholung.",
                                        "A resting heart rate above your band is an early sign of stress, illness or too little recovery.")
                    )
                    .padding(.top, 14)
                } else {
                    EmptyDataHint(text: model.loc("Keine Recovery-Daten für diesen Tag.", "No recovery data for this day."))
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(ScreenBackground())
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Kopf

    private func hero(_ recovery: RecoveryResult) -> some View {
        let color = Theme.recoveryColor(zone: recovery.zone)
        let target = StrainEngine.targetStrain(forRecovery: recovery.score)

        return VStack(spacing: 22) {
            DeepDiveHero(
                value: "\(recovery.score)",
                unit: "%",
                caption: "Recovery",
                fraction: Double(recovery.score) / 100,
                color: color
            )

            if recovery.calibrating {
                PillBadge(text: model.loc("Baseline kalibriert noch", "Baseline still calibrating"), color: Theme.yellow)
            }

            HStack(spacing: 12) {
                StatTile(
                    label: model.loc("Zone", "Zone"),
                    value: zoneName(recovery.zone),
                    sub: zoneRange(recovery.zone),
                    subColor: color
                )
                StatTile(
                    label: model.loc("Strain-Ziel", "Strain target"),
                    value: String(format: "%.1f", target),
                    sub: model.loc("für heute", "for today")
                )
            }

            Text(zoneText(recovery.zone))
                .font(.system(size: 17))
                .foregroundStyle(Theme.textPrimary.opacity(0.8))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func zoneName(_ zone: RecoveryZone) -> String {
        switch zone {
        case .green: return model.loc("Grün", "Green")
        case .yellow: return model.loc("Gelb", "Yellow")
        case .red: return model.loc("Rot", "Red")
        }
    }

    private func zoneRange(_ zone: RecoveryZone) -> String {
        switch zone {
        case .green: return "67–99 %"
        case .yellow: return "34–66 %"
        case .red: return "1–33 %"
        }
    }

    private func zoneText(_ zone: RecoveryZone) -> String {
        switch zone {
        case .green:
            return model.loc("Dein Körper ist gut erholt. Ein guter Tag für hartes Training oder einen Wettkampf.",
                             "Your body is well recovered. A good day for hard training or competing.")
        case .yellow:
            return model.loc("Du bist teilweise erholt. Moderates Training passt, hör auf deinen Körper.",
                             "You\u{2019}re partly recovered. Moderate training works, listen to your body.")
        case .red:
            return model.loc("Dein Körper braucht Ruhe. Leichte Bewegung und früher Schlaf helfen am meisten.",
                             "Your body needs rest. Light movement and an early night help most.")
        }
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
