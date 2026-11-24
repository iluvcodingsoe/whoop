import Foundation
import Observation
import AuthenticationServices
import BackgroundTasks
import UIKit

/// Zentrales App-Modell: hält Store, Auth, Einstellungen und die berechneten
/// Whoop-Metriken (Recovery, Strain, Schlaf) für alle Views bereit.
@MainActor
@Observable
final class AppModel {
    // MARK: - Einstellungen (in UserDefaults persistiert)

    private enum Keys {
        static let clientID = "google.clientID"
        static let onboarded = "app.onboarded"
        static let demoMode = "app.demoMode"
        static let daysBack = "sync.daysBack"
        static let journalBehaviors = "journal.behaviors"
        static let usePounds = "units.pounds"
        static let hrDaysBack = "sync.hrDaysBack"
        static let sleepNeed = "calc.sleepNeedMinutes"
        static let age = "calc.age"
        static let sex = "calc.sex"
        static let heightCm = "profile.heightCm"
        static let stepGoal = "goal.steps"
        static let plannedBedtime = "plan.bedtimeMinutes"
        static let weightKg = "profile.weightKg"
        static let maxHR = "calc.maxHROverride"
        static let lastSync = "sync.lastSyncAt"
        static let backfilledDays = "sync.backfilledDays"
        static let notifications = "notify.enabled"
        static let connectedAt = "auth.connectedAt"
        static let moduleOrder = "dashboard.moduleOrder"
        static let hiddenModules = "dashboard.hiddenModules"
        static let language = "app.language"
    }

    /// Identifier des Hintergrund-Sync-Tasks (muss in Info.plist unter
    /// BGTaskSchedulerPermittedIdentifiers stehen).
    static let refreshTaskID = "net.dehlwes.pulse.refresh"

    /// App-Sprache; wirkt sofort auf alle Texte (kein Neustart nötig).
    var language: PulseLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            Fmt.language = language
            recomputeAll() // AgeEngine-Komponenten tragen lokalisierte Texte
        }
    }

    /// Kurzform für zweisprachige Texte direkt am Verwendungsort.
    func loc(_ de: String, _ en: String) -> String {
        language == .de ? de : en
    }

    var clientID: String {
        didSet { defaults.set(clientID, forKey: Keys.clientID) }
    }
    var onboarded: Bool {
        didSet { defaults.set(onboarded, forKey: Keys.onboarded) }
    }
    var demoMode: Bool {
        didSet { defaults.set(demoMode, forKey: Keys.demoMode) }
    }
    var daysBack: Int {
        didSet { defaults.set(daysBack, forKey: Keys.daysBack) }
    }
    var hrDaysBack: Int {
        didSet { defaults.set(hrDaysBack, forKey: Keys.hrDaysBack) }
    }
    /// Behaviors asked in the journal, in the user's order.
    var trackedBehaviorIDs: [String] {
        didSet { defaults.set(trackedBehaviorIDs, forKey: Keys.journalBehaviors) }
    }
    var baseSleepNeedMinutes: Double {
        didSet {
            defaults.set(baseSleepNeedMinutes, forKey: Keys.sleepNeed)
            recomputeAll()
        }
    }
    var age: Int {
        didSet {
            defaults.set(age, forKey: Keys.age)
            recomputeAll()
        }
    }
    var sex: BiologicalSex {
        didSet {
            defaults.set(sex.rawValue, forKey: Keys.sex)
            recomputeAll()
        }
    }
    /// Körpergröße in cm (Profil; fließt aktuell in keine Score-Berechnung ein).
    var heightCm: Double {
        didSet { defaults.set(heightCm, forKey: Keys.heightCm) }
    }
    /// Tägliches Schrittziel.
    var stepGoal: Int {
        didSet { defaults.set(stepGoal, forKey: Keys.stepGoal) }
    }
    /// Selbst gewählte Bettzeit (Minuten nach Mitternacht), nil = Empfehlung nutzen.
    var plannedBedtimeMinutes: Int? {
        didSet {
            if let plannedBedtimeMinutes {
                defaults.set(plannedBedtimeMinutes, forKey: Keys.plannedBedtime)
            } else {
                defaults.removeObject(forKey: Keys.plannedBedtime)
            }
        }
    }
    /// Gewicht in kg (Profil; VO₂max ist bereits pro kg normalisiert).
    var weightKg: Double {
        didSet { defaults.set(weightKg, forKey: Keys.weightKg) }
    }
    /// Show strength weights in pounds (stored in kg).
    var usePounds: Bool {
        didSet { defaults.set(usePounds, forKey: Keys.usePounds) }
    }
    /// 0 = automatisch (Tanaka-Formel)
    var maxHROverride: Double {
        didSet {
            defaults.set(maxHROverride, forKey: Keys.maxHR)
            recomputeAll()
        }
    }
    var lastSyncAt: Date? {
        didSet {
            if let lastSyncAt {
                defaults.set(lastSyncAt.timeIntervalSince1970, forKey: Keys.lastSync)
            } else {
                defaults.removeObject(forKey: Keys.lastSync)
            }
        }
    }
    /// Opt-in für morgendliche Recovery-Benachrichtigung + Hintergrund-Sync.
    private(set) var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications) }
    }
    /// Zeitpunkt der letzten Verbindung (für die 7-Tage-Ablaufwarnung).
    private(set) var connectedAt: Date? {
        didSet {
            if let connectedAt {
                defaults.set(connectedAt.timeIntervalSince1970, forKey: Keys.connectedAt)
            } else {
                defaults.removeObject(forKey: Keys.connectedAt)
            }
        }
    }

    // MARK: - Laufzeit-Zustand

    private(set) var syncing = false
    private(set) var syncMessage = ""
    private(set) var syncFraction: Double = 0
    var lastError: String?
    private(set) var syncLog: [SyncLogEntry] = []
    var selectedDayKey: String
    private(set) var profileName: String?
    /// Tag, für den das Morgen-Journal-Popup gezeigt werden soll (i. d. R. gestern).
    var journalPrompt: JournalPrompt?

    // MARK: - Dashboard-Anpassung

    /// Reihenfolge ALLER Module (auch ausgeblendeter).
    private(set) var moduleOrder: [DashboardModule] = DashboardModule.allCases {
        didSet { defaults.set(moduleOrder.map(\.rawValue), forKey: Keys.moduleOrder) }
    }
    /// Ausgeblendete Module.
    private(set) var hiddenModules: Set<DashboardModule> = [] {
        didSet { defaults.set(hiddenModules.map(\.rawValue), forKey: Keys.hiddenModules) }
    }

    var visibleModules: [DashboardModule] {
        moduleOrder.filter { !hiddenModules.contains($0) }
    }

    func moveModules(from source: IndexSet, to destination: Int) {
        moduleOrder.move(fromOffsets: source, toOffset: destination)
    }

    func setModule(_ module: DashboardModule, visible: Bool) {
        if visible {
            hiddenModules.remove(module)
        } else {
            hiddenModules.insert(module)
        }
    }

    // MARK: - Daten & abgeleitete Metriken

    let store: MetricsStore
    let journal: JournalStore
    let dailyLogs: DailyLogStore
    let strength: StrengthStore
    /// Finished strength workouts, oldest first.
    var strengthWorkouts: [StrengthWorkout] = []
    var strengthTemplates: [StrengthTemplate] = []
    /// Workout being logged right now.
    var activeStrength: StrengthWorkout?
    var showStrengthLogger = false
    /// Template open in the editor sheet.
    var editingTemplate: StrengthTemplate?
    /// Activity opened from screenshot arguments.
    var screenshotActivity: ScreenshotActivity?
    var strengthScores: [UUID: StrengthScore] = [:]
    /// Logged activity to remove once its exercises are saved.
    var pendingReplaceActivity: (UUID, String)?
    let auth = GoogleAuth()
    private(set) var strainResults: [String: StrainResult] = [:]
    private(set) var sleepAnalyses: [String: SleepAnalysis] = [:]
    private(set) var recoveryResults: [String: RecoveryResult] = [:]
    private(set) var ageResults: [String: AgeResult] = [:]
    private(set) var journalInsights: [FactorInsight] = []
    /// Observabler Spiegel der Journal-Einträge. JournalStore ist eine normale
    /// Klasse (nicht @Observable) — ohne diesen Spiegel würden Toggles in der
    /// UI nicht sichtbar, weil SwiftUI keine Änderung mitbekommt.
    private(set) var journalEntries: [String: JournalEntry] = [:]
    /// Observabler Spiegel der Tages-Logs (Wasser, Essen, Gewicht, Stimmung).
    private(set) var dayLogs: [String: DailyLog] = [:]
    /// Aktiver Tab der Hauptnavigation.
    var selectedTab: MainTab = .home

    private let defaults = UserDefaults.standard

    init() {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pulse", isDirectory: true)
        store = MetricsStore(directory: directory)
        journal = JournalStore(directory: directory)
        dailyLogs = DailyLogStore(directory: directory)
        strength = StrengthStore(directory: directory)

        // Lokale Konstante, damit unten nicht self.language (Observable-Getter)
        // gelesen wird, bevor alle Stored Properties initialisiert sind.
        // Die App ist jetzt nur noch auf Englisch.
        let initialLanguage = PulseLanguage.en
        defaults.set(initialLanguage.rawValue, forKey: Keys.language)
        language = initialLanguage
        Fmt.language = initialLanguage

        clientID = defaults.string(forKey: Keys.clientID) ?? ""
        onboarded = defaults.bool(forKey: Keys.onboarded)
        demoMode = defaults.bool(forKey: Keys.demoMode)
        daysBack = (defaults.object(forKey: Keys.daysBack) as? Int) ?? 60
        hrDaysBack = (defaults.object(forKey: Keys.hrDaysBack) as? Int) ?? 14
        var tracked = (defaults.stringArray(forKey: Keys.journalBehaviors) ?? JournalCatalog.defaultIDs)
            .filter { JournalCatalog.behavior($0) != nil }
        if !defaults.bool(forKey: "journal.addedSleepGear") {
            for id in ["noseStrips", "retainers"] where !tracked.contains(id) { tracked.insert(id, at: 0) }
            defaults.set(true, forKey: "journal.addedSleepGear")
        }
        trackedBehaviorIDs = tracked
        defaults.set(tracked, forKey: Keys.journalBehaviors)
        baseSleepNeedMinutes = (defaults.object(forKey: Keys.sleepNeed) as? Double) ?? 456
        age = (defaults.object(forKey: Keys.age) as? Int) ?? 30
        sex = (defaults.string(forKey: Keys.sex)).flatMap(BiologicalSex.init(rawValue:)) ?? .unspecified
        heightCm = (defaults.object(forKey: Keys.heightCm) as? Double) ?? 175
        stepGoal = (defaults.object(forKey: Keys.stepGoal) as? Int) ?? 8000
        plannedBedtimeMinutes = defaults.object(forKey: Keys.plannedBedtime) as? Int
        weightKg = (defaults.object(forKey: Keys.weightKg) as? Double) ?? 75
        usePounds = (defaults.object(forKey: Keys.usePounds) as? Bool) ?? true
        maxHROverride = (defaults.object(forKey: Keys.maxHR) as? Double) ?? 0
        lastSyncAt = (defaults.object(forKey: Keys.lastSync) as? Double).map(Date.init(timeIntervalSince1970:))
        notificationsEnabled = defaults.bool(forKey: Keys.notifications)
        connectedAt = (defaults.object(forKey: Keys.connectedAt) as? Double).map(Date.init(timeIntervalSince1970:))
        selectedDayKey = DayKey.today()

        // Modul-Reihenfolge laden; neue Module (künftiger Versionen) hinten anfügen.
        var order = (defaults.stringArray(forKey: Keys.moduleOrder) ?? [])
            .compactMap(DashboardModule.init(rawValue:))
        for module in DashboardModule.allCases where !order.contains(module) {
            order.append(module)
        }
        moduleOrder = order
        hiddenModules = Set(
            (defaults.stringArray(forKey: Keys.hiddenModules) ?? [])
                .compactMap(DashboardModule.init(rawValue:))
        )

        refreshStrength(recompute: false)
        recomputeAll()
        applyScreenshotArguments()
    }

    /// Nur für automatische Design-Screenshots im Simulator (CI):
    /// `-screenshotDemo` startet Demo-Daten auf Englisch, `-screenshotTab`
    /// wählt den Tab. Normale Starts sind davon nicht betroffen.
    private func applyScreenshotArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-screenshotDemo") else { return }
        language = .en
        age = 17
        sex = .male
        startDemo()
        if let i = args.firstIndex(of: "-screenshotTab"), i + 1 < args.count,
           let tab = MainTab(rawValue: args[i + 1]) {
            selectedTab = tab
        }
        // Ein paar Beispiel-Einträge, damit das Journal nicht leer aussieht.
        let today = DayKey.today()
        seedDemoJournal(today: today)
        seedDemoStrength(today: today)
        let yesterday = DayKey.addDays(today, -1)
        if args.contains("-screenshotCalm"),
           let day = DayKey.date(from: yesterday),
           let start = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: day) {
            addActivity(type: "Stretching", start: start, end: start.addingTimeInterval(20 * 60))
            if let w = allWorkouts(for: yesterday).first(where: { $0.name == "Stretching" }) {
                screenshotActivity = ScreenshotActivity(id: w.id, dayKey: yesterday)
            }
        } else if args.contains("-screenshotActivity"),
                  let w = allWorkouts(for: yesterday).first(where: { !$0.id.hasPrefix("str-") }) ?? allWorkouts(for: DayKey.addDays(today, -2)).first {
            screenshotActivity = ScreenshotActivity(id: w.id, dayKey: DayKey.string(from: w.start))
        }
        if args.contains("-screenshotStrengthActive") {
            startStrength(template: strengthTemplates.first)
            seedActiveDemoSets()
        }
        if args.contains("-screenshotJournal") {
            journalPrompt = JournalPrompt(time: .morning, day: today)
        }
        updateDayLog(today) { log in
            log.waterGlasses = 3
            log.mood = .good
        }
        updateDayLog(DayKey.addDays(today, -2)) { $0.weightKg = 61.8 }
        updateDayLog(DayKey.addDays(today, -12)) { $0.weightKg = 62.4 }
        updateDayLog(DayKey.addDays(today, -20)) { $0.weightKg = 62.9 }
        recomputeJournalInsights()
        if args.contains("-screenshotYesterday") {
            selectedDayKey = DayKey.addDays(today, -1)
        }
    }

    // MARK: - Abgeleitete Konfiguration

    var oauthConfig: GoogleOAuthConfig {
        GoogleOAuthConfig(clientID: clientID)
    }

    var isConnected: Bool {
        auth.isConnected
    }

    var strainConfig: StrainConfig {
        StrainConfig(age: age, maxHROverride: maxHROverride > 0 ? maxHROverride : nil)
    }

    var sleepConfig: SleepEngineConfig {
        var config = SleepEngineConfig()
        config.baselineNeedMinutes = baseSleepNeedMinutes
        return config
    }

    var hasData: Bool {
        !store.days.isEmpty
    }

    var availableKeys: [String] {
        store.sortedKeys
    }

    // MARK: - Zugriff für Views

    func record(for key: String) -> DayRecord? {
        store.days[key]
    }

    func recovery(for key: String) -> RecoveryResult? {
        recoveryResults[key]
    }

    func sleep(for key: String) -> SleepAnalysis? {
        sleepAnalyses[key]
    }

    func strain(for key: String) -> StrainResult? {
        strainResults[key]
    }

    func ageResult(for key: String) -> AgeResult? {
        ageResults[key]
    }

    // MARK: - Journal

    func journalEntry(for key: String) -> JournalEntry {
        // Aus dem observablen Spiegel lesen, nicht aus dem Store — sonst
        // bemerkt SwiftUI die Änderung nach einem Toggle nicht.
        journalEntries[key] ?? JournalEntry(date: key)
    }

    func setJournalAnswer(_ id: String, _ value: Bool?, on key: String) {
        journal.setAnswer(id, value, on: key)
        journal.save()
        recomputeJournalInsights()
    }

    var trackedBehaviors: [JournalBehavior] {
        trackedBehaviorIDs.compactMap(JournalCatalog.behavior)
    }

    func isTracked(_ id: String) -> Bool {
        trackedBehaviorIDs.contains(id)
    }

    func toggleTracked(_ id: String) {
        if let i = trackedBehaviorIDs.firstIndex(of: id) {
            trackedBehaviorIDs.remove(at: i)
        } else {
            trackedBehaviorIDs.append(id)
        }
    }

    func trackedBehaviors(_ time: JournalTime) -> [JournalBehavior] {
        trackedBehaviors.filter { $0.time == time }
    }

    /// How many tracked questions of one journal are answered.
    func journalProgress(_ prompt: JournalPrompt) -> (answered: Int, total: Int) {
        let entry = journalEntry(for: prompt.key)
        let items = trackedBehaviors(prompt.time)
        return (items.filter { entry.answers[$0.id] != nil }.count, items.count)
    }

    /// Yes/no answers with next-day recovery in the last 90 days.
    func journalCounts(for id: String) -> (yes: Int, no: Int) {
        JournalEngine.counts(
            for: id,
            entries: journalEntries,
            recoveryByDay: recoveryResults.mapValues { $0.score },
            today: DayKey.today()
        )
    }

    /// Demo answers with a few clear patterns so Impacts has something to show.
    private func seedDemoJournal(today: String) {
        var generator = SeededGenerator(seed: 7)
        let effects: [String: Int] = ["alcohol": -14, "lateMeal": -6, "screenBeforeBed": -4, "stretching": 5, "hydrated": 7, "exercised": 2, "stress": -9, "lateCaffeine": -5, "noseStrips": 4, "retainers": 1, "woke": -8]
        for offset in 1...75 {
            let key = DayKey.addDays(today, -offset)
            guard journal.entry(for: key).isEmpty else { continue }
            let next = recoveryResults[DayKey.addDays(key, 1)].map { Double($0.score) } ?? 60
            let lowness = Stats.clamp((60 - next) / 30, -1, 1)
            for id in trackedBehaviorIDs {
                let effect = Double(effects[id] ?? 0)
                let base = id == "alcohol" ? 0.25 : 0.45
                let chance = Stats.clamp(base - lowness * effect / 25, 0.05, 0.95)
                journal.setAnswer(id, Double.random(in: 0..<1, using: &generator) < chance, on: key)
            }
        }
        journal.save()
        recomputeJournalInsights()
    }

    // MARK: - Tages-Log

    func dayLog(for key: String) -> DailyLog {
        dayLogs[key] ?? DailyLog(date: key)
    }

    func updateDayLog(_ key: String, _ change: (inout DailyLog) -> Void) {
        dailyLogs.update(key, change)
        dailyLogs.save()
        dayLogs = dailyLogs.logs
    }

    /// Hat der Nutzer für den Tag eingecheckt (Journal-Faktoren oder Log)?
    func isCheckedIn(_ key: String) -> Bool {
        !(journalEntries[key]?.isEmpty ?? true) || !(dayLogs[key]?.isEmpty ?? true)
    }

    /// Aufeinanderfolgende Tage mit Daten bis heute (Serie oben links).
    var streakDays: Int {
        var count = 0
        var key = DayKey.today()
        if store.days[key] == nil { key = DayKey.addDays(key, -1) }
        while let record = store.days[key],
              record.restingHR != nil || !record.sleepSessions.isEmpty || (record.steps ?? 0) > 0 {
            count += 1
            key = DayKey.addDays(key, -1)
        }
        return count
    }

    // MARK: - Selbst erfasste Aktivitäten

    func loggedActivities(for key: String) -> [LoggedActivity] {
        dayLog(for: key).activities ?? []
    }

    private func editActivities(_ key: String, _ change: (inout [LoggedActivity]) -> Void) {
        updateDayLog(key) { log in
            var list = log.activities ?? []
            change(&list)
            log.activities = list.isEmpty ? nil : list
        }
    }

    /// Bereits erledigte Aktivität nachtragen.
    func addActivity(type: String, start: Date, end: Date) {
        let key = DayKey.string(from: start)
        editActivities(key) { $0.append(LoggedActivity(type: type, start: start, end: max(end, start.addingTimeInterval(60)))) }
    }

    /// Aktivität für einen Tag einplanen ("Pending").
    func planActivity(type: String, on key: String) {
        editActivities(key) { $0.append(LoggedActivity(type: type)) }
    }

    /// Aktivität jetzt starten (läuft bis "Stop").
    func startActivity(type: String) {
        editActivities(DayKey.today()) { $0.append(LoggedActivity(type: type, start: Date())) }
    }

    /// Geplante Aktivität jetzt starten.
    func startPlanned(_ id: UUID, on key: String) {
        editActivities(key) { list in
            if let i = list.firstIndex(where: { $0.id == id }) { list[i].start = Date() }
        }
        if key != DayKey.today(), let activity = loggedActivities(for: key).first(where: { $0.id == id }) {
            // Auf heute verschieben, damit sie beim richtigen Tag landet.
            editActivities(key) { $0.removeAll { $0.id == id } }
            editActivities(DayKey.today()) { $0.append(activity) }
        }
    }

    func stopActivity(_ id: UUID, on key: String) {
        editActivities(key) { list in
            if let i = list.firstIndex(where: { $0.id == id }) { list[i].end = Date() }
        }
    }

    func deleteActivity(_ id: UUID, on key: String) {
        editActivities(key) { $0.removeAll { $0.id == id } }
    }

    /// Art einer Aktivität ändern (Google-Workout oder selbst erfasst).
    func changeWorkoutType(_ workoutID: String, to type: String, on key: String) {
        if let id = Self.loggedID(workoutID) {
            editActivities(key) { list in
                if let i = list.firstIndex(where: { $0.id == id }) { list[i].type = type }
            }
        } else {
            updateDayLog(key) { log in
                var map = log.workoutTypes ?? [:]
                map[workoutID] = type
                log.workoutTypes = map
            }
        }
    }

    /// Aktivität löschen. Google-Workouts werden ausgeblendet und bleiben es auch nach dem Sync.
    func deleteWorkout(_ workoutID: String, on key: String) {
        if let id = Self.loggedID(workoutID) {
            deleteActivity(id, on: key)
        } else {
            updateDayLog(key) { log in
                var hidden = log.hiddenWorkouts ?? []
                if !hidden.contains(workoutID) { hidden.append(workoutID) }
                log.hiddenWorkouts = hidden
            }
        }
    }

    /// Gelöschte Google-Workouts eines Tages wiederherstellen.
    func restoreHiddenWorkouts(on key: String) {
        updateDayLog(key) { $0.hiddenWorkouts = nil }
    }

    func hiddenWorkoutCount(on key: String) -> Int {
        dayLog(for: key).hiddenWorkouts?.count ?? 0
    }

    /// Zeiten einer selbst erfassten Aktivität ändern.
    func updateActivityTimes(_ workoutID: String, start: Date, end: Date, on key: String) {
        guard let id = Self.loggedID(workoutID) else { return }
        editActivities(key) { list in
            if let i = list.firstIndex(where: { $0.id == id }) {
                list[i].start = start
                list[i].end = max(end, start.addingTimeInterval(60))
            }
        }
    }

    static func loggedID(_ workoutID: String) -> UUID? {
        workoutID.hasPrefix("log-") ? UUID(uuidString: String(workoutID.dropFirst(4))) : nil
    }

    /// Workouts aus Google plus fertige, selbst erfasste Aktivitäten (mit Strain aus der HF).
    func allWorkouts(for key: String) -> [Workout] {
        let record = store.days[key]
        let log = dayLog(for: key)
        let hidden = Set(log.hiddenWorkouts ?? [])
        let renamed = log.workoutTypes ?? [:]
        var list = (record?.workouts ?? [])
            .filter { !hidden.contains($0.id) }
            .map { workout -> Workout in
                var w = workout
                if let name = renamed[w.id] { w.name = name }
                return w
            }
        let samples = (store.days[DayKey.addDays(key, -1)]?.hrSamples ?? []) + (record?.hrSamples ?? [])
        for activity in loggedActivities(for: key) where activity.isDone {
            guard let start = activity.start, let end = activity.end else { continue }
            let slice = samples.filter { $0.t >= start && $0.t <= end }
            var workout = Workout(
                id: "log-" + activity.id.uuidString,
                name: activity.type,
                start: start,
                end: end,
                averageHR: slice.isEmpty ? nil : slice.reduce(0) { $0 + $1.bpm } / Double(slice.count)
            )
            workout.strain = StrainEngine.workoutStrain(workout: workout, daySamples: samples, restingHR: record?.restingHR, config: strainConfig)
            list.append(workout)
        }
        addStrengthWorkouts(to: &list, on: key, samples: samples, restingHR: record?.restingHR)
        return list.sorted { $0.start < $1.start }
    }

    // MARK: - Stress

    /// Stress-Verlauf (0–3) für einen Tag aus der Intraday-HF.
    func stress(for key: String) -> StressResult? {
        guard let record = store.days[key] else { return nil }
        return StressEngine.compute(record: record, restingHR: record.restingHR, maxHR: strainConfig.maxHR)
    }

    private func recomputeJournalInsights() {
        journalEntries = journal.entries
        dayLogs = dailyLogs.logs
        let recoveryByDay = recoveryResults.mapValues { $0.score }
        journalInsights = JournalEngine.insights(entries: journal.entries, recoveryByDay: recoveryByDay, today: DayKey.today())
    }

    /// Anzahl Tage mit Recovery — Grundlage für die Monats-Auswertung (ab 28).
    var recoveryDayCount: Int {
        recoveryResults.count
    }

    /// Zeigt das Journal-Popup für gestern — höchstens 1× pro Tag, nur wenn
    /// gestern Daten hat und noch nichts eingetragen wurde.
    /// Opens the morning journal once per morning, and the evening journal
    /// once per evening after 7 PM, if they are not filled out yet.
    func maybeShowJournalPrompt() {
        guard hasData, journalPrompt == nil else { return }
        let today = DayKey.today()
        let morning = JournalPrompt(time: .morning, day: today)
        if Calendar.current.component(.hour, from: Date()) < 19 {
            guard journalProgress(morning).answered == 0, !trackedBehaviors(.morning).isEmpty else { return }
            let promptedKey = "journal.promptedMorning"
            guard defaults.string(forKey: promptedKey) != today else { return }
            defaults.set(today, forKey: promptedKey)
            journalPrompt = morning
        } else {
            let evening = JournalPrompt(time: .evening, day: today)
            guard journalProgress(evening).answered == 0, !trackedBehaviors(.evening).isEmpty else { return }
            let promptedKey = "journal.promptedEvening"
            guard defaults.string(forKey: promptedKey) != today else { return }
            defaults.set(today, forKey: promptedKey)
            journalPrompt = evening
        }
    }

    /// Plant die Routine-Benachrichtigungen neu (nach jedem Sync):
    /// Morgen-Wecker für morgen 7:30 (ersetzt den heutigen) und die
    /// Zubettgeh-Erinnerung für heute Abend.
    func rescheduleRoutineNotifications() {
        guard notificationsEnabled else { return }
        PulseNotifications.scheduleMorningReminder(language: language)
        if let bed = bedtimeTonight?.recommendedBedtimeMinutes {
            PulseNotifications.scheduleBedtimeReminder(bedtimeMinutes: bed, language: language)
        } else {
            PulseNotifications.cancelBedtimeReminder()
        }
    }

    // MARK: - Health-Warnung & Zubettgeh-Empfehlung

    /// Proaktive Gesundheitswarnung für den ausgewählten Tag (nil = alles im Rahmen).
    var healthAlert: HealthAlert? {
        let records = store.chronological(upTo: selectedDayKey, count: 10)
        return HealthMonitor.alert(records: records, language: language)
    }

    /// Empfehlung für die kommende Nacht (aus Schlafschuld, heutigem Strain,
    /// gewohnter Aufwachzeit). nil ohne genug Historie.
    var bedtimeTonight: BedtimeRecommendation? {
        guard hasData else { return nil }
        let today = DayKey.today()
        let debt = sleepAnalyses[today]?.debtAfterMinutes
            ?? store.sortedKeys.last.flatMap { sleepAnalyses[$0]?.debtAfterMinutes }
            ?? 0
        let strainToday = strainResults[today]?.strain ?? 0
        let recentWakes = store.chronological(upTo: today, count: 7)
            .compactMap { sleepAnalyses[$0.date]?.wakeTime }
        guard !recentWakes.isEmpty else { return nil }
        return SleepEngine.bedtimeRecommendation(
            currentDebtMinutes: debt,
            strainToday: strainToday,
            recentWakeTimes: recentWakes,
            config: sleepConfig
        )
    }

    var selectedRecord: DayRecord? {
        record(for: selectedDayKey)
    }

    /// Health-Monitor-Status für den ausgewählten Tag.
    var healthStatuses: [HealthMetricStatus] {
        guard let record = selectedRecord else { return [] }
        let history = store.history(before: selectedDayKey, days: 45)
        return HealthMonitor.evaluate(today: record, history: history)
    }

    /// Werte einer Metrik der letzten `count` Tage bis zum ausgewählten Tag.
    func trend(_ count: Int, endingAt key: String? = nil, _ value: (DayRecord) -> Double?) -> [(key: String, value: Double)] {
        let end = key ?? selectedDayKey
        let start = DayKey.addDays(end, -(count - 1))
        return DayKey.keys(from: start, to: end).compactMap { dayKey in
            guard let record = store.days[dayKey], let v = value(record) else { return nil }
            return (dayKey, v)
        }
    }

    // MARK: - Neuberechnung

    func recomputeAll() {
        var strains: [String: StrainResult] = [:]
        var strainScalar: [String: Double] = [:]
        let muscular = muscularRawByDay()
        for (key, record) in store.days {
            var result = StrainEngine.dayStrain(record: record, restingHR: record.restingHR, config: strainConfig)
            if let extra = muscular[key], extra > 0 {
                let raw = result.rawLoad + extra
                result = StrainResult(
                    strain: StrainEngine.strain(fromRaw: raw, tau: strainConfig.tau),
                    rawLoad: raw,
                    zoneMinutes: result.zoneMinutes,
                    restMinutes: result.restMinutes,
                    avgHR: result.avgHR,
                    peakHR: result.peakHR
                )
            }
            strains[key] = result
            strainScalar[key] = result.strain
        }
        strainResults = strains

        sleepAnalyses = SleepEngine.analyze(days: store.days, config: sleepConfig, strainByDay: strainScalar)

        // Workout-Strains in die Records schreiben
        for (_, record) in store.days where !record.workouts.isEmpty {
            var updated = record
            for index in updated.workouts.indices {
                updated.workouts[index].strain = StrainEngine.workoutStrain(
                    workout: updated.workouts[index],
                    daySamples: record.hrSamples,
                    restingHR: record.restingHR,
                    config: strainConfig
                )
            }
            store.upsert(updated)
        }

        // Recovery chronologisch mit wachsender Historie
        var recoveries: [String: RecoveryResult] = [:]
        var history: [DayRecord] = []
        let keys = store.sortedKeys
        history.reserveCapacity(keys.count)
        for key in keys {
            guard let record = store.days[key] else { continue }
            recoveries[key] = RecoveryEngine.compute(
                dateKey: key,
                today: record,
                history: history,
                sleepPerformance: sleepAnalyses[key]?.performance
            )
            history.append(record)
        }
        recoveryResults = recoveries
        recomputeJournalInsights()

        // Biologisches „Pulse Alter" je Tag aus dem 30-Tage-Fenster.
        var ages: [String: AgeResult] = [:]
        for key in keys {
            let window = store.chronological(upTo: key, count: AgeEngine.calibrationNeed)
            guard !window.isEmpty else { continue }
            let sleepPerf = window.compactMap { record -> Double? in
                guard let analysis = sleepAnalyses[record.date], analysis.hasData else { return nil }
                return analysis.performance
            }
            let inputs = AgeInputs(
                chronoAge: age,
                sex: sex,
                vo2maxValues: window.compactMap { $0.vo2max },
                rmssdValues: window.compactMap { $0.hrvRmssd },
                restingHRValues: window.compactMap { $0.restingHR },
                observedMaxHR: Self.robustMaxHR(window),
                maxHROverride: maxHROverride > 0 ? maxHROverride : nil,
                sleepPerformances: sleepPerf,
                stepsValues: window.compactMap { $0.steps.map(Double.init) },
                validDayCount: window.filter { $0.hrvRmssd != nil || $0.restingHR != nil }.count
            )
            ages[key] = AgeEngine.compute(dateKey: key, inputs: inputs, language: language)
        }
        ageResults = ages

        if store.days[selectedDayKey] == nil, let last = keys.last {
            selectedDayKey = last
        }

        // Tages-Snapshot für die Widgets aktualisieren.
        let today = DayKey.today()
        let todayRecovery = recoveryResults[today]
        let todaySleep = sleepAnalyses[today]
        WidgetBridge.publish(
            recovery: todayRecovery,
            sleepPerformance: (todaySleep?.hasData == true) ? todaySleep?.performance : nil,
            strain: strainResults[today]?.strain,
            strainTarget: todayRecovery.map { StrainEngine.targetStrain(forRecovery: $0.score) },
            language: language
        )
    }

    /// Robuster beobachteter Maxpuls (97,5. Perzentil) über die Intraday-HF des
    /// Fensters; nil bei zu wenig Samples (verhindert Artefakt-Ausreißer).
    private static func robustMaxHR(_ window: [DayRecord]) -> Double? {
        let bpms = window.flatMap { $0.hrSamples.map(\.bpm) }
        guard bpms.count >= 300 else { return nil }
        return Stats.percentile(bpms, 0.975)
    }

    // MARK: - Aktionen

    func startDemo() {
        store.replaceAll(DemoData.generate(daysBack: 120, seed: 42))
        store.save()
        demoMode = true
        onboarded = true
        selectedDayKey = DayKey.today()
        lastError = nil
        recomputeAll()
    }

    func connect() async {
        lastError = nil
        let config = oauthConfig
        guard config.isValid, let scheme = config.reversedClientScheme else {
            lastError = AuthError.invalidClientID.errorDescription
            return
        }
        let pkce = PKCE()
        let state = UUID().uuidString
        guard let url = auth.authorizationURL(config: config, pkce: pkce, state: state) else {
            lastError = "Could not create the sign-in URL."
            return
        }
        do {
            let callback = try await WebAuthenticator.shared.authenticate(url: url, callbackScheme: scheme)
            guard let code = GoogleAuth.extractCode(from: callback, expectedState: state) else {
                lastError = "No valid sign-in code received."
                return
            }
            _ = try await auth.exchange(code: code, pkce: pkce, config: config)
            connectedAt = Date()
            if notificationsEnabled, let connectedAt {
                PulseNotifications.scheduleTokenExpiry(connectedAt: connectedAt, language: language)
                scheduleBackgroundRefresh()
            }
            if demoMode {
                store.wipe()
                demoMode = false
            }
            onboarded = true
            recomputeAll()
            await syncNow()
        } catch let error as AuthError {
            lastError = error.errorDescription
        } catch {
            let nsError = error as NSError
            let cancelled = nsError.domain == ASWebAuthenticationSessionError.errorDomain
                && nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
            if !cancelled {
                lastError = error.localizedDescription
            }
        }
    }

    /// Days to fetch on a normal sync: the full range once, then only the
    /// days since the last sync.
    private func incrementalDaysBack() -> Int {
        let backfilled = defaults.integer(forKey: Keys.backfilledDays)
        guard let lastSyncAt, !store.days.isEmpty, backfilled >= daysBack else { return daysBack }
        let since = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: lastSyncAt), to: Date()).day ?? daysBack
        // Only the days since the last sync (today counts as one).
        return min(daysBack, max(1, since + 1))
    }

    /// Fetches the whole backfill range again.
    func fullResync() async {
        defaults.removeObject(forKey: Keys.backfilledDays)
        await syncNow()
    }

    func syncNow(daysBackOverride: Int? = nil, hrDaysBackOverride: Int? = nil) async {
        guard !syncing else { return }
        guard isConnected else {
            lastError = AuthError.notConnected.errorDescription
            return
        }
        syncing = true
        syncMessage = "Starte…"
        syncFraction = 0

        // Sync gegen Display-Sperre absichern und beim App-Wechsel noch
        // ~30 s im Hintergrund weiterlaufen lassen (Teilergebnisse werden
        // ohnehin nach jeder Phase gespeichert).
        UIApplication.shared.isIdleTimerDisabled = true
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "pulse.sync") {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        defer {
            syncing = false
            UIApplication.shared.isIdleTimerDisabled = false
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }

        let client = HealthAPIClient(auth: auth, config: oauthConfig)
        let engine = SyncEngine(client: client)

        let windowDays = daysBackOverride ?? incrementalDaysBack()
        let isFullBackfill = windowDays >= daysBack

        // Phase 1: alle Tagesmetriken — danach sofort speichern und anzeigen.
        let daily = await engine.syncDailyMetrics(
            existingDays: store.days,
            daysBack: windowDays
        ) { [weak self] progress in
            Task { @MainActor in
                self?.syncMessage = progress.message
                self?.syncFraction = progress.fraction * 0.55
            }
        }
        store.replaceAll(daily.updatedDays)
        store.save()
        syncLog = daily.log
        profileName = daily.profile?.displayName ?? profileName
        if sex == .unspecified, let profileSex = daily.profile?.sex, profileSex != .unspecified {
            sex = profileSex // löst recomputeAll() aus
        } else {
            recomputeAll()
        }

        // Phase 2: Intraday-Herzfrequenz — nur fehlende Tage, parallel.
        let hr = await engine.syncIntradayHeartRate(
            existingDays: store.days,
            hrDaysBack: hrDaysBackOverride ?? hrDaysBack
        ) { [weak self] progress in
            Task { @MainActor in
                self?.syncMessage = progress.message
                self?.syncFraction = 0.55 + progress.fraction * 0.45
            }
        }
        store.replaceAll(hr.updatedDays)
        store.save()
        syncLog = daily.log + hr.log
        lastSyncAt = Date()
        if isFullBackfill, !daily.hadErrors {
            defaults.set(daysBack, forKey: Keys.backfilledDays)
        }
        recomputeAll()

        if daily.hadErrors || hr.hadErrors {
            lastError = "Sync finished with warnings – see the sync log for details."
        }

        rescheduleRoutineNotifications()
        maybeShowJournalPrompt()
    }

    func disconnect() {
        auth.disconnect()
        connectedAt = nil
        PulseNotifications.cancelTokenExpiry()
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskID)
    }

    func resetAll() {
        store.wipe()
        journal.wipe()
        dailyLogs.wipe()
        strength.wipe()
        refreshStrength()
        syncLog = []
        lastSyncAt = nil
        defaults.removeObject(forKey: Keys.backfilledDays)
        connectedAt = nil
        demoMode = false
        onboarded = false
        profileName = nil
        lastError = nil
        PulseNotifications.cancelAll()
        recomputeAll()
    }

    // MARK: - Benachrichtigungen & Hintergrund-Sync

    func setNotifications(enabled: Bool) async {
        if enabled {
            let granted = await PulseNotifications.requestAuthorization()
            notificationsEnabled = granted
            if granted {
                if let connectedAt { PulseNotifications.scheduleTokenExpiry(connectedAt: connectedAt, language: language) }
                scheduleBackgroundRefresh()
            }
        } else {
            notificationsEnabled = false
            PulseNotifications.cancelAll()
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskID)
        }
    }

    /// Plant den nächsten Hintergrund-Sync. iOS entscheidet über den realen
    /// Zeitpunkt – „ab früh morgens" ist nur ein Wunsch, keine Garantie.
    func scheduleBackgroundRefresh() {
        guard notificationsEnabled, isConnected else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = Self.nextEarlyMorning()
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Aufgerufen vom `.backgroundTask`-Handler: leichter Sync + Morgen-Notification.
    func performBackgroundRefresh() async {
        scheduleBackgroundRefresh() // sofort den nächsten Lauf einplanen
        guard isConnected else { return }
        await syncNow(hrDaysBackOverride: 1)
        guard notificationsEnabled, await PulseNotifications.isAuthorized() else { return }
        let today = DayKey.today()
        if let rec = recovery(for: today) {
            let sleepText = sleep(for: today).flatMap { $0.hasData ? "\(Fmt.hm($0.sleptMinutes)) h" : nil }
            let yesterday = DayKey.addDays(today, -1)
            let journalPending = journal.entry(for: yesterday).isEmpty && store.days[yesterday] != nil
            let alertMessage = HealthMonitor.alert(records: store.chronological(upTo: today, count: 10), language: language)?.message
            PulseNotifications.postRecoverySummary(
                recovery: rec.score,
                sleep: sleepText,
                journalPending: journalPending,
                alertMessage: alertMessage,
                language: language
            )
        }
    }

    private static func nextEarlyMorning(hour: Int = 6, minute: Int = 30) -> Date {
        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        let target = cal.date(from: comps) ?? now.addingTimeInterval(6 * 3600)
        return target > now ? target : (cal.date(byAdding: .day, value: 1, to: target) ?? now.addingTimeInterval(6 * 3600))
    }
}

/// One journal to fill out: the morning journal on `day` (about the night
/// before) or the evening journal on `day` (about that day).
struct JournalPrompt: Identifiable, Equatable {
    let time: JournalTime
    let day: String

    var id: String { "\(time.rawValue)-\(day)" }
    /// Where the answers are stored.
    var key: String { time.storageKey(forDay: day) }
}

struct ScreenshotActivity: Identifiable, Equatable {
    let id: String
    let dayKey: String
}
