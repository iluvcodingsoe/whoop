import Foundation

/// How likely the body is fighting something off, from overnight vitals
/// compared with the person's own rolling baseline.
///
/// Based on what WHOOP's Health Monitor and published wearable studies use:
/// respiratory rate (most specific), skin temperature, resting heart rate,
/// HRV and blood oxygen. Each night is compared with the previous 30 nights.
/// Several signals moving together, or one signal staying off for several
/// nights, count far more than a single odd reading. Not a diagnosis.
public enum IllnessLevel: Int, Sendable, Comparable {
    case calibrating = -1
    case normal = 0
    case watch = 1
    case warning = 2

    public static func < (a: IllnessLevel, b: IllnessLevel) -> Bool { a.rawValue < b.rawValue }

    public var title: String {
        switch self {
        case .calibrating: return "Learning your baseline"
        case .normal: return "No signs"
        case .watch: return "Watch"
        case .warning: return "Signs of strain"
        }
    }
}

public struct IllnessSignal: Sendable, Identifiable {
    public let kind: HealthMetricKind
    public let value: Double?
    public let baselineMean: Double?
    /// Spread used for the comparison (baseline SD with a minimum).
    public let spread: Double?
    /// How far off in the direction that matters, in spreads (0 = normal or better).
    public let concern: Double
    /// Nights in a row this signal has been off (concern ≥ 1).
    public let nightsOff: Int
    public let weight: Double

    public var id: String { kind.rawValue }
    public var delta: Double? {
        guard let value, let baselineMean else { return nil }
        return value - baselineMean
    }
    public var isOut: Bool { concern >= IllnessEngine.outThreshold }
    public var isDrifting: Bool { concern >= IllnessEngine.driftThreshold }
}

public struct IllnessAssessment: Sendable {
    public let dayKey: String
    public let level: IllnessLevel
    /// 0–100.
    public let score: Int
    public let signals: [IllnessSignal]
    public let headline: String
    public let detail: String

    public var outSignals: [IllnessSignal] { signals.filter(\.isOut) }
    public var driftingSignals: [IllnessSignal] { signals.filter(\.isDrifting) }
}

public enum IllnessEngine {
    public static let baselineNights = 30
    public static let minimumNights = 7
    /// Same as the Health Monitor band edge (mean ± 1.65 SD).
    public static let outThreshold = 1.65
    public static let driftThreshold = 1.0

    /// Respiratory rate is the most illness-specific signal, then skin temperature.
    static func weight(_ kind: HealthMetricKind) -> Double {
        switch kind {
        case .respiratoryRate: return 1.5
        case .bodyTemp: return 1.3
        case .restingHR: return 1.0
        case .hrv: return 0.9
        case .spo2: return 0.7
        }
    }

    /// Smallest spread used, so very stable baselines don't flag tiny changes.
    static func minimumSpread(_ kind: HealthMetricKind) -> Double {
        switch kind {
        case .restingHR: return 2
        case .hrv: return 6
        case .respiratoryRate: return 0.5
        case .spo2: return 1.0
        case .bodyTemp: return 0.25
        }
    }

    static func value(_ kind: HealthMetricKind, _ r: DayRecord) -> Double? {
        switch kind {
        case .restingHR: return r.restingHR
        case .hrv: return r.hrvRmssd
        case .respiratoryRate: return r.respiratoryRate
        case .spo2: return r.spo2Avg
        case .bodyTemp: return r.bodyTemp
        }
    }

    /// Positive when the value moved in the direction linked to illness.
    static func concern(_ kind: HealthMetricKind, value: Double, mean: Double, spread: Double) -> Double {
        let z = (value - mean) / spread
        switch kind {
        case .hrv, .spo2: return max(0, -z)
        case .restingHR, .respiratoryRate, .bodyTemp: return max(0, z)
        }
    }

    /// Signals for one night, using only nights before it as the baseline.
    static func signals(at index: Int, records: [DayRecord]) -> [IllnessSignal]? {
        let today = records[index]
        let history = Array(records[max(0, index - baselineNights)..<index])
        var result: [IllnessSignal] = []
        var anyBaseline = false
        for kind in HealthMetricKind.allCases {
            let values = history.compactMap { value(kind, $0) }
            let current = value(kind, today)
            guard values.count >= minimumNights else {
                result.append(IllnessSignal(kind: kind, value: current, baselineMean: nil, spread: nil, concern: 0, nightsOff: 0, weight: weight(kind)))
                continue
            }
            anyBaseline = true
            let mean = Stats.mean(values)
            let spread = max(Stats.standardDeviation(values), minimumSpread(kind))
            let c = current.map { concern(kind, value: $0, mean: mean, spread: spread) } ?? 0
            result.append(IllnessSignal(kind: kind, value: current, baselineMean: mean, spread: spread, concern: c, nightsOff: 0, weight: weight(kind)))
        }
        return anyBaseline ? result : nil
    }

    /// Assessment for the last record in `records` (chronological, ideally 40+ nights).
    public static func assess(records: [DayRecord]) -> IllnessAssessment? {
        guard let last = records.last else { return nil }
        let n = records.count
        guard let today = signals(at: n - 1, records: records) else {
            return IllnessAssessment(dayKey: last.date, level: .calibrating, score: 0, signals: [],
                                     headline: "Learning your baseline",
                                     detail: "Pulse needs about a week of nights with your Fitbit to learn what normal looks like for you.")
        }

        // Nights in a row each signal has been drifting (up to 4).
        var previous: [[IllnessSignal]] = []
        for back in 1...3 where n - 1 - back >= 0 {
            if let s = signals(at: n - 1 - back, records: records) { previous.append(s) } else { break }
        }
        let withStreaks: [IllnessSignal] = today.map { signal in
            guard signal.isDrifting else { return signal }
            var streak = 1
            for night in previous {
                if night.first(where: { $0.kind == signal.kind })?.isDrifting == true { streak += 1 } else { break }
            }
            return IllnessSignal(kind: signal.kind, value: signal.value, baselineMean: signal.baselineMean, spread: signal.spread,
                                 concern: signal.concern, nightsOff: streak, weight: signal.weight)
        }

        // Score: weighted concern, extra for several signals together and for persistence.
        var raw = 0.0
        for s in withStreaks {
            let capped = min(s.concern, 3)
            raw += capped * s.weight * (s.nightsOff >= 2 ? 1.25 : 1)
        }
        let drifting = withStreaks.filter(\.isDrifting)
        let out = withStreaks.filter(\.isOut)
        if drifting.count >= 2 { raw += Double(drifting.count - 1) * 1.2 }
        let score = Int(min(100, (100 * (1 - exp(-raw / 5))).rounded()))

        // Level rules: one odd reading is a "watch" at most.
        let respiratoryOut = out.contains { $0.kind == .respiratoryRate }
        let persistentOut = out.contains { $0.nightsOff >= 2 }
        let level: IllnessLevel
        if out.count >= 2 || (respiratoryOut && drifting.count >= 2) || (persistentOut && drifting.count >= 2) || (out.count >= 1 && drifting.count >= 3) {
            level = .warning
        } else if !out.isEmpty || drifting.count >= 2 {
            level = .watch
        } else {
            level = .normal
        }

        return IllnessAssessment(
            dayKey: last.date,
            level: level,
            score: level == .normal ? min(score, 30) : score,
            signals: withStreaks,
            headline: headline(level: level, drifting: drifting),
            detail: detail(level: level, out: out, drifting: drifting)
        )
    }

    /// Daily assessments for the last `days` nights, oldest first.
    public static func history(records: [DayRecord], days: Int) -> [IllnessAssessment] {
        let n = records.count
        guard n > 0 else { return [] }
        return (max(0, n - days)..<n).compactMap { end in
            assess(records: Array(records[max(0, end - baselineNights - 4)...end]))
        }
    }

    static func name(_ kind: HealthMetricKind) -> String {
        switch kind {
        case .restingHR: return "resting heart rate"
        case .hrv: return "HRV"
        case .respiratoryRate: return "respiratory rate"
        case .spo2: return "blood oxygen"
        case .bodyTemp: return "skin temperature"
        }
    }

    static func direction(_ kind: HealthMetricKind) -> String {
        switch kind {
        case .hrv, .spo2: return "lower"
        default: return "higher"
        }
    }

    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }

    static func headline(level: IllnessLevel, drifting: [IllnessSignal]) -> String {
        switch level {
        case .calibrating: return "Learning your baseline"
        case .normal: return "Your vitals look normal"
        case .watch: return "One or two vitals are drifting"
        case .warning: return "Your body may be fighting something"
        }
    }

    static func detail(level: IllnessLevel, out: [IllnessSignal], drifting: [IllnessSignal]) -> String {
        let sorted = drifting.sorted { $0.concern * $0.weight > $1.concern * $1.weight }
        let parts = sorted.map { "\(direction($0.kind)) \(name($0.kind))" }
        switch level {
        case .calibrating:
            return "Pulse needs about a week of nights to learn what normal looks like for you."
        case .normal:
            return "Last night\u{2019}s respiratory rate, skin temperature, resting heart rate, HRV and blood oxygen were all close to your normal."
        case .watch:
            return "Last night showed \(list(parts)) than usual. One odd night is often from a hard day, a late meal, alcohol or short sleep. Keep an eye on it."
        case .warning:
            let persistent = sorted.filter { $0.nightsOff >= 2 }.map { name($0.kind) }
            var text = "Last night showed \(list(parts)) than your normal at the same time."
            if !persistent.isEmpty { text += " \(list(persistent).prefix(1).uppercased() + list(persistent).dropFirst()) has been off for more than one night." }
            text += " This pattern often shows up before or early in a cold or other illness."
            return text
        }
    }
}
