import Foundation

// MARK: - Muskeln & Übungen

/// Muscle groups used for load breakdown and weekly sets.
public enum Muscle: String, CaseIterable, Codable, Sendable, Identifiable {
    case chest, shoulders, triceps, biceps, forearms, lats, upperBack, lowerBack, core, glutes, quads, hamstrings, calves

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .chest: return "Chest"
        case .shoulders: return "Shoulders"
        case .triceps: return "Triceps"
        case .biceps: return "Biceps"
        case .forearms: return "Forearms"
        case .lats: return "Lats"
        case .upperBack: return "Upper Back"
        case .lowerBack: return "Lower Back"
        case .core: return "Core"
        case .glutes: return "Glutes"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .calves: return "Calves"
        }
    }

    /// Body region for grouping in the UI.
    public var region: String {
        switch self {
        case .chest, .shoulders, .triceps, .biceps, .forearms, .lats, .upperBack: return "Upper Body"
        case .lowerBack, .core: return "Core"
        case .glutes, .quads, .hamstrings, .calves: return "Lower Body"
        }
    }
}

public enum Equipment: String, Codable, Sendable, CaseIterable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell, band, medicineBall, other

    public var title: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .machine: return "Machine"
        case .cable: return "Cable"
        case .bodyweight: return "Bodyweight"
        case .kettlebell: return "Kettlebell"
        case .band: return "Band"
        case .medicineBall: return "Medicine Ball"
        case .other: return "Other"
        }
    }
}

/// How a set is measured.
public enum SetMeasure: String, Codable, Sendable {
    case reps, seconds
}

public struct Exercise: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let primary: [Muscle]
    public let secondary: [Muscle]
    public let equipment: Equipment
    /// Load profile of the movement: how much of the body it stresses.
    /// A back squat is 1.0, a calf raise about 0.35.
    public let complexity: Double
    /// Share of body weight moved each rep (push-up 0.64, pull-up 1.0).
    public let bodyweightFraction: Double
    public let measure: SetMeasure

    public var symbol: String {
        switch equipment {
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbell, .kettlebell: return "dumbbell"
        case .machine, .cable: return "figure.strengthtraining.functional"
        case .bodyweight: return "figure.core.training"
        case .band: return "figure.flexibility"
        case .medicineBall: return "figure.golf"
        case .other: return "figure.mixed.cardio"
        }
    }
}

public enum ExerciseCatalog {
    public static let all: [Exercise] = {
        typealias M = Muscle
        func ex(_ id: String, _ name: String, _ primary: [M], _ secondary: [M], _ eq: Equipment, _ c: Double, bw: Double = 0, _ measure: SetMeasure = .reps) -> Exercise {
            Exercise(id: id, name: name, primary: primary, secondary: secondary, equipment: eq, complexity: c, bodyweightFraction: bw, measure: measure)
        }
        return [
            // Legs
            ex("backSquat", "Back Squat", [.quads, .glutes], [.hamstrings, .lowerBack, .core], .barbell, 1.0),
            ex("frontSquat", "Front Squat", [.quads], [.glutes, .core, .upperBack], .barbell, 0.95),
            ex("gobletSquat", "Goblet Squat", [.quads, .glutes], [.core], .dumbbell, 0.85),
            ex("deadlift", "Deadlift", [.hamstrings, .glutes, .lowerBack], [.quads, .upperBack, .forearms], .barbell, 1.1),
            ex("trapBarDeadlift", "Trap Bar Deadlift", [.quads, .glutes, .hamstrings], [.lowerBack, .upperBack], .barbell, 1.05),
            ex("rdl", "Romanian Deadlift", [.hamstrings, .glutes], [.lowerBack, .forearms], .barbell, 0.9),
            ex("dbRdl", "Dumbbell Romanian Deadlift", [.hamstrings, .glutes], [.lowerBack], .dumbbell, 0.85),
            ex("singleLegRdl", "Single-Leg Romanian Deadlift", [.hamstrings, .glutes], [.core], .dumbbell, 0.75),
            ex("legPress", "Leg Press", [.quads, .glutes], [.hamstrings], .machine, 0.7),
            ex("hackSquat", "Hack Squat", [.quads], [.glutes], .machine, 0.75),
            ex("bulgarianSplitSquat", "Bulgarian Split Squat", [.quads, .glutes], [.hamstrings, .core], .dumbbell, 0.85, bw: 0.4),
            ex("walkingLunge", "Walking Lunge", [.quads, .glutes], [.hamstrings], .dumbbell, 0.8, bw: 0.4),
            ex("reverseLunge", "Reverse Lunge", [.quads, .glutes], [.hamstrings], .dumbbell, 0.8, bw: 0.4),
            ex("stepUp", "Step-Up", [.quads, .glutes], [.calves], .dumbbell, 0.75, bw: 0.5),
            ex("hipThrust", "Hip Thrust", [.glutes], [.hamstrings], .barbell, 0.7),
            ex("gluteBridge", "Glute Bridge", [.glutes], [.hamstrings, .core], .bodyweight, 0.5, bw: 0.4),
            ex("legExtension", "Leg Extension", [.quads], [], .machine, 0.45),
            ex("legCurl", "Leg Curl", [.hamstrings], [], .machine, 0.45),
            ex("nordicCurl", "Nordic Curl", [.hamstrings], [.glutes], .bodyweight, 0.7, bw: 0.6),
            ex("calfRaise", "Standing Calf Raise", [.calves], [], .machine, 0.35),
            ex("seatedCalfRaise", "Seated Calf Raise", [.calves], [], .machine, 0.3),
            ex("bodyweightSquat", "Bodyweight Squat", [.quads, .glutes], [], .bodyweight, 0.6, bw: 0.7),
            ex("boxJump", "Box Jump", [.quads, .glutes], [.calves], .bodyweight, 0.8, bw: 1.0),
            ex("kbSwing", "Kettlebell Swing", [.glutes, .hamstrings], [.lowerBack, .core, .shoulders], .kettlebell, 0.8),
            ex("lateralLunge", "Lateral Lunge", [.quads, .glutes], [.hamstrings], .dumbbell, 0.75, bw: 0.4),
            ex("hipAbduction", "Hip Abduction", [.glutes], [], .machine, 0.35),
            ex("hipAdduction", "Hip Adduction", [.quads], [], .machine, 0.35),
            // Chest
            ex("benchPress", "Bench Press", [.chest], [.triceps, .shoulders], .barbell, 0.85),
            ex("inclineBench", "Incline Bench Press", [.chest, .shoulders], [.triceps], .barbell, 0.8),
            ex("dbBench", "Dumbbell Bench Press", [.chest], [.triceps, .shoulders], .dumbbell, 0.8),
            ex("inclineDbBench", "Incline Dumbbell Press", [.chest, .shoulders], [.triceps], .dumbbell, 0.75),
            ex("chestFly", "Chest Fly", [.chest], [.shoulders], .dumbbell, 0.45),
            ex("cableFly", "Cable Fly", [.chest], [.shoulders], .cable, 0.45),
            ex("machineChestPress", "Machine Chest Press", [.chest], [.triceps, .shoulders], .machine, 0.6),
            ex("pushUp", "Push-Up", [.chest], [.triceps, .shoulders, .core], .bodyweight, 0.7, bw: 0.64),
            ex("dip", "Dip", [.chest, .triceps], [.shoulders], .bodyweight, 0.8, bw: 1.0),
            // Back
            ex("pullUp", "Pull-Up", [.lats], [.biceps, .upperBack, .forearms], .bodyweight, 0.9, bw: 1.0),
            ex("chinUp", "Chin-Up", [.lats, .biceps], [.upperBack], .bodyweight, 0.9, bw: 1.0),
            ex("latPulldown", "Lat Pulldown", [.lats], [.biceps, .upperBack], .cable, 0.65),
            ex("barbellRow", "Barbell Row", [.upperBack, .lats], [.biceps, .lowerBack], .barbell, 0.85),
            ex("dbRow", "Dumbbell Row", [.lats, .upperBack], [.biceps], .dumbbell, 0.7),
            ex("seatedCableRow", "Seated Cable Row", [.upperBack, .lats], [.biceps], .cable, 0.65),
            ex("chestSupportedRow", "Chest-Supported Row", [.upperBack], [.lats, .biceps], .machine, 0.6),
            ex("invertedRow", "Inverted Row", [.upperBack, .lats], [.biceps, .core], .bodyweight, 0.7, bw: 0.6),
            ex("facePull", "Face Pull", [.upperBack, .shoulders], [], .cable, 0.4),
            ex("shrug", "Shrug", [.upperBack], [.forearms], .dumbbell, 0.4),
            ex("backExtension", "Back Extension", [.lowerBack], [.glutes, .hamstrings], .bodyweight, 0.5, bw: 0.5),
            ex("goodMorning", "Good Morning", [.hamstrings, .lowerBack], [.glutes], .barbell, 0.8),
            // Shoulders
            ex("overheadPress", "Overhead Press", [.shoulders], [.triceps, .core], .barbell, 0.85),
            ex("dbShoulderPress", "Dumbbell Shoulder Press", [.shoulders], [.triceps], .dumbbell, 0.75),
            ex("arnoldPress", "Arnold Press", [.shoulders], [.triceps], .dumbbell, 0.7),
            ex("lateralRaise", "Lateral Raise", [.shoulders], [], .dumbbell, 0.4),
            ex("rearDeltFly", "Rear Delt Fly", [.shoulders, .upperBack], [], .dumbbell, 0.4),
            ex("frontRaise", "Front Raise", [.shoulders], [], .dumbbell, 0.4),
            ex("uprightRow", "Upright Row", [.shoulders, .upperBack], [.biceps], .barbell, 0.55),
            ex("pushPress", "Push Press", [.shoulders], [.triceps, .quads, .glutes], .barbell, 0.95),
            // Arms
            ex("bicepCurl", "Bicep Curl", [.biceps], [.forearms], .dumbbell, 0.4),
            ex("barbellCurl", "Barbell Curl", [.biceps], [.forearms], .barbell, 0.45),
            ex("hammerCurl", "Hammer Curl", [.biceps, .forearms], [], .dumbbell, 0.4),
            ex("cableCurl", "Cable Curl", [.biceps], [.forearms], .cable, 0.4),
            ex("tricepPushdown", "Tricep Pushdown", [.triceps], [], .cable, 0.4),
            ex("skullCrusher", "Skull Crusher", [.triceps], [], .barbell, 0.45),
            ex("overheadTricep", "Overhead Tricep Extension", [.triceps], [], .dumbbell, 0.4),
            ex("closeGripBench", "Close-Grip Bench Press", [.triceps, .chest], [.shoulders], .barbell, 0.8),
            ex("wristCurl", "Wrist Curl", [.forearms], [], .dumbbell, 0.25),
            ex("farmerCarry", "Farmer's Carry", [.forearms, .upperBack], [.core, .glutes], .dumbbell, 0.7, .seconds),
            // Core
            ex("plank", "Plank", [.core], [.shoulders], .bodyweight, 0.4, bw: 0.6, .seconds),
            ex("sidePlank", "Side Plank", [.core], [.shoulders], .bodyweight, 0.35, bw: 0.5, .seconds),
            ex("crunch", "Crunch", [.core], [], .bodyweight, 0.25, bw: 0.3),
            ex("hangingLegRaise", "Hanging Leg Raise", [.core], [.forearms], .bodyweight, 0.5, bw: 0.35),
            ex("abWheel", "Ab Wheel Rollout", [.core], [.shoulders, .lats], .other, 0.55, bw: 0.5),
            ex("russianTwist", "Russian Twist", [.core], [], .medicineBall, 0.35, bw: 0.2),
            ex("deadBug", "Dead Bug", [.core], [], .bodyweight, 0.3, bw: 0.2),
            ex("cableCrunch", "Cable Crunch", [.core], [], .cable, 0.4),
            // Golf and rotational power
            ex("medBallRotationalThrow", "Med Ball Rotational Throw", [.core, .glutes], [.shoulders, .lats], .medicineBall, 0.7),
            ex("medBallSlam", "Med Ball Slam", [.core, .lats], [.shoulders], .medicineBall, 0.65),
            ex("cableWoodchop", "Cable Woodchop", [.core], [.shoulders, .glutes], .cable, 0.55),
            ex("pallofPress", "Pallof Press", [.core], [.shoulders], .cable, 0.4),
            ex("landmineRotation", "Landmine Rotation", [.core, .shoulders], [.glutes], .barbell, 0.6),
            ex("landminePress", "Landmine Press", [.shoulders, .chest], [.triceps, .core], .barbell, 0.65),
            ex("bandRotation", "Band Trunk Rotation", [.core], [], .band, 0.3),
            ex("splitStanceRow", "Split-Stance Cable Row", [.lats, .upperBack], [.core, .glutes], .cable, 0.6),
            ex("lateralBound", "Lateral Bound", [.glutes, .quads], [.calves], .bodyweight, 0.7, bw: 1.0),
            ex("copenhagenPlank", "Copenhagen Plank", [.core], [.glutes], .bodyweight, 0.45, bw: 0.5, .seconds),
            // Olympic and full body
            ex("powerClean", "Power Clean", [.glutes, .hamstrings, .upperBack], [.quads, .shoulders], .barbell, 1.15),
            ex("thruster", "Thruster", [.quads, .shoulders], [.glutes, .triceps], .barbell, 1.0),
            ex("burpee", "Burpee", [.quads, .chest], [.shoulders, .core], .bodyweight, 0.8, bw: 0.8),
            ex("sledPush", "Sled Push", [.quads, .glutes], [.calves], .other, 0.9, .seconds),
            ex("turkishGetUp", "Turkish Get-Up", [.shoulders, .core], [.glutes], .kettlebell, 0.8),
        ]
    }()

    private static let byID: [String: Exercise] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    public static func exercise(_ id: String) -> Exercise? { byID[id] }
}

// MARK: - Workouts

public struct StrengthSet: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// Reps, or seconds for timed exercises.
    public var reps: Int
    /// Added weight in kg (negative for assisted bodyweight moves).
    public var weightKg: Double
    public var done: Bool

    public init(id: UUID = UUID(), reps: Int, weightKg: Double, done: Bool = false) {
        self.id = id
        self.reps = reps
        self.weightKg = weightKg
        self.done = done
    }
}

public struct StrengthEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var exerciseID: String
    public var sets: [StrengthSet]

    public init(id: UUID = UUID(), exerciseID: String, sets: [StrengthSet]) {
        self.id = id
        self.exerciseID = exerciseID
        self.sets = sets
    }

    public var exercise: Exercise? { ExerciseCatalog.exercise(exerciseID) }
    public var doneSets: [StrengthSet] { sets.filter(\.done) }
}

public struct StrengthWorkout: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var start: Date
    public var end: Date?
    public var entries: [StrengthEntry]

    public init(id: UUID = UUID(), name: String, start: Date = Date(), end: Date? = nil, entries: [StrengthEntry] = []) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.entries = entries
    }

    public var dayKey: String { DayKey.string(from: start) }
    public var doneSetCount: Int { entries.reduce(0) { $0 + $1.doneSets.count } }
    public var durationMinutes: Double { ((end ?? Date()).timeIntervalSince(start)) / 60 }
}

public struct StrengthTemplate: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var entries: [StrengthEntry]

    public init(id: UUID = UUID(), name: String, entries: [StrengthEntry]) {
        self.id = id
        self.name = name
        self.entries = entries
    }

    /// Ready-made starting templates.
    public static let defaults: [StrengthTemplate] = {
        func t(_ name: String, _ items: [(String, Int, Int)]) -> StrengthTemplate {
            StrengthTemplate(name: name, entries: items.map { id, sets, reps in
                StrengthEntry(exerciseID: id, sets: (0..<sets).map { _ in StrengthSet(reps: reps, weightKg: 0) })
            })
        }
        return [
            t("Golf Strength", [("trapBarDeadlift", 3, 5), ("bulgarianSplitSquat", 3, 8), ("medBallRotationalThrow", 3, 6), ("cableWoodchop", 3, 10), ("pallofPress", 3, 10), ("dbRow", 3, 10)]),
            t("Full Body", [("backSquat", 3, 5), ("benchPress", 3, 5), ("barbellRow", 3, 8), ("rdl", 3, 8), ("plank", 3, 45)]),
            t("Upper Body", [("benchPress", 4, 6), ("pullUp", 4, 8), ("dbShoulderPress", 3, 10), ("seatedCableRow", 3, 10), ("bicepCurl", 2, 12), ("tricepPushdown", 2, 12)]),
            t("Lower Body", [("backSquat", 4, 5), ("rdl", 3, 8), ("walkingLunge", 3, 10), ("legCurl", 3, 12), ("calfRaise", 3, 15)]),
            t("Push", [("benchPress", 4, 6), ("overheadPress", 3, 8), ("inclineDbBench", 3, 10), ("lateralRaise", 3, 15), ("tricepPushdown", 3, 12)]),
            t("Pull", [("deadlift", 3, 5), ("pullUp", 3, 8), ("barbellRow", 3, 8), ("facePull", 3, 15), ("hammerCurl", 3, 12)]),
        ]
    }()
}

// MARK: - Speicher

/// Saves strength workouts, templates and the workout in progress (strength.json).
public final class StrengthStore {
    private struct Snapshot: Codable {
        var workouts: [StrengthWorkout]
        var templates: [StrengthTemplate]
        var active: StrengthWorkout?
    }

    public private(set) var workouts: [StrengthWorkout] = []
    public var templates: [StrengthTemplate] = StrengthTemplate.defaults
    public var active: StrengthWorkout?
    public let fileURL: URL

    public init(directory: URL, filename: String = "strength.json") {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent(filename)
        load()
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        workouts = snapshot.workouts
        templates = snapshot.templates
        active = snapshot.active
    }

    @discardableResult
    public func save() -> Bool {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(Snapshot(workouts: workouts, templates: templates, active: active)) else { return false }
        return (try? data.write(to: fileURL, options: .atomic)) != nil
    }

    public func upsert(_ workout: StrengthWorkout) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index] = workout
        } else {
            workouts.append(workout)
        }
        workouts.sort { $0.start < $1.start }
    }

    public func delete(_ id: UUID) {
        workouts.removeAll { $0.id == id }
    }

    public func workouts(on key: String) -> [StrengthWorkout] {
        workouts.filter { $0.dayKey == key && $0.end != nil }
    }

    public func wipe() {
        workouts = []
        templates = StrengthTemplate.defaults
        active = nil
        try? FileManager.default.removeItem(at: fileURL)
    }
}
