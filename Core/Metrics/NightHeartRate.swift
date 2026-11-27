import Foundation

/// Heart rate around the main sleep, from the minute-by-minute heart-rate
/// samples (Google Health `heart-rate` data from the Fitbit).
public struct NightHeartRate: Sendable {
    /// Average while asleep (awake minutes inside the session excluded when stages exist).
    public let sleepingAverage: Double?
    /// Lowest 5-minute average while asleep.
    public let sleepingLowest: Double?
    /// When the lowest stretch happened.
    public let lowestAt: Date?
    /// Average over the 30 minutes before falling asleep.
    public let beforeBed: Double?
    /// Average over the hour before that (60–30 min before sleep), to show the trend.
    public let earlierEvening: Double?
    public let sleepStart: Date
    public let sleepSamples: Int
    public let beforeBedSamples: Int

    public static let beforeBedMinutes: Double = 30

    public static func analyze(samples: [HRSample], session: SleepSession) -> NightHeartRate {
        let sorted = samples.sorted { $0.t < $1.t }
        let awake = session.stages.filter { $0.stage == .awake }
        func isAwake(_ t: Date) -> Bool { awake.contains { t >= $0.start && t < $0.end } }

        let asleep = sorted.filter { $0.t >= session.start && $0.t <= session.end && !isAwake($0.t) }
        let average = asleep.isEmpty ? nil : asleep.map(\.bpm).reduce(0, +) / Double(asleep.count)

        // Lowest rolling 5-minute average (needs at least 3 readings in the window).
        var lowest: Double?
        var lowestAt: Date?
        var startIndex = 0
        var sum = 0.0
        for (i, sample) in asleep.enumerated() {
            sum += sample.bpm
            while asleep[startIndex].t < sample.t.addingTimeInterval(-5 * 60) {
                sum -= asleep[startIndex].bpm
                startIndex += 1
            }
            let count = i - startIndex + 1
            if count >= 3 {
                let value = sum / Double(count)
                if value < (lowest ?? .infinity) {
                    lowest = value
                    lowestAt = sample.t
                }
            }
        }

        let bedStart = session.start.addingTimeInterval(-beforeBedMinutes * 60)
        let before = sorted.filter { $0.t >= bedStart && $0.t < session.start }
        let earlier = sorted.filter { $0.t >= session.start.addingTimeInterval(-90 * 60) && $0.t < bedStart }
        func mean(_ items: [HRSample]) -> Double? { items.isEmpty ? nil : items.map(\.bpm).reduce(0, +) / Double(items.count) }

        return NightHeartRate(
            sleepingAverage: average,
            sleepingLowest: lowest,
            lowestAt: lowestAt,
            beforeBed: before.count >= 5 ? mean(before) : nil,
            earlierEvening: earlier.count >= 5 ? mean(earlier) : nil,
            sleepStart: session.start,
            sleepSamples: asleep.count,
            beforeBedSamples: before.count
        )
    }
}
