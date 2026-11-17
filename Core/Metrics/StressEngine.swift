import Foundation

/// Ein Stress-Messpunkt (Skala 0–3) für ein 15-Minuten-Fenster.
public struct StressPoint: Hashable, Sendable {
    public let t: Date
    public let value: Double

    public init(t: Date, value: Double) {
        self.t = t
        self.value = value
    }
}

public enum StressLevel: String, Sendable {
    case low
    case medium
    case high

    public init(score: Double) {
        if score >= 2 { self = .high }
        else if score >= 1 { self = .medium }
        else { self = .low }
    }

    public func label(_ lang: PulseLanguage) -> String {
        switch (self, lang) {
        case (.low, .de): return "Niedrig"
        case (.low, .en): return "Low"
        case (.medium, .de): return "Mittel"
        case (.medium, .en): return "Medium"
        case (.high, .de): return "Hoch"
        case (.high, .en): return "High"
        }
    }
}

public struct StressResult: Sendable {
    /// 15-Minuten-Werte des Tages (wach, ohne Workouts).
    public let points: [StressPoint]
    /// Letzter Messpunkt.
    public let latest: StressPoint?
    /// Tagesmittel aller Punkte.
    public let average: Double?
    /// Minuten je Stufe (niedrig, mittel, hoch).
    public let minutesLow: Double
    public let minutesMedium: Double
    public let minutesHigh: Double
}

/// Stress-Monitor (0–3) aus der Intraday-Herzfrequenz: Wie weit liegt der
/// Puls im Wachzustand über dem Ruhepuls, gemessen an der Herzfrequenz-
/// Reserve? Schlaf und Workouts werden ausgeklammert, damit Training nicht
/// als Stress zählt.
public enum StressEngine {
    /// Fenstergröße in Minuten.
    public static let windowMinutes = 15.0
    /// Anteil der HF-Reserve, der einem Stress von 3 entspricht.
    static let fullScaleReserve = 0.35

    public static func compute(record: DayRecord, restingHR: Double?, maxHR: Double) -> StressResult? {
        guard let rhr = restingHR ?? record.restingHR, !record.hrSamples.isEmpty else { return nil }
        let reserve = max(30, maxHR - rhr)

        let sleepSpans = record.sleepSessions.map { ($0.start, $0.end) }
        let workoutSpans = record.workouts.map { ($0.start, $0.end) }
        func excluded(_ t: Date) -> Bool {
            sleepSpans.contains { t >= $0.0 && t < $0.1 }
                || workoutSpans.contains { t >= $0.0 && t < $0.1 }
        }

        let awake = record.hrSamples.filter { !excluded($0.t) }.sorted { $0.t < $1.t }
        guard !awake.isEmpty else { return nil }

        // In 15-Minuten-Fenster gruppieren; Median gegen kurze Spitzen.
        var buckets: [Date: [Double]] = [:]
        let window = windowMinutes * 60
        for sample in awake {
            let start = Date(timeIntervalSince1970: (sample.t.timeIntervalSince1970 / window).rounded(.down) * window)
            buckets[start, default: []].append(sample.bpm)
        }

        let points: [StressPoint] = buckets.keys.sorted().compactMap { start in
            guard let values = buckets[start], values.count >= 3 else { return nil }
            let sorted = values.sorted()
            let median = sorted[sorted.count / 2]
            let fraction = (median - rhr) / (reserve * fullScaleReserve)
            return StressPoint(t: start, value: Stats.clamp(fraction * 3, 0, 3))
        }
        guard !points.isEmpty else { return nil }

        let average = points.reduce(0) { $0 + $1.value } / Double(points.count)
        var low = 0.0, medium = 0.0, high = 0.0
        for point in points {
            switch StressLevel(score: point.value) {
            case .low: low += windowMinutes
            case .medium: medium += windowMinutes
            case .high: high += windowMinutes
            }
        }

        return StressResult(
            points: points,
            latest: points.last,
            average: average,
            minutesLow: low,
            minutesMedium: medium,
            minutesHigh: high
        )
    }
}
