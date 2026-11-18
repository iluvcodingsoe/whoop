import SwiftUI

// MARK: - Seiten-Gerüst

/// Hintergrund aller Hauptseiten: dezenter Verlauf von oben nach unten.
struct ScreenBackground: View {
    var body: some View {
        Theme.bgGradient.ignoresSafeArea()
    }
}

/// Zentrierter Titel in Versalien, wie "JOURNAL" oder "HEALTH MONITOR".
struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 15, weight: .bold))
            .kerning(2)
            .foregroundStyle(Theme.textPrimary)
    }
}

/// Große Abschnitts-Überschrift ("Log", "Check-in", "Measurements").
struct SectionHeading: View {
    let text: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .center) {
            Text(text)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.top, 10)
    }
}

/// Kleines Label in Versalien mit Laufweite.
struct CapsLabel: View {
    let text: String
    var color: Color = Theme.textPrimary
    var size: CGFloat = 13

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .bold))
            .kerning(1.6)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

/// Flache, abgerundete Karte im neuen Stil.
struct Panel<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
    }
}

/// Dünne Trennlinie innerhalb von Panels.
struct PanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }
}

// MARK: - Kopfleiste

/// "‹ TODAY ›": blättert durch die Tage mit Daten.
struct DayStepper: View {
    @Environment(AppModel.self) private var model

    private var keys: [String] { model.availableKeys }

    private var index: Int? { keys.firstIndex(of: model.selectedDayKey) }

    private var title: String {
        let key = model.selectedDayKey
        if key == DayKey.today() { return model.loc("Heute", "Today") }
        if key == DayKey.addDays(DayKey.today(), -1) { return model.loc("Gestern", "Yesterday") }
        return Fmt.dayShort(key)
    }

    var body: some View {
        HStack(spacing: 2) {
            arrow("chevron.left", enabled: (index ?? 0) > 0) {
                if let i = index, i > 0 { model.selectedDayKey = keys[i - 1] }
            }
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .kerning(1.4)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 14)
                .frame(minWidth: 88)
                .frame(height: 36)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            arrow("chevron.right", enabled: index.map { $0 < keys.count - 1 } ?? false) {
                if let i = index, i < keys.count - 1 { model.selectedDayKey = keys[i + 1] }
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.04)))
        .animation(.easeOut(duration: 0.15), value: model.selectedDayKey)
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? Theme.textPrimary.opacity(0.8) : Theme.textSecondary.opacity(0.35))
                .frame(width: 28, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Stilisiertes Armband mit Status-Punkt (grün = verbunden oder Demo).
struct BandIcon: View {
    var active: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.textPrimary.opacity(0.9), lineWidth: 2)
                    .frame(width: 17, height: 30)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Theme.textPrimary.opacity(0.9))
                    .frame(width: 6, height: 11)
                    .offset(x: -1)
            }
            .rotationEffect(.degrees(14))
            .frame(width: 26, height: 32)
            Circle()
                .fill(active ? Theme.green : Theme.textSecondary)
                .frame(width: 9, height: 9)
                .offset(x: 6, y: -4)
        }
    }
}

/// Rechter Teil der Kopfleiste: "Demo" bzw. Sync-Status und Armband.
struct DeviceStatus: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            if model.isConnected, !model.syncing {
                Task { await model.syncNow() }
            }
        } label: {
            HStack(spacing: 8) {
                if model.syncing {
                    ProgressView()
                        .controlSize(.small)
                } else if model.demoMode {
                    Text("Demo")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize()
                }
                BandIcon(active: model.isConnected || model.demoMode)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Score-Ring

/// Großer Ring der Startseite: Wert in der Mitte, Label mit Pfeil darunter.
struct ScoreRing: View {
    let value: String
    let unit: String
    let fraction: Double
    let color: Color
    var marker: Double? = nil
    let label: String

    @State private var shown = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Theme.track.opacity(0.75), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: shown ? CGFloat(Stats.clamp(fraction, 0.004, 1)) : 0.004)
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                if let marker {
                    GeometryReader { geo in
                        let r = min(geo.size.width, geo.size.height) / 2
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 3, height: 13)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2 - r)
                            .rotationEffect(.degrees(Stats.clamp(marker, 0, 1) * 360))
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(.system(size: 34, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    }
                }
                .padding(.horizontal, 10)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(4)

            HStack(spacing: 4) {
                CapsLabel(text: label, size: 13)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { shown = true }
        }
    }
}

// MARK: - Status-Kachel

/// Kachel für Health und Stress Monitor auf der Startseite.
struct MonitorTile<Badge: View>: View {
    let title: String
    let status: String
    let statusColor: Color
    let detail: String
    @ViewBuilder var badge: Badge

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                CapsLabel(text: title, size: 12)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 10) {
                badge
                VStack(alignment: .leading, spacing: 3) {
                    Text(status.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .kerning(0.6)
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
    }
}

/// Quadratisches Icon-Feld mit getönter Fläche.
struct TintedSquare<Content: View>: View {
    let color: Color
    var size: CGFloat = 40
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.18)))
    }
}

// MARK: - Zeilen

/// Zeile mit Icon, Titel in Versalien, Unterzeile und Wert rechts.
struct MetricRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let value: String
    let unit: String
    var comparison: String? = nil
    var trend: Trend? = nil
    var showChevron = true

    enum Trend { case up, down, flat }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                CapsLabel(text: title, size: 13)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                    Text(unit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                if let comparison {
                    Text(comparison)
                        .font(.system(size: 14).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if let trend {
                Image(systemName: trend == .up ? "arrowtriangle.up.fill" : trend == .down ? "arrowtriangle.down.fill" : "equal")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 12)
            } else if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Screenshot-Hilfe (nur CI)

/// Mit `-screenshotScroll` als Startargument scrollt die Seite nach dem Laden
/// ans Ende, damit automatische Design-Screenshots auch den unteren Teil zeigen.
struct ScreenshotScrollAnchor: View {
    let proxy: ScrollViewProxy

    var body: some View {
        Color.clear
            .frame(height: 1)
            .id("screenshot-bottom")
            .onAppear {
                guard ProcessInfo.processInfo.arguments.contains("-screenshotScroll") else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    proxy.scrollTo("screenshot-bottom", anchor: .bottom)
                }
            }
    }
}

// MARK: - Deep-Dive-Bausteine (Sleep, Recovery, Strain)

/// Großer Ring oben auf den Detailseiten.
struct DeepDiveHero: View {
    let value: String
    let unit: String
    let caption: String
    let fraction: Double
    let color: Color
    var marker: Double? = nil
    var size: CGFloat = 200

    @State private var shown = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track.opacity(0.7), lineWidth: 12)
            Circle()
                .trim(from: 0, to: shown ? CGFloat(Stats.clamp(fraction, 0.004, 1)) : 0.004)
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.35), radius: 10)
            if let marker {
                GeometryReader { geo in
                    let r = min(geo.size.width, geo.size.height) / 2
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 4, height: 20)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 - r)
                        .rotationEffect(.degrees(Stats.clamp(marker, 0, 1) * 360))
                }
            }
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 58, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary.opacity(0.8))
                    }
                }
                CapsLabel(text: caption, color: Theme.textSecondary, size: 12)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { shown = true }
        }
    }
}

/// Zeitraum-Auswahl (7 / 30 / 90 Tage) als Kapsel-Segmente.
struct RangePicker: View {
    @Binding var days: Int
    var options: [Int] = [7, 30, 90]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let active = option == days
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { days = option }
                } label: {
                    Text("\(option)D")
                        .font(.system(size: 13, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(active ? Color.black : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(Capsule().fill(active ? Color.white : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }
}

/// Kachel mit Label, großem Wert und Unterzeile.
struct StatTile: View {
    let label: String
    let value: String
    var unit: String = ""
    var sub: String? = nil
    var subColor: Color = Theme.textSecondary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CapsLabel(text: label, color: Theme.textSecondary, size: 11)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if let sub {
                Text(sub)
                    .font(.system(size: 13))
                    .foregroundStyle(subColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }
}

/// Zeile mit Titel, Wert rechts und farbigem Fortschrittsbalken darunter.
struct ProgressRow: View {
    let title: String
    let value: String
    let fraction: Double
    let color: Color
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 17, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: max(6, geo.size.width * CGFloat(Stats.clamp(fraction, 0, 1))))
                }
            }
            .frame(height: 8)
            if let detail {
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 16)
    }
}

/// Wert gegen Schnitt: "▲ 4 vs. avg" in grün/orange, je nachdem was gut ist.
struct VersusLabel: View {
    let current: Double
    let average: Double
    let higherIsBetter: Bool
    let format: String
    let suffix: String

    var body: some View {
        let diff = current - average
        let good = higherIsBetter ? diff >= 0 : diff <= 0
        let flat = abs(diff) < max(abs(average) * 0.01, 0.05)
        HStack(spacing: 4) {
            Image(systemName: flat ? "equal" : (diff > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill"))
                .font(.system(size: 9, weight: .bold))
            Text(String(format: format, abs(diff)) + suffix)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(flat ? Theme.textSecondary : (good ? Theme.green : Theme.orange))
    }
}

/// Farbe für Prozent-Kennzahlen (≥ 85 gut, ≥ 70 mittel, sonst schwach).
func percentColor(_ value: Double) -> Color {
    if value >= 85 { return Theme.green }
    if value >= 70 { return Theme.yellow }
    return Theme.red
}

/// Passendes SF-Symbol für einen Workout-Namen (Deutsch oder Englisch).
func workoutSymbol(_ name: String) -> String {
    let n = name.lowercased()
    if n.contains("golf") { return "figure.golf" }
    if n.contains("lauf") || n.contains("run") || n.contains("jog") { return "figure.run" }
    if n.contains("kraft") || n.contains("strength") || n.contains("weight") || n.contains("gym") { return "dumbbell.fill" }
    if n.contains("rad") || n.contains("bike") || n.contains("cycl") { return "figure.outdoor.cycle" }
    if n.contains("schwimm") || n.contains("swim") { return "figure.pool.swim" }
    if n.contains("yoga") { return "figure.yoga" }
    if n.contains("geh") || n.contains("walk") || n.contains("spazier") || n.contains("wander") || n.contains("hik") { return "figure.walk" }
    if n.contains("tennis") { return "figure.tennis" }
    if n.contains("fußball") || n.contains("soccer") || n.contains("football") { return "figure.soccer" }
    if n.contains("basket") { return "figure.basketball" }
    return "figure.mixed.cardio"
}

/// ScrollView der Detailseiten. Für CI-Screenshots kann `-screenshotSection <id>`
/// direkt zu einem Abschnitt springen.
struct DeepDiveScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
            }
            .scrollIndicators(.hidden)
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                guard let i = args.firstIndex(of: "-screenshotSection"), i + 1 < args.count else { return }
                let id = args[i + 1]
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    proxy.scrollTo(id, anchor: .top)
                }
            }
        }
    }
}
