import Foundation

/// Result of scoring one strength workout.
public struct StrengthScore: Sendable {
    /// Muscular load in strain units (same raw scale as heart-rate load).
    public let muscularRaw: Double
    /// Total weight moved in kg (reps x effective load).
    public let volumeKg: Double
    public let doneSets: Int
    public let totalReps: Int
    /// Load per muscle (primary muscles count fully, secondary half).
    public let muscleLoad: [Muscle: Double]
    /// Exercises where this workout set a new estimated 1-rep max.
    public let personalRecords: [String]
}

/// Muscular load from logged sets, reps and weight.
///
/// Each rep counts its effective load (added weight plus the share of body
/// weight the movement moves) relative to body weight, scaled by how demanding
/// the movement is and how close the set was to the lifter's best.
/// The result is added to heart-rate load before mapping to the 0–21 scale.
public enum StrengthEngine {
    /// Converts body-weight reps into strain raw units.
    public static let rawScale = 1.25
    /// Default when no body weight is known.
    public static let fallbackBodyweight = 70.0

    public static func effectiveLoad(_ set: StrengthSet, exercise: Exercise, bodyweight: Double) -> Double {
        max(0, set.weightKg + exercise.bodyweightFraction * bodyweight)
    }

    /// Estimated 1-rep max (Epley), capped at 12 reps for reliability.
    public static func estimatedMax(_ set: StrengthSet, exercise: Exercise, bodyweight: Double) -> Double? {
        guard exercise.measure == .reps, set.reps > 0 else { return nil }
        let load = effectiveLoad(set, exercise: exercise, bodyweight: bodyweight)
        guard load > 0 else { return nil }
        return load * (1 + Double(min(set.reps, 12)) / 30)
    }

    /// Body-weight reps of one set before intensity weighting.
    static func setLoad(_ set: StrengthSet, exercise: Exercise, bodyweight: Double) -> Double {
        let bw = max(bodyweight, 30)
        let load = effectiveLoad(set, exercise: exercise, bodyweight: bw)
        // Weightless sets (e.g. a machine left at 0) still count a little.
        let relative = max(load / bw, 0.15)
        let reps: Double
        switch exercise.measure {
        case .reps: reps = Double(set.reps)
        case .seconds: reps = Double(set.reps) / 4 // ~4 s of holding ≈ 1 rep
        }
        return reps * relative * exercise.complexity
    }

    /// Weight on heavy sets: sets near the lifter's best count more.
    static func intensityFactor(relative: Double?) -> Double {
        guard let relative else { return 1 }
        let r = Stats.clamp(relative, 0, 1.1)
        return 0.7 + 0.6 * r * r
    }

    /// Best estimated 1-rep max per exercise from earlier workouts.
    public static func bestMaxes(_ workouts: [StrengthWorkout], before date: Date? = nil, bodyweight: Double) -> [String: Double] {
        var best: [String: Double] = [:]
        for workout in workouts where date == nil || workout.start < date! {
            for entry in workout.entries {
                guard let exercise = entry.exercise else { continue }
                for set in entry.doneSets {
                    if let e = estimatedMax(set, exercise: exercise, bodyweight: bodyweight) {
                        best[entry.exerciseID] = max(best[entry.exerciseID] ?? 0, e)
                    }
                }
            }
        }
        return best
    }

    public static func score(_ workout: StrengthWorkout, history: [StrengthWorkout], bodyweight: Double) -> StrengthScore {
        let bw = bodyweight > 0 ? bodyweight : fallbackBodyweight
        let previous = bestMaxes(history.filter { $0.id != workout.id }, before: workout.start, bodyweight: bw)
        var raw = 0.0
        var volume = 0.0
        var sets = 0
        var reps = 0
        var muscles: [Muscle: Double] = [:]
        var records: [String] = []

        for entry in workout.entries {
            guard let exercise = entry.exercise else { continue }
            var bestToday = 0.0
            for set in entry.doneSets {
                let base = setLoad(set, exercise: exercise, bodyweight: bw)
                let e1rm = estimatedMax(set, exercise: exercise, bodyweight: bw)
                let relative: Double? = {
                    guard let best = previous[entry.exerciseID], best > 0 else { return nil }
                    return effectiveLoad(set, exercise: exercise, bodyweight: bw) / best
                }()
                let load = base * intensityFactor(relative: relative)
                raw += load * rawScale
                sets += 1
                if exercise.measure == .reps {
                    reps += set.reps
                    volume += Double(set.reps) * effectiveLoad(set, exercise: exercise, bodyweight: bw)
                }
                for muscle in exercise.primary { muscles[muscle, default: 0] += load }
                for muscle in exercise.secondary { muscles[muscle, default: 0] += load * 0.5 }
                if let e1rm { bestToday = max(bestToday, e1rm) }
            }
            if let before = previous[entry.exerciseID], bestToday > before * 1.005 {
                records.append(entry.exerciseID)
            }
        }
        return StrengthScore(
            muscularRaw: raw,
            volumeKg: volume,
            doneSets: sets,
            totalReps: reps,
            muscleLoad: muscles,
            personalRecords: records
        )
    }

    /// Strain of a lifting session: heart-rate load plus muscular load on the 0–21 scale.
    public static func combinedStrain(cardioRaw: Double, muscularRaw: Double, tau: Double = 450) -> Double {
        StrainEngine.strain(fromRaw: cardioRaw + muscularRaw, tau: tau)
    }

    /// Inverse of the strain curve: raw load behind a strain value.
    public static func raw(fromStrain strain: Double, tau: Double = 450) -> Double {
        let s = Stats.clamp(strain, 0, 20.99)
        return -tau * log(1 - s / 21)
    }

    /// Hard sets per muscle in a time window (primary 1, secondary 0.5).
    public static func weeklySets(_ workouts: [StrengthWorkout]) -> [Muscle: Double] {
        var result: [Muscle: Double] = [:]
        for workout in workouts {
            for entry in workout.entries {
                guard let exercise = entry.exercise else { continue }
                let count = Double(entry.doneSets.count)
                for muscle in exercise.primary { result[muscle, default: 0] += count }
                for muscle in exercise.secondary { result[muscle, default: 0] += count * 0.5 }
            }
        }
        return result
    }

    /// Best estimated 1-rep max per workout for one exercise, oldest first.
    public static func progress(for exerciseID: String, in workouts: [StrengthWorkout], bodyweight: Double) -> [(date: Date, value: Double, bestSet: StrengthSet)] {
        guard let exercise = ExerciseCatalog.exercise(exerciseID) else { return [] }
        let bw = bodyweight > 0 ? bodyweight : fallbackBodyweight
        var points: [(Date, Double, StrengthSet)] = []
        for workout in workouts.sorted(by: { $0.start < $1.start }) {
            var best: (Double, StrengthSet)?
            for entry in workout.entries where entry.exerciseID == exerciseID {
                for set in entry.doneSets {
                    let value: Double
                    if exercise.measure == .seconds {
                        value = Double(set.reps)
                    } else {
                        guard let e = estimatedMax(set, exercise: exercise, bodyweight: bw) else { continue }
                        value = e
                    }
                    if value > (best?.0 ?? 0) { best = (value, set) }
                }
            }
            if let best { points.append((workout.start, best.0, best.1)) }
        }
        return points.map { (date: $0.0, value: $0.1, bestSet: $0.2) }
    }
}
