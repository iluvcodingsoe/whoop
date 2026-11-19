import Foundation

/// Stimmung im Tages-Log (1 = schlecht … 5 = super).
public enum Mood: Int, Codable, CaseIterable, Sendable, Identifiable {
    case awful = 1
    case low = 2
    case okay = 3
    case good = 4
    case great = 5

    public var id: Int { rawValue }

    public var symbol: String {
        switch self {
        case .awful: return "cloud.rain"
        case .low: return "cloud"
        case .okay: return "cloud.sun"
        case .good: return "sun.max"
        case .great: return "sparkles"
        }
    }

    public func label(_ lang: PulseLanguage) -> String {
        switch (self, lang) {
        case (.awful, .de): return "Mies"
        case (.awful, .en): return "Awful"
        case (.low, .de): return "Gedrückt"
        case (.low, .en): return "Low"
        case (.okay, .de): return "Okay"
        case (.okay, .en): return "Okay"
        case (.good, .de): return "Gut"
        case (.good, .en): return "Good"
        case (.great, .de): return "Super"
        case (.great, .en): return "Great"
        }
    }
}

/// Eine Mahlzeit im Tages-Log.
public struct FoodItem: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var time: Date

    public init(id: UUID = UUID(), name: String, time: Date = Date()) {
        self.id = id
        self.name = name
        self.time = time
    }
}

/// Selbst erfasste Aktivität: geplant (ohne Start), läuft (ohne Ende) oder fertig.
public struct LoggedActivity: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var type: String
    public var start: Date?
    public var end: Date?

    public init(id: UUID = UUID(), type: String, start: Date? = nil, end: Date? = nil) {
        self.id = id
        self.type = type
        self.start = start
        self.end = end
    }

    public var isPlanned: Bool { start == nil }
    public var isActive: Bool { start != nil && end == nil }
    public var isDone: Bool { start != nil && end != nil }
}

/// Was der Nutzer an einem Tag selbst einträgt: Wasser, Essen, Gewicht, Stimmung.
/// Bleibt nur auf dem Gerät.
public struct DailyLog: Codable, Sendable {
    public var date: String // "yyyy-MM-dd"
    /// Gläser à 250 ml.
    public var waterGlasses: Int
    public var food: [FoodItem]
    public var weightKg: Double?
    public var mood: Mood?
    /// Selbst erfasste oder geplante Aktivitäten (optional, damit alte Dateien lesbar bleiben).
    public var activities: [LoggedActivity]?

    public init(date: String, waterGlasses: Int = 0, food: [FoodItem] = [], weightKg: Double? = nil, mood: Mood? = nil, activities: [LoggedActivity]? = nil) {
        self.date = date
        self.waterGlasses = waterGlasses
        self.food = food
        self.weightKg = weightKg
        self.mood = mood
        self.activities = activities
    }

    public var isEmpty: Bool {
        waterGlasses == 0 && food.isEmpty && weightKg == nil && mood == nil && (activities ?? []).isEmpty
    }
}

/// Persistiert Tages-Logs in einer eigenen JSON-Datei (wie das Journal), damit
/// ein Sync sie nie überschreibt.
public final class DailyLogStore {
    public private(set) var logs: [String: DailyLog] = [:]
    public let fileURL: URL

    public init(directory: URL, filename: String = "daylog.json") {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent(filename)
        load()
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: DailyLog].self, from: data) else { return }
        logs = decoded
    }

    @discardableResult
    public func save() -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(logs) else { return false }
        return (try? data.write(to: fileURL, options: .atomic)) != nil
    }

    public func log(for key: String) -> DailyLog {
        logs[key] ?? DailyLog(date: key)
    }

    public func update(_ key: String, _ change: (inout DailyLog) -> Void) {
        var log = log(for: key)
        change(&log)
        logs[key] = log.isEmpty ? nil : log
    }

    /// Letztes eingetragenes Gewicht bis einschließlich `key`.
    public func latestWeight(upTo key: String) -> (date: String, kg: Double)? {
        logs.values
            .filter { $0.date <= key && $0.weightKg != nil }
            .max { $0.date < $1.date }
            .map { ($0.date, $0.weightKg!) }
    }

    public func wipe() {
        logs = [:]
        try? FileManager.default.removeItem(at: fileURL)
    }
}
