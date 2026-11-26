import SwiftUI
import Foundation

/// Cloud backup through Firebase (free Spark plan), with no Firebase SDK:
/// Firebase Authentication signs in with the Google account Pulse already
/// uses, and Firestore stores one compressed backup document per user at
/// users/{uid}/pulse/backup.
struct FirebaseConfig: Codable, Equatable {
    var apiKey: String
    var projectID: String

    var isComplete: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty && !projectID.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

struct FirebaseSession: Codable {
    var idToken: String
    var refreshToken: String
    var expiry: Date
    var uid: String
    var email: String?
}

struct CloudBackupInfo {
    var updatedAt: Date
    var device: String?
    var data: Data
}

enum CloudError: LocalizedError {
    case notConfigured
    case needsReconnect
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Add your Firebase API key and project ID first."
        case .needsReconnect: return "Disconnect and reconnect Google in Settings once, so Pulse can use your Google account for the cloud."
        case .server(let message): return message
        }
    }
}

final class FirebaseCloud {
    static let keychainService = "net.dehlwes.pulse.firebase"
    private let session = URLSession.shared

    var config: FirebaseConfig? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "cloud.config") else { return nil }
            return try? JSONDecoder().decode(FirebaseConfig.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "cloud.config")
            } else {
                UserDefaults.standard.removeObject(forKey: "cloud.config")
            }
        }
    }

    private(set) var current: FirebaseSession? = {
        guard let data = Keychain.load(service: FirebaseCloud.keychainService, account: "session") else { return nil }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try? d.decode(FirebaseSession.self, from: data)
    }()

    private func store(_ value: FirebaseSession?) {
        current = value
        if let value {
            let e = JSONEncoder()
            e.dateEncodingStrategy = .iso8601
            if let data = try? e.encode(value) {
                _ = Keychain.save(data, service: Self.keychainService, account: "session")
            }
        } else {
            Keychain.delete(service: Self.keychainService, account: "session")
        }
    }

    func signOut() { store(nil) }

    // MARK: Auth

    private func post(_ url: String, json: [String: Any]? = nil, form: String? = nil) async throws -> [String: Any] {
        guard let target = URL(string: url) else { throw CloudError.server("Bad URL") }
        var request = URLRequest(url: target)
        request.httpMethod = "POST"
        if let bundle = Bundle.main.bundleIdentifier {
            request.setValue(bundle, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        } else if let form {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = form.data(using: .utf8)
        }
        let (data, response) = try await session.data(for: request)
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = ((object["error"] as? [String: Any])?["message"] as? String) ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CloudError.server(Self.friendly(message))
        }
        return object
    }

    static func friendly(_ message: String) -> String {
        if message.contains("OPERATION_NOT_ALLOWED") { return "Turn on Google as a sign-in method in Firebase Authentication." }
        if message.contains("API key not valid") || message.contains("API_KEY_INVALID") { return "The Firebase API key is not valid. Copy the Web API Key from Firebase project settings." }
        if message.contains("INVALID_IDP_RESPONSE") || message.contains("audience") {
            return "Firebase rejected your Google sign-in. Make sure Firebase is added to the same Google Cloud project as your Pulse client ID."
        }
        if message.contains("PERMISSION_DENIED") || message.contains("Missing or insufficient permissions") {
            return "Firestore blocked the request. Check that you pasted the security rules from the setup steps."
        }
        if message.contains("NOT_FOUND") && message.contains("database") { return "Create a Firestore database in your Firebase project first." }
        return message
    }

    /// Signs in to Firebase with the Google ID token from Pulse's Google connection.
    func signIn(googleIDToken: String, config: FirebaseConfig) async throws -> FirebaseSession {
        let key = config.apiKey.trimmingCharacters(in: .whitespaces)
        let result = try await post(
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=\(key)",
            json: [
                "postBody": "id_token=\(googleIDToken)&providerId=google.com",
                "requestUri": "http://localhost",
                "returnIdpCredential": true,
                "returnSecureToken": true,
            ]
        )
        guard let idToken = result["idToken"] as? String,
              let refresh = result["refreshToken"] as? String,
              let uid = result["localId"] as? String else {
            throw CloudError.server("Firebase sign-in returned no session.")
        }
        let expires = Double(result["expiresIn"] as? String ?? "3600") ?? 3600
        let value = FirebaseSession(idToken: idToken, refreshToken: refresh, expiry: Date().addingTimeInterval(expires), uid: uid, email: result["email"] as? String)
        store(value)
        return value
    }

    private func validSession(config: FirebaseConfig) async throws -> FirebaseSession {
        guard var value = current else { throw CloudError.needsReconnect }
        if value.expiry.timeIntervalSinceNow < 300 {
            let key = config.apiKey.trimmingCharacters(in: .whitespaces)
            let result = try await post(
                "https://securetoken.googleapis.com/v1/token?key=\(key)",
                form: "grant_type=refresh_token&refresh_token=\(value.refreshToken)"
            )
            guard let idToken = result["id_token"] as? String else { throw CloudError.server("Could not refresh the cloud session.") }
            value.idToken = idToken
            value.refreshToken = (result["refresh_token"] as? String) ?? value.refreshToken
            value.expiry = Date().addingTimeInterval(Double(result["expires_in"] as? String ?? "3600") ?? 3600)
            store(value)
        }
        return value
    }

    // MARK: Firestore

    private func documentURL(_ config: FirebaseConfig, uid: String) -> URL? {
        let project = config.projectID.trimmingCharacters(in: .whitespaces)
        return URL(string: "https://firestore.googleapis.com/v1/projects/\(project)/databases/(default)/documents/users/\(uid)/pulse/backup")
    }

    func upload(_ backup: Data, config: FirebaseConfig) async throws -> Date {
        let value = try await validSession(config: config)
        guard let url = documentURL(config, uid: value.uid) else { throw CloudError.notConfigured }
        let packed = (try? (backup as NSData).compressed(using: .zlib) as Data) ?? backup
        let now = Date()
        let iso = ISO8601DateFormatter().string(from: now)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(value.idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "fields": [
                "data": ["bytesValue": packed.base64EncodedString()],
                "compressed": ["booleanValue": true],
                "updatedAt": ["timestampValue": iso],
                "device": ["stringValue": UIDevice.current.name],
                "version": ["integerValue": "1"],
            ],
        ])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = ((object?["error"] as? [String: Any])?["message"] as? String) ?? "Upload failed."
            throw CloudError.server(Self.friendly(message))
        }
        return now
    }

    /// The cloud backup, or nil if none exists yet.
    func download(config: FirebaseConfig) async throws -> CloudBackupInfo? {
        let value = try await validSession(config: config)
        guard let url = documentURL(config, uid: value.uid) else { throw CloudError.notConfigured }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(value.idToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudError.server("No response.") }
        if http.statusCode == 404 { return nil }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(http.statusCode) else {
            let message = ((object["error"] as? [String: Any])?["message"] as? String) ?? "Download failed."
            throw CloudError.server(Self.friendly(message))
        }
        let fields = object["fields"] as? [String: Any] ?? [:]
        guard let b64 = (fields["data"] as? [String: Any])?["bytesValue"] as? String,
              let raw = Data(base64Encoded: b64) else { return nil }
        let compressed = ((fields["compressed"] as? [String: Any])?["booleanValue"] as? Bool) ?? false
        let payload = compressed ? ((try? (raw as NSData).decompressed(using: .zlib) as Data) ?? raw) : raw
        let stamp = ((fields["updatedAt"] as? [String: Any])?["timestampValue"] as? String)
        let date = stamp.flatMap { Self.parseDate($0) } ?? Date.distantPast
        return CloudBackupInfo(updatedAt: date, device: (fields["device"] as? [String: Any])?["stringValue"] as? String, data: payload)
    }

    static func parseDate(_ text: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: text) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: text)
    }
}

// MARK: - Model

extension AppModel {
    var cloudConfig: FirebaseConfig? {
        get { cloud.config }
        set { cloud.config = newValue }
    }

    var cloudSignedInEmail: String? { cloud.current?.email }
    var cloudIsOn: Bool { cloud.current != nil && (cloud.config?.isComplete ?? false) }

    var lastCloudUpload: Date? {
        UserDefaults.standard.object(forKey: "cloud.lastUpload") as? Date
    }

    /// Signs in to Firebase with the connected Google account.
    func connectCloud() async throws {
        guard let config = cloud.config, config.isComplete else { throw CloudError.notConfigured }
        guard isConnected, let idToken = try await auth.freshIDToken(config: oauthConfig) else { throw CloudError.needsReconnect }
        _ = try await cloud.signIn(googleIDToken: idToken, config: config)
    }

    func disconnectCloud() {
        cloud.signOut()
        UserDefaults.standard.removeObject(forKey: "cloud.lastUpload")
    }

    /// Uploads the current backup. Throttled to once a minute unless forced.
    @discardableResult
    func cloudUpload(force: Bool = false) async throws -> Date? {
        guard !demoMode, let config = cloud.config, config.isComplete, cloud.current != nil else { return nil }
        if !force, let last = lastCloudUpload, Date().timeIntervalSince(last) < 60 { return nil }
        let date = try await cloud.upload(makeBackup(), config: config)
        UserDefaults.standard.set(date, forKey: "cloud.lastUpload")
        return date
    }

    /// Fire-and-forget upload for app hooks (leaving the app, finishing a workout).
    func cloudAutoUpload() {
        guard cloudIsOn else { return }
        Task { _ = try? await cloudUpload() }
    }

    func cloudDownload() async throws -> CloudBackupInfo? {
        guard let config = cloud.config, config.isComplete else { throw CloudError.notConfigured }
        if cloud.current == nil { try await connectCloud() }
        return try await cloud.download(config: config)
    }

    /// True when this phone has no journal, activities or workouts yet.
    var hasLocalUserData: Bool {
        !journal.entries.isEmpty || !strength.workouts.isEmpty || dailyLogs.logs.values.contains { !($0.activities ?? []).isEmpty }
    }
}

// MARK: - Settings section

struct CloudSection: View {
    @Environment(AppModel.self) private var model
    @State private var apiKey = ""
    @State private var projectID = ""
    @State private var busy = false
    @State private var message: String?
    @State private var pending: CloudBackupInfo?
    @State private var refresh = 0
    @State private var showSetup = false

    var body: some View {
        Section {
            if model.cloudIsOn {
                LabeledContent("Account", value: model.cloudSignedInEmail ?? "Signed in")
                LabeledContent("Last upload", value: model.lastCloudUpload.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Not yet")
                Button {
                    run { if let date = try await model.cloudUpload(force: true) { message = "Uploaded at \(date.formatted(date: .omitted, time: .shortened))." } }
                } label: {
                    Label("Back Up Now", systemImage: "icloud.and.arrow.up")
                }
                Button {
                    run {
                        if let info = try await model.cloudDownload() { pending = info } else { message = "No cloud backup yet." }
                    }
                } label: {
                    Label("Restore from Cloud", systemImage: "icloud.and.arrow.down")
                }
                Button("Turn Off Cloud Sync", role: .destructive) {
                    model.disconnectCloud()
                    refresh += 1
                }
            } else {
                TextField("Firebase Web API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Firebase Project ID", text: $projectID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    model.cloudConfig = FirebaseConfig(apiKey: apiKey.trimmingCharacters(in: .whitespaces), projectID: projectID.trimmingCharacters(in: .whitespaces))
                    run {
                        try await model.connectCloud()
                        refresh += 1
                        if let info = try await model.cloudDownload(), !model.hasLocalUserData {
                            pending = info
                        } else {
                            try await model.cloudUpload(force: true)
                            message = "Cloud sync is on. Pulse backs up to your Firebase project whenever you leave the app."
                        }
                    }
                } label: {
                    Label("Sign In with Google", systemImage: "person.crop.circle.badge.checkmark")
                }
                .disabled(apiKey.isEmpty || projectID.isEmpty || !model.isConnected)
                Button("How to set up Firebase") { showSetup = true }
            }
            if busy {
                HStack { ProgressView(); Text("Working…").foregroundStyle(.secondary) }
            }
        } header: {
            Text("Cloud Sync (Firebase)")
        } footer: {
            Text(model.isConnected
                 ? "Saves your journal, activities, workouts, templates and settings to your own free Firebase project, signed in with your Google account. Restore on any reinstall."
                 : "Connect Google Health first. Cloud sync uses the same Google account.")
        }
        .id(refresh)
        .onAppear {
            apiKey = model.cloudConfig?.apiKey ?? ""
            projectID = model.cloudConfig?.projectID ?? ""
        }
        .sheet(isPresented: $showSetup) { FirebaseSetupGuide() }
        .confirmationDialog(
            pending.map { "Restore the cloud backup from \($0.updatedAt.formatted(date: .abbreviated, time: .shortened))\($0.device.map { " (\($0))" } ?? "")? This replaces your journal, activities and workouts on this phone." } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible
        ) {
            Button("Restore", role: .destructive) {
                guard let info = pending else { return }
                pending = nil
                do { message = try model.restoreBackup(info.data) } catch { message = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) { pending = nil }
        }
        .alert("Cloud Sync", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        busy = true
        Task {
            do { try await work() } catch { message = error.localizedDescription }
            busy = false
        }
    }
}

struct FirebaseSetupGuide: View {
    @Environment(\.dismiss) private var dismiss

    private let rules = """
    rules_version = '2';
    service cloud.firestore {
      match /databases/{database}/documents {
        match /users/{userId}/{document=**} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }
      }
    }
    """

    var body: some View {
        NavigationStack {
            List {
                Section("1. Add Firebase to your Google project") {
                    Text("On a computer, go to console.firebase.google.com and click Create a project. Choose your existing Google Cloud project, the one with your Pulse client ID. Using the same project lets Firebase accept your Google sign-in. Skip Google Analytics. Stay on the free Spark plan.")
                }
                Section("2. Turn on Google sign-in") {
                    Text("Go to Build, then Authentication, then Get started. Under Sign-in method, pick Google, turn it on, choose your email as the support email, and save.")
                }
                Section("3. Create the database") {
                    Text("Go to Build, then Firestore Database, then Create database. Pick a location near you and start in production mode.")
                }
                Section("4. Paste the security rules") {
                    Text("In Firestore, open the Rules tab, replace everything with this, and click Publish. It makes sure only you can read your data.")
                    Text(rules)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                    Button("Copy Rules") { UIPasteboard.general.string = rules }
                }
                Section("5. Copy two values") {
                    Text("Click the gear next to Project Overview, then Project settings. Copy the Project ID and the Web API Key into Pulse. If no Web API Key shows, finish step 2 first and reload the page.")
                }
                Section("6. Reconnect Google once") {
                    Text("In Pulse Settings, disconnect Google and connect again. This lets Pulse use your Google account for the cloud. Then tap Sign In with Google under Cloud Sync.")
                }
            }
            .navigationTitle("Firebase Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
