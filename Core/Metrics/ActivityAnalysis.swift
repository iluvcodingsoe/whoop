import Foundation

/// Heart-rate breakdown of one activity: summary numbers, time in zones,
/// how fast heart rate drops after it ends, and how it settles during calm
/// activities like stretching or breathwork.
public struct ActivityAnalysis: Sendable {
    /// Samples from a few minutes before until a few minutes after the activity.
    public let window: [HRSample]
    /// Samples inside the activity.
    public let during: [HRSample]
    public let start: Date
    public let end: Date
    public let restingHR: Double
    public let maxHR: Double

    public let averageHR: Double?
    public let peakHR: Double?
    public let lowestHR: Double?
    /// When the lowest heart rate happened, in minutes from the start.
    public let lowestMinute: Double?
    /// Average of the first and last 3 minutes.
    public let startHR: Double?
    public let endHR: Double?
    /// Linear trend during the activity, in bpm per minute (negative = calming down).
    public let trendPerMinute: Double?
    /// Minutes in each of the six heart-rate zones.
    public let zoneMinutes: [Double]
    public let cardioRaw: Double
    /// Highest share of heart-rate reserve reached (0–1).
    public let peakEffort: Double?
    /// Minutes close to resting heart rate (within 10 bpm).
    public let calmMinutes: Double
    /// First minute from the start when heart rate stayed within 10 bpm of resting.
    public let settleMinute: Double?
    /// Drop from the end of the activity to 1 and 2 minutes after (heart-rate recovery).
    public let recovery1: Double?
    public let recovery2: Double?

    public static let minutesBefore: Double = 5
    public static let minutesAfter: Double = 10
    public static let calmMargin: Double = 10

    public var hasData: Bool { during.count >= 2 }
    public var durationMinutes: Double { end.timeIntervalSince(start) / 60 }
    public var calmThreshold: Double { restingHR + Self.calmMargin }

    public static func analyze(samples: [HRSample], start: Date, end: Date, restingHR: Double, maxHR: Double) -> ActivityAnalysis {
        let from = start.addingTimeInterval(-minutesBefore * 60)
        let to = end.addingTimeInterval(minutesAfter * 60)
        let window = samples.filter { $0.t >= from && $0.t <= to }.sorted { $0.t < $1.t }
        let during = window.filter { $0.t >= start && $0.t <= end }
        let bpms = during.map(\.bpm)

        func average(_ items: [HRSample]) -> Double? {
            items.isEmpty ? nil : items.map(\.bpm).reduce(0, +) / Double(items.count)
        }
        func minutes(_ date: Date) -> Double { date.timeIntervalSince(start) / 60 }

        let firstPart = during.filter { $0.t <= start.addingTimeInterval(180) }
        let lastPart = during.filter { $0.t >= end.addingTimeInterval(-180) }
        let lowest = during.min { $0.bpm < $1.bpm }

        // Linear regression of bpm over minutes.
        var trend: Double?
        if during.count >= 4 {
            let xs = during.map { minutes($0.t) }
            let mx = xs.reduce(0, +) / Double(xs.count)
            let my = bpms.reduce(0, +) / Double(bpms.count)
            var num = 0.0, den = 0.0
            for (x, y) in zip(xs, bpms) {
                num += (x - mx) * (y - my)
                den += (x - mx) * (x - mx)
            }
            trend = den > 0 ? num / den : nil
        }

        let acc = StrainEngine.accumulate(samples: during, restingHR: restingHR, maxHR: maxHR)
        let peak = bpms.max()
        let reserve = maxHR - restingHR
        let peakEffort = peak.flatMap { reserve > 0 ? min(max(($0 - restingHR) / reserve, 0), 1) : nil }

        // Calm time and settle point.
        let threshold = restingHR + calmMargin
        var calm = 0.0
        var settle: Double?
        for (index, sample) in during.enumerated() {
            let next = index + 1 < during.count ? during[index + 1].t : min(sample.t.addingTimeInterval(60), end)
            let dt = min(max(next.timeIntervalSince(sample.t) / 60, 0), 5)
            if sample.bpm <= threshold {
                calm += dt
                if settle == nil {
                    // Needs to stay calm for the next two readings too.
                    let following = during.dropFirst(index + 1).prefix(2)
                    if following.allSatisfy({ $0.bpm <= threshold + 3 }) { settle = minutes(sample.t) }
                }
            }
        }

        // Heart-rate recovery after the end.
        let endReference = lastPart.isEmpty ? nil : lastPart.suffix(2).map(\.bpm).reduce(0, +) / Double(min(lastPart.count, 2))
        func after(_ seconds: Double) -> Double? {
            let target = end.addingTimeInterval(seconds)
            let near = window.filter { $0.t > end && abs($0.t.timeIntervalSince(target)) <= 45 }
            return near.min { abs($0.t.timeIntervalSince(target)) < abs($1.t.timeIntervalSince(target)) }?.bpm
        }
        let r1 = endReference.flatMap { ref in after(60).map { ref - $0 } }
        let r2 = endReference.flatMap { ref in after(120).map { ref - $0 } }

        return ActivityAnalysis(
            window: window,
            during: during,
            start: start,
            end: end,
            restingHR: restingHR,
            maxHR: maxHR,
            averageHR: average(during),
            peakHR: peak,
            lowestHR: lowest?.bpm,
            lowestMinute: lowest.map { minutes($0.t) },
            startHR: average(firstPart),
            endHR: average(lastPart),
            trendPerMinute: trend,
            zoneMinutes: acc.zones,
            cardioRaw: acc.raw,
            peakEffort: peakEffort,
            calmMinutes: calm,
            settleMinute: settle,
            recovery1: r1,
            recovery2: r2
        )
    }

    /// Zone index (0–5) of a heart rate, or nil below zone 1.
    public func zone(for bpm: Double) -> Int? {
        let reserve = maxHR - restingHR
        guard reserve > 0 else { return nil }
        return StrainEngine.zoneIndex(for: (bpm - restingHR) / reserve)
    }

    /// Heart rate where a zone starts.
    public func zoneStart(_ index: Int) -> Double {
        restingHR + StrainEngine.zoneLowerBounds[index] * (maxHR - restingHR)
    }
}
