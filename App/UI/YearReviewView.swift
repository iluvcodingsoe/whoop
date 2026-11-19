import SwiftUI

/// Jahresrückblick: Bestwerte des laufenden Jahres, geöffnet über die Serie oben links.
struct YearReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let year = Calendar.current.component(.year, from: Date())

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(hex: 0x14161B), Color(hex: 0x181A24), Color(hex: 0x2A2148)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            DeepDiveScroll {
                YearReviewCard(stats: YearStats(model: model, year: year), year: year)
                    .padding(.bottom, 30)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .padding(.leading, 20)
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Kennzahlen

/// Bestwerte eines Kalenderjahres aus allen gespeicherten Tagen.
struct YearStats {
    struct Best {
        let value: Double
        let key: String
    }

    var daysTracked = 0
    var currentStreak = 0
    var longestStreak = 0
    var bestSleep: Best?
    var peakRecovery: Best?
    var maxStrain: Best?
    var longestSleep: Best?
    var lowestRecovery: Best?
    var topActivity: (name: String, count: Int)?
    var averageRecovery: Double?
    var averageSleepMinutes: Double?
    var totalSteps = 0
    var workouts = 0

    @MainActor
    init(model: AppModel, year: Int) {
        let prefix = "\(year)-"
        let keys = model.store.sortedKeys.filter { $0.hasPrefix(prefix) }

        var recoveries: [Double] = []
        var sleeps: [Double] = []
        var activityCounts: [String: Int] = [:]
        var trackedKeys: [String] = []

        for key in keys {
            let recovery = model.recovery(for: key)
            let sleep = model.sleep(for: key).flatMap { $0.hasData ? $0 : nil }
            let strain = model.strain(for: key)
            let record = model.record(for: key)
            if recovery != nil || sleep != nil { trackedKeys.append(key) }

            if let recovery {
                let score = Double(recovery.score)
                recoveries.append(score)
                if score > (peakRecovery?.value ?? -1) { peakRecovery = Best(value: score, key: key) }
                if score < (lowestRecovery?.value ?? 1000) { lowestRecovery = Best(value: score, key: key) }
            }
            if let sleep {
                sleeps.append(sleep.sleptMinutes)
                if sleep.performance > (bestSleep?.value ?? -1) { bestSleep = Best(value: sleep.performance, key: key) }
                if sleep.sleptMinutes > (longestSleep?.value ?? -1) { longestSleep = Best(value: sleep.sleptMinutes, key: key) }
            }
            if let strain, strain.strain > (maxStrain?.value ?? -1) {
                maxStrain = Best(value: strain.strain, key: key)
            }
            totalSteps += record?.steps ?? 0
            for workout in model.allWorkouts(for: key) {
                activityCounts[workout.name, default: 0] += 1
                workouts += 1
            }
        }

        daysTracked = trackedKeys.count
        currentStreak = model.streakDays
        var run = 0
        var previous: String?
        for key in trackedKeys {
            run = (previous.map { DayKey.addDays($0, 1) == key } ?? false) ? run + 1 : 1
            longestStreak = max(longestStreak, run)
            previous = key
        }
        if let top = activityCounts.max(by: { $0.value < $1.value }) {
            topActivity = (top.key, top.value)
        }
        averageRecovery = recoveries.isEmpty ? nil : recoveries.reduce(0, +) / Double(recoveries.count)
        averageSleepMinutes = sleeps.isEmpty ? nil : sleeps.reduce(0, +) / Double(sleeps.count)
    }
}

// MARK: - Karte

struct YearReviewCard: View {
    let stats: YearStats
    let year: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("PULSE")
                            .font(.system(size: 24, weight: .light))
                            .kerning(4)
                            .foregroundStyle(Theme.textPrimary)
                        Text(String(year))
                            .font(.system(size: 24, weight: .semibold).italic())
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: 0x8C7CF0), Color(hex: 0x3D8BFF)], startPoint: .leading, endPoint: .trailing)
                            )
                    }

                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Theme.orange, Theme.red], startPoint: .top, endPoint: .bottom))
                        Image(systemName: "flame.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.white)
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your")
                        Text("Year in Review")
                    }
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                }
                .padding(.top, 60)
                .frame(maxWidth: .infinity, alignment: .leading)

                RecoveryOrb(average: stats.averageRecovery)
                    .frame(width: 230, height: 230)
                    .offset(x: 50, y: -30)
                    .allowsHitTesting(false)
            }

            HStack(spacing: 14) {
                headlineStat(symbol: "calendar", title: "Days tracked", value: "\(stats.daysTracked) days")
                headlineStat(symbol: "flame", title: "Day streak", value: "\(stats.currentStreak) now · \(stats.longestStreak) best")
            }
            .padding(.top, 26)

            HStack(spacing: 0) {
                ring(value: stats.bestSleep.map { "\(Int($0.value.rounded()))" } ?? "–", unit: "%",
                     fraction: (stats.bestSleep?.value ?? 0) / 100, color: Theme.sleepPurple,
                     title: "Best\nSleep", date: stats.bestSleep?.key)
                ring(value: stats.peakRecovery.map { "\(Int($0.value))" } ?? "–", unit: "%",
                     fraction: (stats.peakRecovery?.value ?? 0) / 100, color: Theme.green,
                     title: "Peak\nRecovery", date: stats.peakRecovery?.key)
                ring(value: stats.maxStrain.map { String(format: "%.1f", $0.value) } ?? "–", unit: "",
                     fraction: (stats.maxStrain?.value ?? 0) / 21, color: Theme.strainBlue,
                     title: "Max\nStrain", date: stats.maxStrain?.key)
            }
            .padding(.vertical, 22)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
            .padding(.top, 22)

            VStack(spacing: 12) {
                row(symbol: "moon.stars", title: "Longest Sleep", subtitle: stats.longestSleep.map { dateText($0.key) },
                    value: stats.longestSleep.map { Fmt.hm($0.value) } ?? "–", unit: "hr")
                row(symbol: "arrow.down.heart", title: "Lowest Recovery", subtitle: stats.lowestRecovery.map { dateText($0.key) },
                    value: stats.lowestRecovery.map { "\(Int($0.value))" } ?? "–", unit: "%")
                row(symbol: stats.topActivity.map { ActivityCatalog.symbol(for: $0.name) } ?? "figure.walk", title: "Top Activity",
                    subtitle: stats.topActivity?.name, value: stats.topActivity.map { "\($0.count)" } ?? "–", unit: "x", smallTitle: true)
                row(symbol: "bed.double", title: "Average Sleep", subtitle: nil,
                    value: stats.averageSleepMinutes.map { Fmt.hm($0) } ?? "–", unit: "hr")
                row(symbol: "shoeprints.fill", title: "Total Steps", subtitle: nil,
                    value: stats.totalSteps.formatted(.number), unit: "")
                row(symbol: "figure.mixed.cardio", title: "Activities", subtitle: nil,
                    value: "\(stats.workouts)", unit: "")
            }
            .padding(.top, 18)
            .id("rows")
        }
        .padding(.horizontal, 20)
        .clipped()
    }

    private func dateText(_ key: String) -> String {
        (DayKey.date(from: key) ?? Date()).formatted(.dateTime.month(.abbreviated).day())
    }

    private func headlineStat(symbol: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(Theme.textPrimary)
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ring(value: String, unit: String, fraction: Double, color: Color, title: String, date: String?) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(Stats.clamp(fraction, 0.004, 1)))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold).monospacedDigit())
                    if !unit.isEmpty {
                        Text(unit).font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 8)
            }
            .frame(width: 86, height: 86)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
            Text(date.map(dateText) ?? " ")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(symbol: String, title: String, subtitle: String?, value: String, unit: String, smallTitle: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: 0xE8C27A))
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white.opacity(0.06)))
            VStack(alignment: .leading, spacing: 2) {
                if smallTitle {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    Text(subtitle ?? "–")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Text(title)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Leuchtende Kugel

/// Grüne Punktwolke mit dem Jahresschnitt der Recovery in der Mitte.
struct RecoveryOrb: View {
    let average: Double?

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2
                context.fill(
                    Path(ellipseIn: CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                    with: .radialGradient(
                        Gradient(colors: [Color.black.opacity(0.9), Color(hex: 0x0B3D2A).opacity(0.85), Color(hex: 0x19E39A).opacity(0.35), .clear]),
                        center: center, startRadius: radius * 0.35, endRadius: radius
                    )
                )
                var generator = SeededGenerator(seed: 42)
                for _ in 0..<520 {
                    let angle = Double.random(in: 0..<(2 * .pi), using: &generator)
                    let r = radius * sqrt(Double.random(in: 0.25...1, using: &generator))
                    let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                    let size = Double.random(in: 0.8...2.4, using: &generator)
                    let alpha = 0.25 + 0.75 * (r / radius)
                    context.fill(
                        Path(ellipseIn: CGRect(x: p.x, y: p.y, width: size, height: size)),
                        with: .color(Color(hex: 0x19E39A).opacity(alpha))
                    )
                }
            }
            VStack(spacing: 4) {
                Text(average.map { "\(Int($0.rounded()))%" } ?? "–")
                    .font(.system(size: 34, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Text("AVG RECOVERY")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.4)
                    .foregroundStyle(Theme.textPrimary)
            }
            .offset(x: -24, y: 18)
        }
    }
}

/// Fester Zufallsgenerator, damit die Punkte bei jedem Zeichnen gleich liegen.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
