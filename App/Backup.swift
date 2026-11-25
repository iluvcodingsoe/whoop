import SwiftUI
import UniformTypeIdentifiers

/// Everything that only exists on this phone: journal, logged activities and
/// edits, strength workouts and templates, plus settings. Google data is not
/// included because a sync brings it back.
struct PulseBackup: Codable {
    var version = 1
    var createdAt: Date
    var files: [String: Data]
    var settings: [String: BackupValue]
}

enum BackupValue: Codable {
    case int(Int), double(Double), bool(Bool), string(String), strings([String])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else { self = .strings(try c.decode([String].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .strings(let v): try c.encode(v)
        }
    }

    var object: Any {
        switch self {
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .string(let v): return v
        case .strings(let v): return v
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum BackupError: LocalizedError {
    case unreadable
    var errorDescription: String? { "This file is not a Pulse backup." }
}

extension AppModel {
    private static let backupSettingKeys = [
        "google.clientID", "sync.daysBack", "sync.hrDaysBack", "journal.behaviors", "journal.addedSleepGear",
        "units.pounds", "calc.sleepNeedMinutes", "calc.age", "calc.sex", "profile.heightCm", "goal.steps",
        "plan.bedtimeMinutes", "profile.weightKg", "calc.maxHROverride", "notify.enabled",
        "dashboard.moduleOrder", "dashboard.hiddenModules",
    ]
    private static let folderBookmarkKey = "backup.folderBookmark"
    private static let lastAutoBackupKey = "backup.lastAuto"
    static let autoBackupFileName = "Pulse Backup.json"

    var backupFileName: String {
        "Pulse Backup \(DayKey.today()).json"
    }

    // MARK: - Erstellen

    func makeBackup() -> Data {
        let defaults = UserDefaults.standard
        var settings: [String: BackupValue] = [:]
        for key in Self.backupSettingKeys {
            guard let object = defaults.object(forKey: key) else { continue }
            if let number = object as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    settings[key] = .bool(number.boolValue)
                } else if CFNumberIsFloatType(number) {
                    settings[key] = .double(number.doubleValue)
                } else {
                    settings[key] = .int(number.intValue)
                }
            } else if let v = object as? String {
                settings[key] = .string(v)
            } else if let v = object as? [String] {
                settings[key] = .strings(v)
            }
        }
        journal.save()
        dailyLogs.save()
        strength.save()
        var files: [String: Data] = [:]
        for url in [journal.fileURL, dailyLogs.fileURL, strength.fileURL] {
            if let data = try? Data(contentsOf: url) { files[url.lastPathComponent] = data }
        }
        let backup = PulseBackup(createdAt: Date(), files: files, settings: settings)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(backup)) ?? Data()
    }

    // MARK: - Wiederherstellen

    /// Replaces local data with the backup. Returns a short summary.
    @discardableResult
    func restoreBackup(_ data: Data) throws -> String {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(PulseBackup.self, from: data), !backup.files.isEmpty || !backup.settings.isEmpty else {
            throw BackupError.unreadable
        }
        for (name, contents) in backup.files {
            let target: URL?
            switch name {
            case journal.fileURL.lastPathComponent: target = journal.fileURL
            case dailyLogs.fileURL.lastPathComponent: target = dailyLogs.fileURL
            case strength.fileURL.lastPathComponent: target = strength.fileURL
            default: target = nil
            }
            if let target { try contents.write(to: target, options: .atomic) }
        }
        let defaults = UserDefaults.standard
        for (key, value) in backup.settings where Self.backupSettingKeys.contains(key) {
            defaults.set(value.object, forKey: key)
        }
        journal.load()
        dailyLogs.load()
        strength.load()
        reloadSettingsFromDefaults()
        refreshStrength()
        recomputeJournalInsights()

        let workouts = strength.workouts.count
        let activities = dailyLogs.logs.values.reduce(0) { $0 + ($1.activities?.count ?? 0) }
        let journalDays = journal.entries.count
        return "Restored \(journalDays) journal days, \(activities) logged activities and \(workouts) strength workouts from \(backup.createdAt.formatted(date: .abbreviated, time: .shortened))."
    }

    private func reloadSettingsFromDefaults() {
        let d = UserDefaults.standard
        if let v = d.string(forKey: "google.clientID"), !v.isEmpty { clientID = v }
        if let v = d.object(forKey: "sync.daysBack") as? Int { daysBack = v }
        if let v = d.object(forKey: "sync.hrDaysBack") as? Int { hrDaysBack = v }
        if let v = d.stringArray(forKey: "journal.behaviors") { trackedBehaviorIDs = v.filter { JournalCatalog.behavior($0) != nil } }
        if let v = d.object(forKey: "units.pounds") as? Bool { usePounds = v }
        if let v = d.object(forKey: "calc.sleepNeedMinutes") as? Double { baseSleepNeedMinutes = v }
        if let v = d.object(forKey: "calc.age") as? Int { age = v }
        if let v = d.string(forKey: "calc.sex").flatMap(BiologicalSex.init(rawValue:)) { sex = v }
        if let v = d.object(forKey: "profile.heightCm") as? Double { heightCm = v }
        if let v = d.object(forKey: "goal.steps") as? Int { stepGoal = v }
        if let v = d.object(forKey: "plan.bedtimeMinutes") as? Int { plannedBedtimeMinutes = v }
        if let v = d.object(forKey: "profile.weightKg") as? Double { weightKg = v }
        if let v = d.object(forKey: "calc.maxHROverride") as? Double { maxHROverride = v }
        recomputeAll()
    }

    // MARK: - Automatisch in einen Ordner

    var autoBackupFolderName: String? {
        guard let url = resolveBackupFolder() else { return nil }
        return url.lastPathComponent
    }

    var lastAutoBackup: Date? {
        UserDefaults.standard.object(forKey: Self.lastAutoBackupKey) as? Date
    }

    /// Remembers a folder (iCloud Drive or On My iPhone) and backs up into it.
    func setAutoBackupFolder(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: Self.folderBookmarkKey)
        autoBackup(force: true)
    }

    func stopAutoBackup() {
        UserDefaults.standard.removeObject(forKey: Self.folderBookmarkKey)
        UserDefaults.standard.removeObject(forKey: Self.lastAutoBackupKey)
    }

    private func resolveBackupFolder() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.folderBookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: Self.folderBookmarkKey)
        }
        return url
    }

    /// Writes the backup into the chosen folder. Runs when the app goes to the
    /// background and after a workout is saved.
    func autoBackup(force: Bool = false) {
        guard !demoMode, let folder = resolveBackupFolder() else { return }
        if !force, let last = lastAutoBackup, Date().timeIntervalSince(last) < 60 { return }
        let data = makeBackup()
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        let target = folder.appendingPathComponent(Self.autoBackupFileName)
        var coordinatorError: NSError?
        var written = false
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordinatorError) { url in
            written = (try? data.write(to: url, options: .atomic)) != nil
        }
        if written { UserDefaults.standard.set(Date(), forKey: Self.lastAutoBackupKey) }
    }
}

// MARK: - Oberfläche

/// Settings section: save, restore and automatic backups.
struct BackupSection: View {
    @Environment(AppModel.self) private var model
    @State private var exporting = false
    @State private var document = BackupDocument(data: Data())
    @State private var importMode: ImportMode?
    @State private var pendingRestore: Data?
    @State private var message: String?
    @State private var refresh = 0

    enum ImportMode { case restore, folder }

    var body: some View {
        Section {
            Button {
                document = BackupDocument(data: model.makeBackup())
                exporting = true
            } label: {
                Label("Save Backup to Files", systemImage: "square.and.arrow.down")
            }

            Button {
                importMode = .restore
            } label: {
                Label("Restore from Backup", systemImage: "arrow.counterclockwise")
            }

            if let folder = model.autoBackupFolderName {
                LabeledContent("Auto-backup folder", value: folder)
                if let last = model.lastAutoBackup {
                    LabeledContent("Last auto-backup", value: last.formatted(date: .abbreviated, time: .shortened))
                }
                Button("Back Up Now") {
                    model.autoBackup(force: true)
                    refresh += 1
                    message = model.lastAutoBackup.map { "Saved to \(folder) at \($0.formatted(date: .omitted, time: .shortened))." } ?? "Could not write to \(folder). Pick the folder again."
                }
                Button("Change Folder") { importMode = .folder }
                Button("Turn Off Auto-Backup", role: .destructive) {
                    model.stopAutoBackup()
                    refresh += 1
                }
            } else {
                Button {
                    importMode = .folder
                } label: {
                    Label("Turn On Auto-Backup", systemImage: "icloud.and.arrow.up")
                }
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("Backs up your journal, logged activities, edits, strength workouts, templates and settings. Google Health data is not included because syncing brings it back. Auto-backup saves \u{201C}\(AppModel.autoBackupFileName)\u{201D} to the folder you pick, for example in iCloud Drive, every time you leave the app.")
        }
        .id(refresh)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: model.backupFileName) { result in
            if case .success = result { message = "Backup saved." }
        }
        .fileImporter(
            isPresented: Binding(get: { importMode != nil }, set: { if !$0 { importMode = nil } }),
            allowedContentTypes: importMode == .folder ? [.folder] : [.json]
        ) { result in
            let mode = importMode
            importMode = nil
            guard case .success(let url) = result else { return }
            switch mode {
            case .folder:
                do {
                    try model.setAutoBackupFolder(url)
                    refresh += 1
                    message = "Auto-backup is on. Pulse saves to \(url.lastPathComponent) each time you leave the app."
                } catch {
                    message = "Could not use that folder: \(error.localizedDescription)"
                }
            case .restore:
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                pendingRestore = try? Data(contentsOf: url)
                if pendingRestore == nil { message = "Could not read that file." }
            case nil:
                break
            }
        }
        .confirmationDialog(
            "Replace your journal, activities and workouts with this backup?",
            isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
            titleVisibility: .visible
        ) {
            Button("Restore", role: .destructive) {
                guard let data = pendingRestore else { return }
                pendingRestore = nil
                do {
                    message = try model.restoreBackup(data)
                } catch {
                    message = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        }
        .alert("Backup", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

/// Restore button for the first screen after a fresh install.
struct RestoreBackupButton: View {
    @Environment(AppModel.self) private var model
    @State private var importing = false
    @State private var pending: Data?
    @State private var message: String?

    var body: some View {
        Button {
            importing = true
        } label: {
            Label("Restore from Backup", systemImage: "arrow.counterclockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                message = "Could not read that file."
                return
            }
            do {
                message = try model.restoreBackup(data) + " Connect Google Health to load your Fitbit data again."
            } catch {
                message = error.localizedDescription
            }
        }
        .alert("Backup", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}
