import SwiftUI
import WidgetKit

// Gemeinsam genutzt vom Widget und von der App (Vorschau für CI-Screenshots).

struct PulseEntry: TimelineEntry {
    let date: Date
    let score: Int?
    let zone: String
    let sleepPerformance: Double?
    let strain: Double?
    let strainTarget: Double?
}

/// Findet die App Group, die dieses Build wirklich nutzen darf. Sideloading-Tools
/// (Sideloadly, AltStore, SideStore …) signieren mit einer eigenen Gruppe neu. Die
/// zuverlässigste Quelle ist das eingebettete Provisioning-Profil, dessen
/// Entitlements die tatsächlich erteilten Gruppen enthalten.
enum AppGroupResolver {
    static let fallback = "group.net.dehlwes.pulse"

    /// Gruppen aus `embedded.mobileprovision` eines Bundles.
    static func profileGroups(in bundle: Bundle) -> [String] {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return [] }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String]
        else { return [] }
        return groups
    }

    /// Kandidaten in Reihenfolge; `bundles` = eigenes Bundle und ggf. die Host-App.
    static func candidates(bundles: [Bundle]) -> [String] {
        var result: [String] = []
        for bundle in bundles { result += profileGroups(in: bundle) }
        for bundle in bundles {
            result += bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []
        }
        result.append(fallback)
        for bundle in bundles {
            if let id = bundle.bundleIdentifier { result.append("group." + id) }
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0).inserted }
    }

    static func resolve(bundles: [Bundle]) -> String {
        let list = candidates(bundles: bundles)
        return list.first {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
        } ?? list.first ?? fallback
    }
}

/// Recovery-Zonenfarbe im Widget.
func widgetZoneColor(_ zone: String) -> Color {
    switch zone {
    case "green": return Color(red: 0.184, green: 0.839, blue: 0.451)
    case "yellow": return Color(red: 0.961, green: 0.773, blue: 0.259)
    case "red": return Color(red: 0.937, green: 0.325, blue: 0.314)
    default: return Color(red: 0.54, green: 0.59, blue: 0.65)
    }
}

// MARK: - Breites Widget: drei Werte nebeneinander

struct ScoresWidgetView: View {
    var entry: PulseEntry

    private let background = Color(red: 0.133, green: 0.153, blue: 0.176)
    private let sleepBlue = Color(red: 0.498, green: 0.651, blue: 0.776)
    private let strainColor = Color(red: 0.039, green: 0.576, blue: 0.961)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("PULSE")
                    .font(.system(size: 17, weight: .light))
                    .kerning(3.5)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day()))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer(minLength: 6)
            HStack(alignment: .top, spacing: 0) {
                column(
                    symbol: "figure.mind.and.body",
                    value: entry.score.map { "\($0)" },
                    unit: "%",
                    label: "Recovery",
                    color: entry.score == nil ? .gray : widgetZoneColor(entry.zone)
                )
                column(
                    symbol: "figure.strengthtraining.traditional",
                    value: entry.strain.map { String(format: "%.1f", $0) },
                    unit: "",
                    label: "Strain",
                    color: strainColor
                )
                column(
                    symbol: "moon",
                    value: entry.sleepPerformance.map { "\(Int($0.rounded()))" },
                    unit: "%",
                    label: "Sleep",
                    color: sleepBlue
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .containerBackground(background, for: .widget)
    }

    private func column(symbol: String, value: String?, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
                .frame(height: 26)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value ?? "–")
                    .font(.system(size: 30, weight: .bold).monospacedDigit())
                if value != nil && !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 12, weight: .bold))
                .kerning(1.4)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

