import SwiftUI

/// Health-Tab: aktueller Puls oben, darunter die Werte der letzten Nacht als Kacheln
/// mit deinem persönlichen Bereich.
struct HealthMonitorView: View {
    @Environment(AppModel.self) private var model
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ScreenTitle(text: "Health monitor")
                            .frame(height: 44)
                            .padding(.top, 6)

                        DayStepper()
                            .fixedSize()
                            .padding(.top, 10)

                        heartHero
                            .padding(.top, 14)

                        if model.hasData {
                            HStack(spacing: 10) {
                                CapsLabel(text: model.selectedDayKey == DayKey.today() ? "Last night\u{2019}s readings" : "Readings that night", size: 14)
                                Button {
                                    showInfo = true
                                } label: {
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 22, weight: .light))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 26)

                            tilesGrid
                                .padding(.top, 22)

                            if let alert = model.healthAlert {
                                alertPanel(alert)
                                    .padding(.top, 16)
                            }

                            Text("Not a diagnosis. Readings outside your range can point to illness, stress or overtraining. Talk to your doctor if you\u{2019}re worried.")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                                .lineSpacing(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 18)
                                .padding(.horizontal, 4)
                        } else {
                            EmptyDataHint(text: "No data available.")
                                .padding(.top, 40)
                        }
                        ScreenshotScrollAnchor(proxy: proxy)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showInfo) {
                infoSheet
            }
        }
    }

    // MARK: - Puls oben

    private var latestHeartRate: (bpm: Double, time: Date?)? {
        let record = model.selectedRecord
        if let last = record?.hrSamples.max(by: { $0.t < $1.t }) { return (last.bpm, last.t) }
        if let rhr = record?.restingHR { return (rhr, nil) }
        return nil
    }

    private var heartHero: some View {
        let hr = latestHeartRate
        return ZStack {
            // Untere Hälfte: blauer Schimmer unter der Linie.
            VStack(spacing: 0) {
                Color.clear.frame(height: 120)
                LinearGradient(colors: [Color(hex: 0x1D4A6E).opacity(0.75), Color.clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
            }
            .padding(.horizontal, -20)

            Rectangle()
                .fill(Theme.accent)
                .frame(height: 2.5)
                .padding(.horizontal, -20)
                .shadow(color: Theme.accent.opacity(0.7), radius: 6)

            ZStack {
                Circle()
                    .fill(Color(hex: 0x121518))
                    .shadow(color: .black.opacity(0.6), radius: 18, y: 6)
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.textSecondary)
                    Text(hr.map { "\(Int($0.bpm.rounded()))" } ?? "–")
                        .font(.system(size: 62, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                    Text("BPM")
                        .font(.system(size: 15, weight: .semibold))
                        .kerning(3)
                        .foregroundStyle(Theme.textSecondary)
                    if let time = hr?.time {
                        Text(Fmt.clock(time))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    }
                }
            }
            .frame(width: 200, height: 200)
        }
        .frame(height: 240)
    }

    // MARK: - Kacheln

    private var tilesGrid: some View {
        let statuses = Dictionary(uniqueKeysWithValues: model.healthStatuses.map { ($0.kind, $0) })
        let order: [HealthMetricKind] = [.respiratoryRate, .spo2, .restingHR, .hrv, .bodyTemp]

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(order, id: \.self) { kind in
                NavigationLink {
                    VitalDetailView(kind: kind)
                } label: {
                    VitalTile(kind: kind, status: statuses[kind])
                }
                .buttonStyle(.plain)
            }
            ShareLink(item: reportText) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text("SHARE YOUR HEALTH REPORT")
                            .font(.system(size: 14, weight: .bold))
                            .kerning(0.8)
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text("A summary of your readings to send to your doctor, coach, or anyone you choose.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private var reportText: String {
        let key = model.selectedDayKey
        var lines = ["Pulse health report – \(Fmt.dayTitle(key))", ""]
        for status in model.healthStatuses {
            let value = status.value.map { VitalTile.valueText(status.kind, $0, baseline: status.baseline) } ?? "no reading"
            let unit = VitalTile.unitText(status.kind)
            lines.append("\(VitalTile.title(status.kind)): \(value) \(unit) – \(VitalTile.pillText(status))")
        }
        if let recovery = model.recovery(for: key) {
            lines.append("")
            lines.append("Recovery: \(recovery.score)%")
        }
        lines.append("")
        lines.append("Ranges are personal 30-day baselines from Pulse. Not a medical diagnosis.")
        return lines.joined(separator: "\n")
    }

    private func alertPanel(_ alert: HealthAlert) -> some View {
        Panel(padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.orange)
                VStack(alignment: .leading, spacing: 4) {
                    CapsLabel(text: "Notice", size: 13)
                    Text(alert.message)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Info

    private var infoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(model.loc(
                        "Jeder nächtliche Wert wird mit deinem persönlichen 30-Tage-Band verglichen (Mittelwert ± 1,65 Standardabweichungen). Ein Wert außerhalb des Bands ist ungewöhnlich für dich, nicht unbedingt ungesund.",
                        "Each overnight reading is compared with your personal 30-day band (average ± 1.65 standard deviations). A reading outside the band is unusual for you, not necessarily unhealthy."
                    ))
                    Text(model.loc(
                        "Mehrere Werte außerhalb des Bands, oder einer über mehrere Tage, sind oft frühe Anzeichen für einen Infekt oder Übertraining.",
                        "Several readings outside the band, or one for several days in a row, are often early signs of illness or overtraining."
                    ))
                    Text(model.loc(
                        "Messwerte vergleichen den letzten Wert mit dem Schnitt der 30 Tage davor. Gewicht trägst du im Journal ein.",
                        "Measurements compare the latest reading with the average of the 30 days before it. You log weight in Journal."
                    ))
                }
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary.opacity(0.85))
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Health monitor")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

// MARK: - Kachel eines Vitalwerts

struct VitalTile: View {
    let kind: HealthMetricKind
    let status: HealthMetricStatus?

    var body: some View {
        let state = status?.state ?? .noData
        let good = Self.isGood(status)
        let pillColor: Color = (state == .noData || state == .calibrating) ? Theme.textSecondary : (good ? Theme.green : Theme.orange)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: Self.symbol(kind))
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30)
                Text(Self.title(kind).uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .kerning(0.4)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 36, alignment: .leading)

            Spacer(minLength: 14)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(status?.value.map { Self.valueText(kind, $0, baseline: status?.baseline) } ?? "–")
                    .font(.system(size: 40, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(Self.unitText(kind))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer(minLength: 14)

            HStack(spacing: 6) {
                if state != .noData && state != .calibrating {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(Self.pillText(status))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(pillColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(pillColor.opacity(0.16)))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    static func title(_ kind: HealthMetricKind) -> String {
        switch kind {
        case .respiratoryRate: return "Respiratory rate"
        case .spo2: return "Blood oxygen"
        case .restingHR: return "RHR"
        case .hrv: return "HRV"
        case .bodyTemp: return "Skin temp (from baseline)"
        }
    }

    static func symbol(_ kind: HealthMetricKind) -> String {
        switch kind {
        case .respiratoryRate: return "lungs"
        case .spo2: return "drop"
        case .restingHR: return "heart"
        case .hrv: return "waveform.path.ecg"
        case .bodyTemp: return "thermometer.medium"
        }
    }

    static func unitText(_ kind: HealthMetricKind) -> String {
        switch kind {
        case .respiratoryRate: return "rpm"
        case .spo2: return "%"
        case .restingHR: return "bpm"
        case .hrv: return "ms"
        case .bodyTemp: return "°F"
        }
    }

    /// Hauttemperatur als Abweichung vom Schnitt in °F, sonst der Wert selbst.
    static func valueText(_ kind: HealthMetricKind, _ value: Double, baseline: Baseline?) -> String {
        switch kind {
        case .bodyTemp:
            guard let mean = baseline?.mean else { return "–" }
            return String(format: "%+.1f", (value - mean) * 1.8)
        case .spo2: return String(format: "%.0f", value)
        case .respiratoryRate: return String(format: "%.1f", value)
        default: return String(format: "%.0f", value)
        }
    }

    private static func bound(_ kind: HealthMetricKind, _ value: Double, baseline: Baseline?) -> String {
        if kind == .bodyTemp, let mean = baseline?.mean {
            return String(format: "%+.1f", (value - mean) * 1.8)
        }
        return valueText(kind, value, baseline: baseline)
    }

    static func pillText(_ status: HealthMetricStatus?) -> String {
        guard let status else { return "no reading" }
        let kind = status.kind
        switch status.state {
        case .noData: return "no reading"
        case .calibrating: return "calibrating"
        case .inRange:
            guard let lower = status.lowerBound else { return "within range" }
            if let upper = status.upperBound {
                return "within \(bound(kind, lower, baseline: status.baseline)) – \(bound(kind, upper, baseline: status.baseline))"
            }
            return "above \(bound(kind, lower, baseline: status.baseline))"
        case .above:
            return "elevated > \(status.upperBound.map { bound(kind, $0, baseline: status.baseline) } ?? "")"
        case .below:
            return "low < \(status.lowerBound.map { bound(kind, $0, baseline: status.baseline) } ?? "")"
        }
    }

    /// Ist die Abweichung in die gute Richtung (z. B. HRV höher)?
    static func isGood(_ status: HealthMetricStatus?) -> Bool {
        guard let status else { return true }
        switch status.state {
        case .inRange, .calibrating, .noData: return true
        case .above: return status.kind == .hrv || status.kind == .spo2
        case .below: return status.kind == .restingHR || status.kind == .respiratoryRate
        }
    }
}

// MARK: - Detailseite eines Vitalwerts

struct VitalDetailView: View {
    @Environment(AppModel.self) private var model
    let kind: HealthMetricKind

    var body: some View {
        let status = model.healthStatuses.first { $0.kind == kind }
        let points = trendPoints(model.trend(30) { record in Self.value(kind, record) })

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(status?.value.map { kind.formatted($0) } ?? "–")
                                .font(.system(size: 52, weight: .bold).monospacedDigit())
                                .foregroundStyle(Theme.textPrimary)
                            Text(kind.unit(model.language))
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            if let status {
                                PillBadge(text: Theme.bandLabel(status.state).uppercased(), color: Theme.bandColor(status.state))
                            }
                        }
                        if let status, let lower = status.lowerBound {
                            let upperText = status.upperBound.map { kind.formatted($0) } ?? "∞"
                            Text(model.loc("Dein Bereich: \(kind.formatted(lower)) – \(upperText) \(kind.unit(model.language))", "Your range: \(kind.formatted(lower)) – \(upperText) \(kind.unit(model.language))"))
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textSecondary)
                        } else if let baseline = status?.baseline {
                            Text(model.loc("Schnitt: \(kind.formatted(baseline.mean)) \(kind.unit(model.language)) (\(baseline.count) Nächte)", "Average: \(kind.formatted(baseline.mean)) \(kind.unit(model.language)) (\(baseline.count) nights)"))
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        CapsLabel(text: model.loc("Letzte 30 Tage", "Last 30 days"), color: Theme.textSecondary)
                        if points.count >= 2 {
                            BaselineLineChart(
                                points: points,
                                baseline: status?.baseline,
                                color: status.map { Theme.bandColor($0.state) == Theme.textSecondary ? Theme.accent : Theme.bandColor($0.state) } ?? Theme.accent,
                                height: 200
                            )
                        } else {
                            EmptyDataHint(text: model.loc("Zu wenige Messungen.", "Not enough readings."))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(ScreenBackground())
        .navigationTitle(kind.label(model.language))
        .navigationBarTitleDisplayMode(.inline)
    }

    static func value(_ kind: HealthMetricKind, _ record: DayRecord) -> Double? {
        switch kind {
        case .restingHR: return record.restingHR
        case .hrv: return record.hrvRmssd
        case .respiratoryRate: return record.respiratoryRate
        case .spo2: return record.spo2Avg
        case .bodyTemp: return record.bodyTemp
        }
    }
}
