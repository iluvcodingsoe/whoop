import SwiftUI

// MARK: - Kopfleiste der Detailseiten

/// Eigene Kopfleiste: Zurück-Pfeil, Datum in Versalien, optional ein Element rechts.
struct DetailHeader<Trailing: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var title: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text((title ?? dayTitle).uppercased())
                .font(.system(size: 15, weight: .bold))
                .kerning(2)
                .foregroundStyle(Theme.textPrimary)
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                Spacer()
                trailing
            }
        }
        .frame(height: 48)
    }

    private var dayTitle: String {
        let key = model.selectedDayKey
        if key == DayKey.today() { return "Today" }
        if key == DayKey.addDays(DayKey.today(), -1) { return "Yesterday" }
        return Fmt.dayShort(key)
    }
}

extension DetailHeader where Trailing == EmptyView {
    init(title: String? = nil) {
        self.title = title
        self.trailing = EmptyView()
    }
}

// MARK: - Großer Ring

/// Großer Ring mit Wordmark, Wert und Label – oben auf Recovery und Strain.
struct BigRing: View {
    let value: String
    let unit: String
    let label: String
    let fraction: Double
    let color: Color
    var marker: Double? = nil

    @State private var shown = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 26)
            Circle()
                .trim(from: 0, to: shown ? CGFloat(Stats.clamp(fraction, 0.004, 1)) : 0.004)
                .stroke(color, style: StrokeStyle(lineWidth: 26, lineCap: .butt))
                .rotationEffect(.degrees(-90))
            if let marker {
                GeometryReader { geo in
                    let r = min(geo.size.width, geo.size.height) / 2
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 5, height: 30)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 - r)
                        .rotationEffect(.degrees(Stats.clamp(marker, 0, 1) * 360))
                }
            }
            VStack(spacing: 6) {
                Text("PULSE")
                    .font(.system(size: 22, weight: .medium))
                    .kerning(5)
                    .foregroundStyle(Theme.textPrimary.opacity(0.6))
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 76, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                Text(label.uppercased())
                    .font(.system(size: 17, weight: .bold))
                    .kerning(2.4)
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 290, height: 290)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { shown = true }
        }
    }
}

// MARK: - Vergleichs-Panel

/// Eine Zeile: Wert heute gegen den Schnitt der 30 Tage davor.
struct ComparisonItem: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let value: String
    let average: String?
    /// +1 = höher als Schnitt, -1 = niedriger, 0 = gleich, nil = kein Vergleich.
    let direction: Int?
    /// Ist "höher" hier gut?
    let higherIsBetter: Bool
}

/// Panel mit Spitze nach oben (zeigt auf den Ring), Zeilen und Fußzeile.
struct ComparisonPanel: View {
    let items: [ComparisonItem]
    let footer: String
    var pointer = true

    var body: some View {
        VStack(spacing: 0) {
            if pointer {
                Triangle()
                    .fill(Theme.card)
                    .frame(width: 28, height: 14)
            }
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { PanelDivider() }
                    row(item)
                }
                HStack(spacing: 8) {
                    HStack(spacing: 1) {
                        Image(systemName: "arrowtriangle.up.fill").foregroundStyle(Theme.green)
                        Image(systemName: "arrowtriangle.down.fill").foregroundStyle(Theme.orange)
                    }
                    .font(.system(size: 9))
                    Text(footer)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.35)))
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 22)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.card)
            )
            .offset(y: -1)
        }
    }

    private func row(_ item: ComparisonItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbol)
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28)
            Text(item.title.uppercased())
                .font(.system(size: 14, weight: .bold))
                .kerning(1.6)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.value)
                    .font(.system(size: 28, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                if let average = item.average {
                    Text(average)
                        .font(.system(size: 15, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            arrow(item)
                .frame(width: 12)
        }
        .padding(.vertical, 18)
    }

    @ViewBuilder
    private func arrow(_ item: ComparisonItem) -> some View {
        if let direction = item.direction, direction != 0 {
            let good = (direction > 0) == item.higherIsBetter
            Image(systemName: direction > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundStyle(good ? Theme.green : Theme.orange)
        } else {
            Color.clear
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Richtung eines Werts gegen den Schnitt, mit kleiner Toleranz.
func comparisonDirection(_ value: Double?, _ average: Double?) -> Int? {
    guard let value, let average else { return nil }
    let tolerance = max(abs(average) * 0.01, 0.05)
    if abs(value - average) < tolerance { return 0 }
    return value > average ? 1 : -1
}

// MARK: - Hinweis-Karte

/// Karte mit Text und farbigem Verlaufsrahmen.
struct InsightCard: View {
    let text: String
    var linkTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(text)
                .font(.system(size: 18))
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if let linkTitle, let action {
                Button(action: action) {
                    HStack(spacing: 8) {
                        Text(linkTitle.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .kerning(1.4)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: 0x8C7CF0))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: 0x1C1F2A))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [Color(hex: 0x6A5AE0), Color(hex: 0x3D8BFF), Color(hex: 0x35D0BA)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - 30-Tage-Schnitt

extension AppModel {
    /// Schnitt eines Tageswerts über die 30 Tage vor `key` (ohne `key`).
    func average30(before key: String, _ value: (DayRecord) -> Double?) -> Double? {
        let values = trend(30, endingAt: DayKey.addDays(key, -1), value).map(\.value)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
