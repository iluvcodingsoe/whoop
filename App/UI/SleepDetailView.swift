import SwiftUI

/// Sleep-Deep-Dive: Leistung, Phasen, Kennzahlen, Vitalwerte im Schlaf und Trend.
struct SleepDetailView: View {
    @Environment(AppModel.self) private var model
    @State private var range = 7

    var body: some View {
        DeepDiveScroll {
            VStack(alignment: .leading, spacing: 0) {
                if let sleep = model.sleep(for: model.selectedDayKey), sleep.hasData {
                    hero(sleep)
                        .padding(.top, 8)

                    if let session = model.selectedRecord?.mainSleep, !session.stages.isEmpty {
                        SectionHeading(text: model.loc("Schlafphasen", "Sleep stages"))
                    .id("stages")
                            .padding(.top, 34)
                        stagesPanel(sleep, session: session)
                            .padding(.top, 14)
                    }

                    SectionHeading(text: model.loc("Schlafleistung", "Sleep performance"))
                    .id("performance")
                        .padding(.top, 34)
                    performancePanel(sleep)
                        .padding(.top, 14)

                    SectionHeading(text: model.loc("Im Schlaf", "While you slept"))
                    .id("vitals")
                        .padding(.top, 34)
                    vitalsGrid
                        .padding(.top, 14)

                    if let record = model.selectedRecord, !record.naps.isEmpty {
                        SectionHeading(text: model.loc("Nickerchen", "Naps"))
                            .padding(.top, 34)
                        napsPanel(record.naps)
                            .padding(.top, 14)
                    }

                    SectionHeading(text: "Trends")
                    .id("trends")
                        .padding(.top, 34)
                    trendPanel
                        .padding(.top, 14)
                } else {
                    EmptyDataHint(text: model.loc("Kein Schlaf für diesen Tag erfasst.", "No sleep recorded for this day."))
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(ScreenBackground())
        .navigationTitle(model.loc("Schlaf", "Sleep"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Kopf

    private func hero(_ sleep: SleepAnalysis) -> some View {
        VStack(spacing: 22) {
            DeepDiveHero(
                value: "\(Int(sleep.performance.rounded()))",
                unit: "%",
                caption: model.loc("Schlafleistung", "Sleep performance"),
                fraction: sleep.performance / 100,
                color: Theme.sleepPurple
            )

            HStack(spacing: 12) {
                StatTile(
                    label: model.loc("Geschlafen", "Hours of sleep"),
                    value: Fmt.hm(sleep.sleptMinutes),
                    unit: "h",
                    sub: model.loc("Bedarf \(Fmt.hm(sleep.needMinutes)) h", "Need \(Fmt.hm(sleep.needMinutes)) h")
                )
                StatTile(
                    label: model.loc("Im Bett", "In bed"),
                    value: sleep.bedTime.map { Fmt.clock($0) } ?? "–",
                    sub: sleep.wakeTime.map { model.loc("Auf \(Fmt.clock($0))", "Woke \(Fmt.clock($0))") }
                )
            }

            Text(summary(sleep))
                .font(.system(size: 17))
                .foregroundStyle(Theme.textPrimary.opacity(0.8))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summary(_ sleep: SleepAnalysis) -> String {
        let short = sleep.needMinutes - sleep.sleptMinutes
        if short <= 10 {
            return model.loc("Du hast deinen Schlafbedarf gedeckt. Dein Körper hatte alles, was er zur Erholung braucht.",
                             "You met your sleep need. Your body got what it needed to recover.")
        }
        return model.loc("Dir haben \(Fmt.hm(short)) h zu deinem Bedarf gefehlt. Eine frühere Bettzeit heute hilft beim Aufholen.",
                         "You were \(Fmt.hm(short)) h short of your need. An earlier bedtime tonight helps you catch up.")
    }

    // MARK: - Phasen

    private func stagesPanel(_ sleep: SleepAnalysis, session: SleepSession) -> some View {
        let order: [SleepStage] = [.awake, .light, .deep, .rem]
        let total = max(1, order.reduce(0) { $0 + (sleep.stageMinutes[$1] ?? 0) })

        return Panel(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                StagesTimelineView(session: session)
                    .padding(20)

                // Gestapelter Balken mit dem Anteil jeder Phase.
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(order, id: \.self) { stage in
                            let minutes = sleep.stageMinutes[stage] ?? 0
                            if minutes > 0 {
                                Rectangle()
                                    .fill(Theme.stageColor(stage))
                                    .frame(width: max(2, geo.size.width * CGFloat(minutes / total) - 2))
                            }
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

                ForEach(order, id: \.self) { stage in
                    let minutes = sleep.stageMinutes[stage] ?? 0
                    PanelDivider().padding(.horizontal, 20)
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Theme.stageColor(stage))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Theme.stageName(stage))
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Text(stageNote(stage))
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Fmt.hm(minutes)) h")
                                .font(.system(size: 18, weight: .bold).monospacedDigit())
                                .foregroundStyle(Theme.textPrimary)
                            Text("\(Int((minutes / total * 100).rounded())) %")
                                .font(.system(size: 13).monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private func stageNote(_ stage: SleepStage) -> String {
        switch stage {
        case .awake: return model.loc("Kurzes Aufwachen ist normal", "Brief wake-ups are normal")
        case .light: return model.loc("Übergang zwischen den Phasen", "Transition between stages")
        case .deep: return model.loc("Körperliche Erholung, Muskelaufbau", "Physical recovery and muscle repair")
        case .rem: return model.loc("Mentale Erholung, Gedächtnis", "Mental recovery and memory")
        case .unknown: return ""
        }
    }

    // MARK: - Leistung

    private func performancePanel(_ sleep: SleepAnalysis) -> some View {
        let sufficiency = sleep.needMinutes > 0 ? min(100, sleep.sleptMinutes / sleep.needMinutes * 100) : 0
        let restorativePct = sleep.sleptMinutes > 0 ? sleep.restorativeMinutes / sleep.sleptMinutes * 100 : 0

        return Panel(padding: 0) {
            VStack(spacing: 0) {
                ProgressRow(
                    title: model.loc("Stunden vs. Bedarf", "Hours vs. needed"),
                    value: "\(Int(sufficiency.rounded())) %",
                    fraction: sufficiency / 100,
                    color: percentColor(sufficiency),
                    detail: "\(Fmt.hm(sleep.sleptMinutes)) / \(Fmt.hm(sleep.needMinutes)) h"
                )
                PanelDivider()
                ProgressRow(
                    title: model.loc("Konsistenz", "Sleep consistency"),
                    value: sleep.consistency.map { "\(Int($0.rounded())) %" } ?? "–",
                    fraction: (sleep.consistency ?? 0) / 100,
                    color: percentColor(sleep.consistency ?? 0),
                    detail: model.loc("Wie gleich deine Bett- und Aufstehzeiten sind", "How regular your bed and wake times are")
                )
                PanelDivider()
                ProgressRow(
                    title: model.loc("Effizienz", "Sleep efficiency"),
                    value: sleep.efficiency.map { "\(Int($0.rounded())) %" } ?? "–",
                    fraction: (sleep.efficiency ?? 0) / 100,
                    color: percentColor(sleep.efficiency ?? 0),
                    detail: model.loc("Anteil der Zeit im Bett, in der du geschlafen hast", "Share of your time in bed spent asleep")
                )
                PanelDivider()
                ProgressRow(
                    title: model.loc("Erholsamer Schlaf", "Restorative sleep"),
                    value: "\(Int(restorativePct.rounded())) %",
                    fraction: restorativePct / 50,
                    color: restorativePct >= 40 ? Theme.green : restorativePct >= 30 ? Theme.yellow : Theme.red,
                    detail: model.loc("Tief + REM: \(Fmt.hm(sleep.restorativeMinutes)) h · Ziel über 40 %", "Deep + REM: \(Fmt.hm(sleep.restorativeMinutes)) h · aim for over 40 %")
                )
                PanelDivider()
                ProgressRow(
                    title: model.loc("Schlafschuld", "Sleep debt"),
                    value: "\(Fmt.hm(sleep.debtAfterMinutes)) h",
                    fraction: sleep.debtAfterMinutes / 180,
                    color: sleep.debtAfterMinutes <= 30 ? Theme.green : sleep.debtAfterMinutes <= 90 ? Theme.yellow : Theme.red,
                    detail: model.loc("Fehlender Schlaf der letzten Nächte", "Sleep you still owe from recent nights")
                )
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Vitalwerte im Schlaf

    private var vitalsGrid: some View {
        let record = model.selectedRecord
        let statuses = Dictionary(uniqueKeysWithValues: model.healthStatuses.map { ($0.kind, $0) })

        func tile(_ kind: HealthMetricKind, _ value: Double?, label: String, higherIsBetter: Bool) -> some View {
            let avg = statuses[kind]?.baseline?.mean
            return VStack(alignment: .leading, spacing: 6) {
                CapsLabel(text: label, color: Theme.textSecondary, size: 11)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value.map { kind.formatted($0) } ?? "–")
                        .font(.system(size: 26, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                    Text(kind.unit(model.language))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                if let value, let avg {
                    HStack(spacing: 6) {
                        VersusLabel(current: value, average: avg, higherIsBetter: higherIsBetter, format: kind == .respiratoryRate ? "%.1f" : "%.0f", suffix: "")
                        Text(model.loc("vs. Ø \(kind.formatted(avg))", "vs. avg \(kind.formatted(avg))"))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    Text(" ").font(.system(size: 13))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        }

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tile(.hrv, record?.hrvRmssd, label: "HRV", higherIsBetter: true)
            tile(.restingHR, record?.restingHR, label: model.loc("Ruhepuls", "Resting HR"), higherIsBetter: false)
            tile(.respiratoryRate, record?.respiratoryRate, label: model.loc("Atemfrequenz", "Resp. rate"), higherIsBetter: false)
            tile(.spo2, record?.spo2Avg, label: model.loc("Blut-O₂", "Blood O₂"), higherIsBetter: true)
        }
    }

    // MARK: - Nickerchen

    private func napsPanel(_ naps: [SleepSession]) -> some View {
        Panel(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(naps.enumerated()), id: \.element.id) { index, nap in
                    if index > 0 { PanelDivider() }
                    MetricRow(
                        symbol: "powersleep",
                        title: model.loc("Nickerchen", "Nap"),
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
                        CapsLabel(text: model.loc("Ø Schlaf", "Avg sleep"), color: Theme.textSecondary, size: 11)
                        Text(avgSlept.map { "\(Fmt.hm($0)) h" } ?? "–")
                            .font(.system(size: 24, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        CapsLabel(text: model.loc("Ø Leistung", "Avg performance"), color: Theme.textSecondary, size: 11)
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
                            Text(model.loc("Geschlafen", "Slept"))
                        }
                        HStack(spacing: 6) {
                            Capsule().fill(.white.opacity(0.7)).frame(width: 14, height: 2)
                            Text(model.loc("Bedarf", "Need"))
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                } else {
                    EmptyDataHint(text: model.loc("Noch zu wenige Nächte für den Trend.", "Not enough nights for a trend yet."))
                }
            }
        }
    }
}
