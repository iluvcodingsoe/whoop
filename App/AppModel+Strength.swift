import Foundation

/// Strength Trainer: logging lifts, muscular load and progress.
extension AppModel {
    var bodyweightKg: Double { weightKg > 0 ? weightKg : StrengthEngine.fallbackBodyweight }

    // MARK: - Laden & Bewerten

    /// Reloads workouts and templates from the store and rescores everything.
    func refreshStrength(recompute: Bool = true) {
        strengthWorkouts = strength.workouts.filter { $0.end != nil }
        strengthTemplates = strength.templates
        activeStrength = strength.active
        var scores: [UUID: StrengthScore] = [:]
        for workout in strengthWorkouts {
            scores[workout.id] = StrengthEngine.score(workout, history: strengthWorkouts, bodyweight: bodyweightKg)
        }
        strengthScores = scores
        if recompute { recomputeAll() }
    }

    func strengthScore(_ workout: StrengthWorkout) -> StrengthScore {
        strengthScores[workout.id] ?? StrengthEngine.score(workout, history: strengthWorkouts, bodyweight: bodyweightKg)
    }

    func muscularRawByDay() -> [String: Double] {
        var result: [String: Double] = [:]
        for workout in strengthWorkouts {
            result[workout.dayKey, default: 0] += strengthScores[workout.id]?.muscularRaw ?? 0
        }
        return result
    }

    func strengthWorkouts(on key: String) -> [StrengthWorkout] {
        strengthWorkouts.filter { $0.dayKey == key }
    }

    func strengthWorkout(_ id: UUID) -> StrengthWorkout? {
        strengthWorkouts.first { $0.id == id }
    }

    static func strengthID(_ workoutID: String) -> UUID? {
        workoutID.hasPrefix("str-") ? UUID(uuidString: String(workoutID.dropFirst(4))) : nil
    }

    /// Adds lifting sessions to a day's activities. A session replaces any
    /// other activity it mostly overlaps, so nothing is counted twice.
    func addStrengthWorkouts(to list: inout [Workout], on key: String, samples: [HRSample], restingHR: Double?) {
        for session in strengthWorkouts(on: key) {
            guard let end = session.end else { continue }
            list.removeAll { other in
                let overlap = min(other.end, end).timeIntervalSince(max(other.start, session.start))
                let length = max(other.end.timeIntervalSince(other.start), 60)
                return overlap > 0.5 * length
            }
            let slice = samples.filter { $0.t >= session.start && $0.t <= end }
            let acc = StrainEngine.accumulate(samples: slice, restingHR: restingHR ?? 62, maxHR: strainConfig.maxHR)
            var workout = Workout(id: "str-" + session.id.uuidString, name: "Weightlifting", start: session.start, end: end, averageHR: acc.avgHR)
            workout.strain = StrengthEngine.combinedStrain(
                cardioRaw: acc.raw,
                muscularRaw: strengthScores[session.id]?.muscularRaw ?? 0,
                tau: strainConfig.tau
            )
            list.append(workout)
        }
    }

    /// Strain of one lifting session (heart rate plus muscular load).
    func sessionStrain(_ session: StrengthWorkout) -> (total: Double, cardio: Double) {
        let key = session.dayKey
        let samples = (store.days[DayKey.addDays(key, -1)]?.hrSamples ?? []) + (store.days[key]?.hrSamples ?? [])
        let end = session.end ?? Date()
        let slice = samples.filter { $0.t >= session.start && $0.t <= end }
        let acc = StrainEngine.accumulate(samples: slice, restingHR: store.days[key]?.restingHR ?? 62, maxHR: strainConfig.maxHR)
        let muscular = strengthScores[session.id]?.muscularRaw ?? strengthScore(session).muscularRaw
        return (
            StrengthEngine.combinedStrain(cardioRaw: acc.raw, muscularRaw: muscular, tau: strainConfig.tau),
            StrainEngine.strain(fromRaw: acc.raw, tau: strainConfig.tau)
        )
    }

    // MARK: - Live-Training

    func startStrength(template: StrengthTemplate?, at start: Date = Date()) {
        var entries = template?.entries ?? []
        // Fill in the last weights used so the user only adjusts.
        entries = entries.map { entry in
            var e = entry
            e.id = UUID()
            let last = lastSets(for: entry.exerciseID)
            e.sets = entry.sets.enumerated().map { index, set in
                let previous = last.isEmpty ? nil : last[min(index, last.count - 1)]
                return StrengthSet(reps: previous?.reps ?? set.reps, weightKg: previous?.weightKg ?? set.weightKg)
            }
            return e
        }
        let workout = StrengthWorkout(name: template?.name ?? "Workout", start: start, entries: entries)
        strength.active = workout
        strength.save()
        activeStrength = workout
        showStrengthLogger = true
    }

    /// Opens the logger to add exercises to an activity that already happened.
    func logExercises(forActivity workoutID: String, start: Date, end: Date, on key: String) {
        let workout = StrengthWorkout(name: "Weightlifting", start: start, end: end)
        strength.active = workout
        strength.save()
        activeStrength = workout
        if let id = Self.loggedID(workoutID) {
            pendingReplaceActivity = (id, key)
        }
        showStrengthLogger = true
    }

    /// Reopens a finished workout in the logger.
    func editStrength(_ workout: StrengthWorkout) {
        strength.active = workout
        strength.save()
        activeStrength = workout
        showStrengthLogger = true
    }

    func updateActive(_ change: (inout StrengthWorkout) -> Void) {
        guard var workout = activeStrength else { return }
        change(&workout)
        activeStrength = workout
        strength.active = workout
        strength.save()
    }

    func finishActive() {
        guard var workout = activeStrength else { return }
        if workout.end == nil { workout.end = Date() }
        // Drop exercises without a finished set.
        workout.entries = workout.entries
            .map { var e = $0; e.sets = e.sets.filter(\.done); return e }
            .filter { !$0.sets.isEmpty }
        strength.active = nil
        if !workout.entries.isEmpty {
            strength.upsert(workout)
            if let pending = pendingReplaceActivity { deleteActivity(pending.0, on: pending.1) }
        }
        pendingReplaceActivity = nil
        strength.save()
        activeStrength = nil
        showStrengthLogger = false
        refreshStrength()
    }

    func discardActive() {
        strength.active = nil
        strength.save()
        activeStrength = nil
        pendingReplaceActivity = nil
        showStrengthLogger = false
    }

    // MARK: - Bearbeiten

    func saveStrength(_ workout: StrengthWorkout) {
        strength.upsert(workout)
        strength.save()
        refreshStrength()
    }

    func deleteStrength(_ id: UUID) {
        strength.delete(id)
        strength.save()
        refreshStrength()
    }

    func saveTemplate(from workout: StrengthWorkout, name: String) {
        let entries = workout.entries.map { entry in
            StrengthEntry(exerciseID: entry.exerciseID, sets: entry.sets.map { StrengthSet(reps: $0.reps, weightKg: $0.weightKg) })
        }
        strength.templates.insert(StrengthTemplate(name: name, entries: entries), at: 0)
        strength.save()
        strengthTemplates = strength.templates
    }

    /// Adds a new template or replaces one with the same id.
    func saveTemplate(_ template: StrengthTemplate) {
        if let i = strength.templates.firstIndex(where: { $0.id == template.id }) {
            strength.templates[i] = template
        } else {
            strength.templates.insert(template, at: 0)
        }
        strength.save()
        strengthTemplates = strength.templates
    }

    func deleteTemplate(_ id: UUID) {
        strength.templates.removeAll { $0.id == id }
        strength.save()
        strengthTemplates = strength.templates
    }

    // MARK: - Verlauf

    /// Sets from the most recent workout with this exercise.
    func lastSets(for exerciseID: String, before date: Date = .distantFuture) -> [StrengthSet] {
        for workout in strengthWorkouts.reversed() where workout.start < date {
            if let entry = workout.entries.first(where: { $0.exerciseID == exerciseID }), !entry.doneSets.isEmpty {
                return entry.doneSets
            }
        }
        return []
    }

    /// Exercises done in the last 90 days, most frequent first.
    var recentExercises: [String] {
        let cutoff = Date().addingTimeInterval(-90 * 86400)
        var counts: [String: Int] = [:]
        for workout in strengthWorkouts where workout.start >= cutoff {
            for entry in workout.entries { counts[entry.exerciseID, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    func strengthWeek(endingAt date: Date = Date()) -> [StrengthWorkout] {
        let start = date.addingTimeInterval(-7 * 86400)
        return strengthWorkouts.filter { $0.start > start && $0.start <= date }
    }

    // MARK: - Einheiten

    var weightUnit: String { usePounds ? "lb" : "kg" }

    func displayWeight(_ kg: Double) -> Double {
        usePounds ? kg * 2.20462 : kg
    }

    func kilograms(fromDisplay value: Double) -> Double {
        usePounds ? value / 2.20462 : value
    }

    func weightText(_ kg: Double) -> String {
        let value = displayWeight(kg)
        let rounded = (value * 2).rounded() / 2
        return rounded.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }

    func volumeText(_ kg: Double) -> String {
        Int(displayWeight(kg).rounded()).formatted(.number)
    }

    // MARK: - Demo

    func seedDemoStrength(today: String) {
        guard strength.workouts.isEmpty else { return }
        let cal = Calendar.current
        let plan: [(String, [(String, Double, Int)])] = [
            ("Golf Strength", [("trapBarDeadlift", 100, 5), ("bulgarianSplitSquat", 16, 8), ("medBallRotationalThrow", 6, 6), ("cableWoodchop", 20, 10), ("pallofPress", 14, 10), ("dbRow", 24, 10)]),
            ("Upper Body", [("benchPress", 60, 6), ("pullUp", 0, 8), ("dbShoulderPress", 16, 10), ("seatedCableRow", 45, 10), ("bicepCurl", 10, 12)]),
            ("Lower Body", [("backSquat", 80, 5), ("rdl", 70, 8), ("walkingLunge", 14, 10), ("legCurl", 35, 12), ("calfRaise", 60, 15)]),
        ]
        for week in 0..<6 {
            for (index, session) in plan.enumerated() {
                let daysAgo = (5 - week) * 7 + (6 - index * 2)
                guard daysAgo >= 1,
                      let day = DayKey.date(from: DayKey.addDays(today, -daysAgo)),
                      let start = cal.date(bySettingHour: 16, minute: 30, second: 0, of: day) else { continue }
                let growth = 1 + Double(week) * 0.025
                let entries = session.1.map { id, kg, reps in
                    StrengthEntry(exerciseID: id, sets: (0..<3).map { _ in
                        StrengthSet(reps: reps, weightKg: (kg * growth / 2.5).rounded() * 2.5, done: true)
                    })
                }
                strength.upsert(StrengthWorkout(name: session.0, start: start, end: start.addingTimeInterval(55 * 60), entries: entries))
            }
        }
        strength.save()
        refreshStrength()
    }

    func seedActiveDemoSets() {
        updateActive { workout in
            workout.start = Date().addingTimeInterval(-24 * 60)
            for i in workout.entries.indices.prefix(2) {
                for j in workout.entries[i].sets.indices where i == 0 || j == 0 {
                    workout.entries[i].sets[j].done = true
                }
            }
        }
    }
}
