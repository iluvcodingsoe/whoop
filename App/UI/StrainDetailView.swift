import SwiftUI

/// Strain-Deep-Dive: Score gegen Tagesziel, Herzfrequenz-Zonen, Aktivitäten, Tagesverlauf und Trend.
struct StrainDetailView: View {
    @Environment(AppModel.self) private var model
    @State private var range = 7

    var body: some View {
        DeepDiveScroll {
            VStack(alignment: .leading, spacing: 0) {
                DetailHeader()
                if let strain = model.strain(for: model.selectedDayKey) {
                    BigRing(
                        value: String(format: "%.1f", strain.strain),
                        unit: "",
                        label: "Strain",
                        fraction: strain.strain / 21,
                        color: Theme.strainBlue,
                        marker: targetStrain.map { $0 / 21 }
                    )
                    .padding(.top, 14)

                    ComparisonPanel(items: comparisonItems(strain), footer: footerText)
                        .padding(.top, 18)

                    InsightCard(text: insightText(strain))
                        .padding(.top, 22)

                    SectionHeading(text: "Activities")
                        .id("activities")
                        .padding(.top, 34)
                    activitiesPanel
                        .padding(.top, 14)

                    SectionHeading(text: "Heart rate zones")
                        .id("zones")
                        .padding(.top, 34)
                    zonesPanel(strain)
                        .padding(.top, 14)

                    if let record = model.selectedRecord, !record.hrSamples.isEmpty {
                        SectionHeading(text: "Heart rate")
                            .padding(.top, 34)
                        Panel {
                            HRDayChart(samples: record.hrSamples)
                        }
                        .padding(.top, 14)
                    }

                    SectionHeading(text: "Trends")
                        .id("trends")
                        .padding(.top, 34)
                    trendPanel
                        .padding(.top, 14)
                } else {
                    EmptyDataHint(text: "No strain data for this day.")
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

    private static func isStrength(_ workout: Workout) -> Bool {
        let n = workout.name.lowercased()
        return ["strength", "weight", "kraft", "gym", "lifting", "functional", "crossfit", "hiit"].contains { n.contains($0) }
    }

    private func comparisonItems(_ strain: StrainResult) -> [ComparisonItem] {
        let key = model.selectedDayKey
        func low(_ s: StrainResult) -> Double { s.zoneMinutes.prefix(3).reduce(0, +) }
        func high(_ s: StrainResult) -> Double { s.zoneMinutes.dropFirst(3).reduce(0, +) }
        func strength(_ r: DayRecord) -> Double {
            r.workouts.filter(Self.isStrength).reduce(0) { $0 + $1.durationMinutes }
        }
        let record = model.selectedRecord
        let lowAvg = model.average30(before: key) { r in model.strain(for: r.date).map(low) }
        let highAvg = model.average30(before: key) { r in model.strain(for: r.date).map(high) }
        let strengthAvg = model.average30(before: key) { r in strength(r) }
        let stepsAvg = model.average30(before: key) { r in r.steps.map(Double.init) }
        let todayStrength = record.map(strength)
        let steps = record?.steps.map(Double.init)

        return [
            ComparisonItem(id: "z13", symbol: "heart", title: "Heart rate zones 1–3",
                           value: Fmt.hm(low(strain)), average: lowAvg.map { Fmt.hm($0) },
                           direction: comparisonDirection(low(strain), lowAvg), higherIsBetter: true),
            ComparisonItem(id: "z45", symbol: "heart.fill", title: "Heart rate zones 4–5",
                           value: Fmt.hm(high(strain)), average: highAvg.map { Fmt.hm($0) },
                           direction: comparisonDirection(high(strain), highAvg), higherIsBetter: true),
            ComparisonItem(id: "strength", symbol: "dumbbell", title: "Strength activity time",
                           value: Fmt.hm(todayStrength ?? 0), average: strengthAvg.map { Fmt.hm($0) },
                           direction: comparisonDirection(todayStrength, strengthAvg), higherIsBetter: true),
            ComparisonItem(id: "steps", symbol: "shoeprints.fill", title: "Steps",
                           value: steps.map { Int($0).formatted(.number) } ?? "–",
                           average: stepsAvg.map { Int($0.rounded()).formatted(.number) },
                           direction: comparisonDirection(steps, stepsAvg), higherIsBetter: true),
        ]
    }

    private func insightText(_ strain: StrainResult) -> String {
        let value = strain.strain
        var text: String
        switch value {
        case ..<10:
            text = "Strain under 10 is considered light. Your body had an easy day, which helps it recover."
        case ..<14:
            text = "Strain between 10 and 13.9 is considered moderate. You kept a steady level of activity."
        case ..<18:
            text = "Strain between 14 and 17.9 is considered strenuous. Your cardiovascular system has been working hard."
        default:
            text = "Strain of 18 or more is considered all out. Plan for extra sleep and recovery."
        }
        if let target = targetStrain {
            let diff = value - target
            if diff >= 1 {
                text += " You\u{2019}re past your target of \(String(format: "%.1f", target)), so prioritise sleep tonight."
            } else if diff >= -1 {
                text += " You\u{2019}re right on your target of \(String(format: "%.1f", target))."
            } else {
                text += " Your target for the day is \(String(format: "%.1f", target))."
            }
        }
        return text
    }

    private var targetStrain: Double? {
        model.recovery(for: model.selectedDayKey).map { StrainEngine.targetStrain(forRecovery: $0.score) }
    }

    // MARK: - Kopf

    private func hero(_ strain: StrainResult) -> some View {
        let record = model.selectedRecord
        let calories = model.allWorkouts(for: model.selectedDayKey).compactMap(\.calories).reduce(0, +)

        return VStack(spacing: 22) {
            DeepDiveHero(
                value: String(format: "%.1f", strain.strain),
                unit: "",
                caption: model.loc("Strain von 21", "Strain of 21"),
                fraction: strain.strain / 21,
                color: Theme.strainBlue,
                marker: targetStrain.map { $0 / 21 }
            )

            if let target = targetStrain {
                targetBar(strain.strain, target: target)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                StatTile(label: model.loc("Ø Puls", "Avg HR"), value: strain.avgHR.map { "\(Int($0.rounded()))" } ?? "–", unit: "bpm")
                StatTile(label: model.loc("Max. Puls", "Max HR"), value: strain.peakHR.map { "\(Int($0.rounded()))" } ?? "–", unit: "bpm")
                StatTile(label: model.loc("Kalorien (Workouts)", "Workout calories"), value: calories > 0 ? "\(Int(calories.rounded()))" : "–", unit: "kcal")
                StatTile(label: model.loc("Schritte", "Steps"), value: record?.steps.map { $0.formatted(.number) } ?? "–")
            }

            Text(targetText(strain))
                .font(.system(size: 17))
                .foregroundStyle(Theme.textPrimary.opacity(0.8))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Balken 0–21 mit aktuellem Strain und Ziel-Strich.
    private func targetBar(_ value: Double, target: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CapsLabel(text: model.loc("Fortschritt zum Ziel", "Progress to target"), color: Theme.textSecondary, size: 11)
                Spacer()
                Text(String(format: "%.1f / %.1f", value, target))
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Theme.strainBlue)
                        .frame(width: max(6, geo.size.width * CGFloat(min(value, 21) / 21)))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3, height: 18)
                        .offset(x: geo.size.width * CGFloat(min(target, 21) / 21) - 1.5)
                }
            }
            .frame(height: 10)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }

    private func targetText(_ strain: StrainResult) -> String {
        guard let target = targetStrain else { return strainText(strain.strain) }
        let diff = strain.strain - target
        if diff >= 1 {
            return model.loc("Ziel übertroffen. Mehr bringt heute wenig, setz auf Schlaf und Erholung.",
                             "You\u{2019}ve passed your target. More adds little today, so focus on sleep and recovery.")
        }
        if diff >= -1 {
            return model.loc("Du bist genau im Zielbereich für deine heutige Recovery.",
                             "You\u{2019}re right in the target zone for today\u{2019}s recovery.")
        }
        return model.loc("Noch \(String(format: "%.1f", -diff)) bis zum Ziel. Der weiße Strich zeigt, was deine Recovery heute hergibt.",
                         "\(String(format: "%.1f", -diff)) to go. The white tick shows what your recovery supports today.")
    }

    private func strainText(_ value: Double) -> String {
        switch value {
        case ..<10: return model.loc("Leichter Tag, gut für Erholung.", "Light day, good for recovery.")
        case ..<14: return model.loc("Moderate Belastung.", "Moderate strain.")
        case ..<18: return model.loc("Hohe Belastung. Dein Schlafbedarf steigt.", "High strain. Your sleep need goes up.")
        default: return model.loc("Sehr hohe Belastung. Plane Erholung ein.", "All-out strain. Plan time to recover.")
        }
    }

    // MARK: - Zonen

    private func zonesPanel(_ strain: StrainResult) -> some View {
        let active = strain.zoneMinutes.reduce(0, +)
        let total = max(1, active)
        let colors = [Theme.textSecondary, Theme.teal, Theme.green, Theme.yellow, Theme.orange, Theme.red]

        return Panel(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    zoneSummary(model.loc("Aktiv", "Active"), active)
                    zoneSummary(model.loc("Ruhe", "Rest"), strain.restMinutes)
                    zoneSummary(model.loc("Erfasst", "Tracked"), strain.trackedMinutes)
                }
                .padding(20)

                if active >= 1 {
                    ForEach(Array(strain.zoneMinutes.enumerated().reversed()), id: \.offset) { index, minutes in
                        PanelDivider().padding(.horizontal, 20)
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.black)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(colors[min(index, 5)]))
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(StrainEngine.zoneLabels(model.language)[index])
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(zoneRangeText(index))
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                    Text(duration(minutes))
                                        .font(.system(size: 16, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(Theme.textPrimary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.08))
                                        Capsule()
                                            .fill(colors[min(index, 5)])
                                            .frame(width: max(4, geo.size.width * CGFloat(minutes / total)))
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                } else {
                    Text(model.loc("Heute keine Zeit über der Ruhezone. Zonen zählen erst ab etwa 20 % deiner Herzfrequenz-Reserve.",
                                   "No time above the rest zone today. Zones start at about 20 % of your heart rate reserve."))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
        }
    }

    private func zoneSummary(_ label: String, _ minutes: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            CapsLabel(text: label, color: Theme.textSecondary, size: 11)
            Text(duration(minutes))
                .font(.system(size: 20, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Pulsbereich einer Zone aus der HF-Reserve (Karvonen).
    private func zoneRangeText(_ index: Int) -> String {
        let config = model.strainConfig
        let rhr = model.selectedRecord?.restingHR ?? 60
        let reserve = config.maxHR - rhr
        let bounds = StrainEngine.zoneLowerBounds
        let low = Int((rhr + reserve * bounds[index]).rounded())
        if index + 1 < bounds.count {
            let high = Int((rhr + reserve * bounds[index + 1]).rounded())
            return "\(low)–\(high)"
        }
        return "\(low)+"
    }

    private func duration(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m < 60 { return "\(m) min" }
        return "\(Fmt.hm(minutes)) h"
    }

    // MARK: - Aktivitäten

    @ViewBuilder
    private var activitiesPanel: some View {
        let workouts = model.allWorkouts(for: model.selectedDayKey)
        if workouts.isEmpty {
            Panel {
                Text(model.loc("Kein Workout an diesem Tag erfasst.", "No workout recorded on this day."))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
        } else {
            VStack(spacing: 12) {
                ForEach(workouts, id: \.id) { workout in
                    workoutCard(workout)
                }
            }
        }
    }

    private func workoutCard(_ workout: Workout) -> some View {
        Panel(padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Theme.track, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: CGFloat(Stats.clamp((workout.strain ?? 0) / 21, 0.01, 1)))
                        .stroke(Theme.strainBlue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(workout.strain.map { String(format: "%.1f", $0) } ?? "–")
                        .font(.system(size: 16, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: ActivityCatalog.symbol(for: workout.name))
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.strainBlue)
                        Text(workout.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                    }
                    Text("\(Fmt.clock(workout.start)) – \(Fmt.clock(workout.end)) · \(duration(workout.durationMinutes))")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 14) {
                        if let hr = workout.averageHR {
                            Label("\(Int(hr.rounded())) bpm", systemImage: "heart.fill")
                        }
                        if let kcal = workout.calories {
                            Label("\(Int(kcal.rounded())) kcal", systemImage: "flame.fill")
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Trend

    private var trendPanel: some View {
        let points = trendPoints(model.trend(range) { record in model.strain(for: record.date)?.strain })
        let targets = trendPoints(model.trend(range) { record in
            model.recovery(for: record.date).map { StrainEngine.targetStrain(forRecovery: $0.score) }
        })
        let values = points.map(\.value)
        let avg = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        let hits = points.filter { point in
            targets.first { $0.key == point.key }.map { abs(point.value - $0.value) <= 1.5 } ?? false
        }.count

        return Panel {
            VStack(alignment: .leading, spacing: 18) {
                RangePicker(days: $range)
                HStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 4) {
                        CapsLabel(text: model.loc("Ø Strain", "Avg strain"), color: Theme.textSecondary, size: 11)
                        Text(avg.map { String(format: "%.1f", $0) } ?? "–")
                            .font(.system(size: 26, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        CapsLabel(text: model.loc("Ziel getroffen", "On target"), color: Theme.textSecondary, size: 11)
                        Text("\(hits)/\(points.count)")
                            .font(.system(size: 26, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                if points.count >= 2 {
                    StrainBarsChart(points: points, targets: targets)
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.strainBlue).frame(width: 10, height: 10)
                            Text("Strain")
                        }
                        HStack(spacing: 6) {
                            Capsule().fill(Color.white).frame(width: 12, height: 3)
                            Text(model.loc("Ziel", "Target"))
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                } else {
                    EmptyDataHint(text: model.loc("Noch zu wenige Tage für den Trend.", "Not enough days for a trend yet."))
                }
            }
        }
    }
}
