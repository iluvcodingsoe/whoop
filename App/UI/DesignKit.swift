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
                .font(.system(size: 14, weight: .bold))
                .kerning(1.6)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minWidth: 96)
                .frame(height: 38)
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
                .frame(width: 34, height: 38)
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
            HStack(spacing: 10) {
                if model.syncing {
                    ProgressView()
                        .controlSize(.small)
                } else if model.demoMode {
                    Text("Demo")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
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
            HStack(spacing: 12) {
                badge
                VStack(alignment: .leading, spacing: 3) {
                    Text(status.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(detail)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
    }
}

/// Quadratisches Icon-Feld mit getönter Fläche.
struct TintedSquare<Content: View>: View {
    let color: Color
    var size: CGFloat = 44
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
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                CapsLabel(text: title, size: 13)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
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
