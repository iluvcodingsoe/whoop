import Foundation

// MARK: - Journal-Verhalten

/// Categories of the behavior catalog.
public enum JournalCategory: String, CaseIterable, Sendable, Identifiable {
    case lifestyle, nutrition, sleep, recovery, supplements, mental, health

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .lifestyle: return "Lifestyle"
        case .nutrition: return "Nutrition"
        case .sleep: return "Sleep"
        case .recovery: return "Recovery"
        case .supplements: return "Supplements"
        case .mental: return "Mental Wellbeing"
        case .health: return "Health"
        }
    }
}

/// One yes/no question in the journal.
public struct JournalBehavior: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let question: String
    public let symbol: String
    public let category: JournalCategory
}

/// All behaviors that can be tracked. Ids of the original eight factors are kept
/// so older journal entries stay readable.
public enum JournalCatalog {
    public static let all: [JournalBehavior] = {
        let raw: [(String, String, String, String, JournalCategory)] = [
            // Lifestyle
            ("exercised", "Worked out", "Work out?", "figure.run", .lifestyle),
            ("playedGolf", "Played golf", "Play a round of golf?", "figure.golf", .lifestyle),
            ("practiced", "Practiced", "Have a practice session?", "sportscourt", .lifestyle),
            ("outdoors", "Time outdoors", "Spend time outdoors?", "sun.max", .lifestyle),
            ("morningSun", "Morning sunlight", "Get sunlight within an hour of waking?", "sunrise", .lifestyle),
            ("screenBeforeBed", "Screen before bed", "View a screen device in bed?", "iphone", .lifestyle),
            ("travel", "Traveled", "Travel?", "airplane", .lifestyle),
            ("timeZone", "Changed time zones", "Cross time zones?", "globe.americas", .lifestyle),
            ("schoolDay", "School day", "Have school?", "graduationcap", .lifestyle),
            ("examDay", "Exam or test", "Take an exam or test?", "doc.text", .lifestyle),
            ("longCommute", "Long commute", "Spend over an hour commuting?", "car", .lifestyle),
            ("standingDesk", "Stood a lot", "Spend most of the day on your feet?", "figure.stand", .lifestyle),
            ("socialTime", "Time with friends", "Spend time with friends?", "person.2", .lifestyle),
            ("familyTime", "Family time", "Spend quality time with family?", "house", .lifestyle),
            ("gaming", "Video games", "Play video games?", "gamecontroller", .lifestyle),
            ("reading", "Read", "Read a book?", "book", .lifestyle),
            ("hydrated", "Hydrated", "Feel well hydrated?", "drop", .lifestyle),
            ("highAltitude", "High altitude", "Spend time at high altitude?", "mountain.2", .lifestyle),
            ("hotWeather", "Hot weather", "Spend time in hot weather?", "thermometer.sun", .lifestyle),
            ("walkAfterMeal", "Walk after a meal", "Take a walk after a meal?", "figure.walk", .lifestyle),
            // Nutrition
            ("alcohol", "Alcohol", "Have any alcoholic drinks?", "wineglass", .nutrition),
            ("caffeine", "Caffeine", "Have any caffeine?", "cup.and.saucer", .nutrition),
            ("lateCaffeine", "Late caffeine", "Have caffeine after 2 PM?", "cup.and.saucer.fill", .nutrition),
            ("energyDrink", "Energy drink", "Have an energy drink?", "bolt", .nutrition),
            ("lateMeal", "Late meal", "Eat within 2 hours of bed?", "fork.knife", .nutrition),
            ("breakfast", "Ate breakfast", "Eat breakfast?", "takeoutbag.and.cup.and.straw", .nutrition),
            ("skippedMeal", "Skipped a meal", "Skip a meal?", "fork.knife.circle", .nutrition),
            ("protein", "Protein goal", "Hit your protein goal?", "fish", .nutrition),
            ("fruitsVeg", "Fruits and vegetables", "Eat fruits and vegetables?", "carrot", .nutrition),
            ("addedSugar", "Added sugar", "Have foods with added sugar?", "birthday.cake", .nutrition),
            ("fastFood", "Fast food", "Eat fast food?", "takeoutbag.and.cup.and.straw.fill", .nutrition),
            ("processedFood", "Processed food", "Eat mostly processed food?", "shippingbox", .nutrition),
            ("dairy", "Dairy", "Have dairy?", "mug", .nutrition),
            ("redMeat", "Red meat", "Eat red meat?", "flame", .nutrition),
            ("spicyFood", "Spicy food", "Eat spicy food?", "flame.fill", .nutrition),
            ("highSodium", "Salty food", "Eat a lot of salty food?", "aqi.medium", .nutrition),
            ("bigDinner", "Large dinner", "Eat a large dinner?", "fork.knife", .nutrition),
            ("intermittentFasting", "Intermittent fasting", "Practice intermittent fasting?", "timer", .nutrition),
            ("plantBased", "Plant-based day", "Eat only plant-based food?", "leaf", .nutrition),
            ("sportsDrink", "Sports drink", "Have a sports drink?", "waterbottle", .nutrition),
            ("water3l", "Lots of water", "Drink over 2 liters of water?", "drop.fill", .nutrition),
            ("homeCooked", "Home-cooked meals", "Eat mostly home-cooked meals?", "frying.pan", .nutrition),
            // Sleep
            ("readInBed", "Read in bed", "Read (non-screened device) while in bed?", "book.closed", .sleep),
            ("sharedBed", "Shared bed", "Share your bed?", "bed.double", .sleep),
            ("petInBed", "Pet in bed", "Sleep with a pet in the bed?", "pawprint", .sleep),
            ("sleepMask", "Sleep mask", "Wear a sleep mask?", "eye.slash", .sleep),
            ("earplugs", "Earplugs", "Wear earplugs?", "ear", .sleep),
            ("whiteNoise", "White noise", "Use a white noise machine?", "waveform", .sleep),
            ("coolRoom", "Cool bedroom", "Sleep in a cool room?", "snowflake", .sleep),
            ("consistentBedtime", "Consistent bedtime", "Go to bed at your usual time?", "clock", .sleep),
            ("nap", "Napped", "Take a nap?", "powersleep", .sleep),
            ("lateNight", "Stayed up late", "Stay up past midnight?", "moon.zzz", .sleep),
            ("phoneOutside", "Phone out of bedroom", "Keep your phone outside the bedroom?", "iphone.slash", .sleep),
            ("blueLightGlasses", "Blue light glasses", "Wear blue light blocking glasses?", "eyeglasses", .sleep),
            ("darkRoom", "Dark bedroom", "Sleep in a fully dark room?", "moon", .sleep),
            ("woke", "Woke during night", "Wake up during the night?", "alarm", .sleep),
            ("hotShower", "Warm shower before bed", "Take a warm shower before bed?", "shower", .sleep),
            ("alarmClock", "Woke to alarm", "Wake up to an alarm?", "alarm.fill", .sleep),
            // Recovery
            ("stretching", "Stretched", "Stretch?", "figure.flexibility", .recovery),
            ("foamRolling", "Foam rolling", "Foam roll?", "cylinder", .recovery),
            ("massage", "Massage", "Get a massage?", "hand.raised", .recovery),
            ("coldPlunge", "Cold plunge", "Take a cold plunge or ice bath?", "snowflake.circle", .recovery),
            ("sauna", "Sauna", "Use a sauna?", "flame.circle", .recovery),
            ("yoga", "Yoga", "Do yoga?", "figure.yoga", .recovery),
            ("restDay", "Rest day", "Take a rest day?", "sofa", .recovery),
            ("compression", "Compression", "Use compression gear?", "figure.socialdance", .recovery),
            ("percussion", "Massage gun", "Use a massage gun?", "hand.point.up", .recovery),
            ("activeRecovery", "Active recovery", "Do light active recovery?", "figure.walk.motion", .recovery),
            ("sore", "Sore muscles", "Feel sore?", "bandage", .recovery),
            ("injured", "Injured", "Have an injury?", "cross.case", .recovery),
            // Supplements
            ("magnesium", "Magnesium", "Take magnesium?", "pills", .supplements),
            ("melatonin", "Melatonin", "Take melatonin?", "moon.stars", .supplements),
            ("creatine", "Creatine", "Take creatine?", "capsule", .supplements),
            ("proteinShake", "Protein shake", "Have a protein shake?", "takeoutbag.and.cup.and.straw", .supplements),
            ("multivitamin", "Multivitamin", "Take a multivitamin?", "pills.fill", .supplements),
            ("vitaminD", "Vitamin D", "Take vitamin D?", "sun.min", .supplements),
            ("omega3", "Omega-3", "Take omega-3 or fish oil?", "drop.circle", .supplements),
            ("electrolytes", "Electrolytes", "Take electrolytes?", "bolt.circle", .supplements),
            ("probiotic", "Probiotic", "Take a probiotic?", "allergens", .supplements),
            ("zinc", "Zinc", "Take zinc?", "circle.hexagongrid", .supplements),
            ("ashwagandha", "Ashwagandha", "Take ashwagandha?", "leaf.circle", .supplements),
            ("preWorkout", "Pre-workout", "Take a pre-workout supplement?", "bolt.heart", .supplements),
            // Mental wellbeing
            ("stress", "Stress", "Feel stressed?", "bolt.heart", .mental),
            ("meditation", "Meditated", "Meditate?", "brain.head.profile", .mental),
            ("journaling", "Journaled", "Journal your thoughts?", "pencil.and.scribble", .mental),
            ("breathwork", "Breathwork", "Do breathwork?", "wind", .mental),
            ("gratitude", "Gratitude", "Practice gratitude?", "heart.text.square", .mental),
            ("anxious", "Anxious", "Feel anxious?", "exclamationmark.bubble", .mental),
            ("productive", "Productive day", "Have a productive day?", "checkmark.seal", .mental),
            ("competition", "Competed", "Compete in a tournament or game?", "trophy", .mental),
            ("lonely", "Felt lonely", "Feel lonely?", "person", .mental),
            ("motivated", "Motivated", "Feel motivated?", "flame", .mental),
            ("mentallyTired", "Mentally drained", "Feel mentally drained?", "battery.25", .mental),
            ("happy", "Happy", "Feel happy overall?", "face.smiling", .mental),
            // Health
            ("sick", "Sick", "Feel sick or ill?", "thermometer.medium", .health),
            ("headache", "Headache", "Have a headache?", "brain", .health),
            ("allergies", "Allergies", "Have allergy symptoms?", "aqi.high", .health),
            ("congestion", "Congestion", "Have congestion?", "nose", .health),
            ("medication", "Medication", "Take any medication?", "cross.vial", .health),
            ("painReliever", "Pain reliever", "Take a pain reliever?", "pill", .health),
            ("vaccine", "Vaccine", "Get a vaccine?", "syringe", .health),
            ("upsetStomach", "Upset stomach", "Have an upset stomach?", "exclamationmark.triangle", .health),
            ("dehydrated", "Dehydrated", "Feel dehydrated?", "drop.triangle", .health),
            ("sunburn", "Sunburn", "Get a sunburn?", "sun.max.trianglebadge.exclamationmark", .health),
        ]
        return raw.map { JournalBehavior(id: $0.0, title: $0.1, question: $0.2, symbol: $0.3, category: $0.4) }
    }()

    private static let byID: [String: JournalBehavior] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    public static func behavior(_ id: String) -> JournalBehavior? { byID[id] }

    /// Starting set for new users.
    public static let defaultIDs = ["alcohol", "lateCaffeine", "lateMeal", "screenBeforeBed", "stress", "exercised", "stretching", "hydrated"]

    /// The eight factors of the old journal (stored as a set without explicit "no").
    public static let legacyIDs = ["alcohol", "lateCaffeine", "lateMeal", "stress", "sick", "screenBeforeBed", "exercised", "sex"]

    /// Recommended upper limit for clear results.
    public static let recommendedMax = 10
}

/// One day of journal answers: behavior id -> yes (true) or no (false).
/// Unanswered behaviors are missing from the map.
public struct JournalEntry: Codable, Sendable, Equatable {
    public var date: String // "yyyy-MM-dd"
    public var answers: [String: Bool]

    public init(date: String, answers: [String: Bool] = [:]) {
        self.date = date
        self.answers = answers
    }

    public var isEmpty: Bool { answers.isEmpty }

    public func answer(_ id: String) -> Bool? { answers[id] }

    /// Ids answered with yes.
    public var yesIDs: [String] {
        answers.filter { $0.value }.map(\.key).sorted()
    }

    private enum CodingKeys: String, CodingKey { case date, answers, factors }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        if let answers = try c.decodeIfPresent([String: Bool].self, forKey: .answers) {
            self.answers = answers
        } else {
            // Old format: a set of factors that were "on". Every other old factor was "off".
            let on = Set(try c.decodeIfPresent([String].self, forKey: .factors) ?? [])
            var answers: [String: Bool] = [:]
            if !on.isEmpty {
                for id in JournalCatalog.legacyIDs { answers[id] = on.contains(id) }
            }
            self.answers = answers
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(answers, forKey: .answers)
    }
}

// MARK: - Journal-Speicher

/// Persistiert Journal-Einträge in einer **eigenen** JSON-Datei — getrennt vom
/// MetricsStore, damit ein Sync (der `days.json` ersetzt) das Journal nie
/// überschreibt.
public final class JournalStore {
    public private(set) var entries: [String: JournalEntry] = [:]
    public let fileURL: URL

    public init(directory: URL, filename: String = "journal.json") {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent(filename)
        load()
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: JournalEntry].self, from: data) else { return }
        entries = decoded
    }

    @discardableResult
    public func save() -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(entries) else { return false }
        return (try? data.write(to: fileURL, options: .atomic)) != nil
    }

    public func entry(for key: String) -> JournalEntry {
        entries[key] ?? JournalEntry(date: key)
    }

    /// Sets yes/no for a behavior, or clears it with nil.
    public func setAnswer(_ id: String, _ value: Bool?, on key: String) {
        var entry = entry(for: key)
        entry.answers[id] = value
        entries[key] = entry.isEmpty ? nil : entry
    }

    public func answer(_ id: String, on key: String) -> Bool? {
        entries[key]?.answers[id]
    }

    public func wipe() {
        entries = [:]
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - Korrelations-Engine

/// Wie belastbar ein Insight ist.
public enum InsightConfidence: String, Sendable {
    /// Differenz übersteigt das Doppelte ihres Standardfehlers (~95 %-Niveau).
    case solid
    /// Mindestfallzahl erreicht, aber Differenz noch im Rauschbereich.
    case emerging
}

public struct FactorInsight: Sendable, Identifiable {
    public let behaviorID: String
    /// Avg next-day recovery on "yes" days.
    public let avgWith: Double
    /// Avg next-day recovery on "no" days.
    public let avgWithout: Double
    /// Difference in recovery points (negative = behavior lowers recovery).
    public let delta: Double
    /// Standard error of the difference (Welch).
    public let standardError: Double
    public let confidence: InsightConfidence
    public let daysWith: Int
    public let daysWithout: Int

    public var id: String { behaviorID }
    public var behavior: JournalBehavior? { JournalCatalog.behavior(behaviorID) }
    public var title: String { behavior?.title ?? behaviorID }
    public var symbol: String { behavior?.symbol ?? "questionmark.circle" }
    /// Relative change of recovery in percent.
    public var percentChange: Double { avgWithout > 0 ? delta / avgWithout * 100 : 0 }
}

/// Correlates journal answers with the recovery of the following day.
/// Needs at least 5 "yes" and 5 "no" answers within the last 90 days.
/// Correlation, not proof of cause.
public enum JournalEngine {
    public static let minDaysPerGroup = 5
    public static let windowDays = 90
    public static let assessmentMinRecoveryDays = 28

    public static func assessmentReady(recoveryByDay: [String: Int]) -> Bool {
        recoveryByDay.count >= assessmentMinRecoveryDays
    }

    /// Count of yes/no answers with next-day recovery inside the window.
    public static func counts(
        for id: String,
        entries: [String: JournalEntry],
        recoveryByDay: [String: Int],
        today: String? = nil
    ) -> (yes: Int, no: Int) {
        let values = groups(for: id, entries: entries, recoveryByDay: recoveryByDay, today: today)
        return (values.with.count, values.without.count)
    }

    private static func groups(
        for id: String,
        entries: [String: JournalEntry],
        recoveryByDay: [String: Int],
        today: String?
    ) -> (with: [Double], without: [Double]) {
        let start = today.map { DayKey.addDays($0, -windowDays) }
        var with: [Double] = []
        var without: [Double] = []
        for (dayKey, entry) in entries {
            if let start, dayKey < start { continue }
            guard let answer = entry.answers[id],
                  let recovery = recoveryByDay[DayKey.addDays(dayKey, 1)] else { continue }
            if answer { with.append(Double(recovery)) } else { without.append(Double(recovery)) }
        }
        return (with, without)
    }

    public static func insights(
        entries: [String: JournalEntry],
        recoveryByDay: [String: Int],
        today: String? = nil
    ) -> [FactorInsight] {
        var ids = Set<String>()
        for entry in entries.values { ids.formUnion(entry.answers.keys) }

        var result: [FactorInsight] = []
        for id in ids {
            let (withValues, withoutValues) = groups(for: id, entries: entries, recoveryByDay: recoveryByDay, today: today)
            guard withValues.count >= minDaysPerGroup,
                  withoutValues.count >= minDaysPerGroup else { continue }

            let avgWith = Stats.mean(withValues)
            let avgWithout = Stats.mean(withoutValues)
            let delta = avgWith - avgWithout
            let varWith = pow(Stats.standardDeviation(withValues), 2)
            let varWithout = pow(Stats.standardDeviation(withoutValues), 2)
            let se = sqrt(varWith / Double(withValues.count) + varWithout / Double(withoutValues.count))

            result.append(FactorInsight(
                behaviorID: id,
                avgWith: avgWith,
                avgWithout: avgWithout,
                delta: delta,
                standardError: se,
                confidence: abs(delta) > 2 * max(se, 0.001) ? .solid : .emerging,
                daysWith: withValues.count,
                daysWithout: withoutValues.count
            ))
        }
        return result.sorted { abs($0.delta) > abs($1.delta) }
    }
}
