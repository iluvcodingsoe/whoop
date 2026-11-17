import SwiftUI

/// Health-Tab: nächtliche Vitalwerte gegen dein Baseline-Band und Messwerte im 30-Tage-Vergleich.
struct HealthMonitorView: View {
    @Environment(AppModel.self) private var model
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        HStack {
                            Spacer()
                            DayStepper().fixedSize()
                            Spacer()
                        }
                        .padding(.top, 18)

                        if model.hasData {
                            SectionHeading(text: model.loc("Vitalwerte", "Overnight vitals"))
                                .padding(.top, 30)
                            vitalsPanel
                                .padding(.top, 16)

                            if let alert = model.healthAlert {
                                alertPanel(alert)
                                    .padding(.top, 14)
                            }

                            Text(model.loc(
                                "Keine Diagnose. Abweichungen von deinem Bereich können auf Infekt, Stress oder Übertraining hinweisen. Sprich bei Sorgen mit deinem Arzt.",
                                "Not a diagnosis. Readings outside your range can point to illness, stress or overtraining. Talk to your doctor if you\u{2019}re worried."
                            ))
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(2)
                            .padding(.top, 14)
                            .padding(.horizontal, 6)

                            SectionHeading(text: model.loc("Messwerte", "Measurements"))
                                .padding(.top, 36)
                            measurementsPanel
                                .padding(.top, 16)
                ScreenshotScrollAnchor(proxy: proxy)
                        } else {
                            EmptyDataHint(text: model.loc("Keine Daten vorhanden.", "No data available."))
                                .padding(.top, 60)
                        }
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

    private var header: some View {
        ZStack {
            ScreenTitle(text: "Health monitor")
            HStack {
                Spacer()
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Theme.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 44)
        .padding(.top, 6)
    }

    // MARK: - Vitalwerte

    private var vitalsPanel: some View {
        let statuses = model.healthStatuses
        let measured = statuses.filter { $0.state != .noData }
        let inRange = measured.filter { $0.state == .inRange || $0.state == .calibrating }.count
        let outside = measured.count - inRange
        let date = DayKey.date(from: model.selectedDayKey) ?? Date()

        return Panel(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.textSecondary)
                        CapsLabel(text: model.loc("Letzte Nacht", "Last night"), color: Theme.textSecondary, size: 14)
                        Spacer()
                        Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(inRange)/\(measured.count)")
                            .font(.system(size: 46, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                        Text(model.loc("im Bereich", "within range"))
                            .font(.system(size: 19))
                            .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    }
                    if !measured.isEmpty {
                        let ok = outside == 0
                        Label(
                            ok ? model.loc("Alles in deinem Bereich", "All within your range")
                               : model.loc("\(outside) außerhalb deines Bereichs", "\(outside) outside your range"),
                            systemImage: ok ? "checkmark" : "exclamationmark.triangle"
                        )
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ok ? Theme.green : Theme.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill((ok ? Theme.green : Theme.orange).opacity(0.16))
                        )
                    }
                }
                .padding(20)

                ForEach(statuses, id: \.kind) { status in
                    PanelDivider()
                    NavigationLink {
                        VitalDetailView(kind: status.kind)
                    } label: {
                        vitalRow(status)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func vitalRow(_ status: HealthMetricStatus) -> some View {
        let unit = status.kind.unit(model.language)
        let subtitle: String = {
            switch status.state {
            case .noData: return model.loc("Keine Messung", "No reading")
            case .calibrating: return model.loc("Bereich wird kalibriert", "Calibrating range")
            default:
                guard let lower = status.lowerBound else { return Theme.bandLabel(status.state) }
                let upper = status.upperBound.map { status.kind.formatted($0) }
                return upper.map { model.loc("Bereich \(status.kind.formatted(lower))–\($0)", "Range \(status.kind.formatted(lower))–\($0)") }
                    ?? model.loc("Über \(status.kind.formatted(lower))", "Above \(status.kind.formatted(lower))")
            }
        }()

        return HStack(spacing: 12) {
            Circle()
                .fill(Theme.bandColor(status.state))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 4) {
                Text(status.kind.label(model.language))
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(status.state == .above || status.state == .below ? Theme.orange : Theme.textSecondary)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(status.value.map { status.kind.formatted($0) } ?? "–")
                    .font(.system(size: 26, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Text(unit)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private func alertPanel(_ alert: HealthAlert) -> some View {
        Panel(padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.orange)
                VStack(alignment: .leading, spacing: 4) {
                    CapsLabel(text: model.loc("Hinweis", "Notice"), size: 13)
                    Text(alert.message)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Messwerte

    private var measurementsPanel: some View {
        let key = model.selectedDayKey
        return Panel(padding: 0) {
            VStack(spacing: 0) {
                Group {
                    weightRow(key)
                    PanelDivider()
                    dailyRow(
                        symbol: "lungs",
                        title: "VO₂ max",
                        unit: "",
                        format: "%.0f",
                        key: key
                    ) { $0.vo2max }
                    PanelDivider()
                    dailyRow(
                        symbol: "heart",
                        title: model.loc("Ruhepuls", "Resting HR"),
                        unit: HealthMetricKind.restingHR.unit(model.language),
                        format: "%.0f",
                        key: key
                    ) { $0.restingHR }
                    PanelDivider()
                    dailyRow(
                        symbol: "shoeprints.fill",
                        title: model.loc("Schritte", "Steps"),
                        unit: "",
                        format: "%.0f",
                        key: key
                    ) { $0.steps.map(Double.init) }
                }
                .padding(.horizontal, 20)

                Text(model.loc("Letzter Wert vs. die 30 Tage davor", "Latest reading vs. the 30 days before it"))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.35)))
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 20)
            }
        }
    }

    /// Gewicht kommt aus dem Journal-Log.
    private func weightRow(_ key: String) -> some View {
        let latest: (date: String, kg: Double)? = model.dayLogs.values
            .filter { $0.date <= key && $0.weightKg != nil }
            .max { $0.date < $1.date }
            .map { ($0.date, $0.weightKg!) }
        let previous: Double? = latest.flatMap { latest in
            let start = DayKey.addDays(latest.date, -30)
            let values = model.dayLogs.values
                .filter { $0.date >= start && $0.date < latest.date }
                .compactMap(\.weightKg)
            return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }

        return Button {
            model.selectedTab = .journal
        } label: {
            MetricRow(
                symbol: "scalemass",
                title: model.loc("Gewicht", "Weight"),
                subtitle: latest.map { shortDate($0.date) } ?? model.loc("Im Journal eintragen", "Log it in Journal"),
                value: latest.map { String(format: "%.1f", $0.kg) } ?? "–",
                unit: "kg",
                comparison: previous.map { String(format: "%.1f", $0) },
                trend: zip2(latest?.kg, previous).map { trend($0, $1) }
            )
        }
        .buttonStyle(.plain)
    }

    /// Letzter Tageswert bis `key` gegen den Schnitt der 30 Tage davor.
    private func dailyRow(
        symbol: String,
        title: String,
        unit: String,
        format: String,
        key: String,
        value: @escaping (DayRecord) -> Double?
    ) -> some View {
        let latest = DayKey.keys(from: DayKey.addDays(key, -14), to: key).reversed()
            .first { model.record(for: $0).flatMap(value) != nil }
            .flatMap { k in model.record(for: k).flatMap(value).map { (k, $0) } }
        let previous: Double? = latest.flatMap { latest in
            let values = model.trend(30, endingAt: DayKey.addDays(latest.0, -1), value).map(\.value)
            return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }

        return MetricRow(
            symbol: symbol,
            title: title,
            subtitle: latest.map { shortDate($0.0) } ?? model.loc("Keine Daten", "No data"),
            value: latest.map { formatted($0.1, format) } ?? "–",
            unit: unit,
            comparison: previous.map { formatted($0, format) },
            trend: zip2(latest?.1, previous).map { trend($0, $1) }
        )
    }

    private func formatted(_ value: Double, _ format: String) -> String {
        if value >= 1000 { return Int(value.rounded()).formatted(.number) }
        return String(format: format, value)
    }

    private func trend(_ latest: Double, _ previous: Double) -> MetricRow.Trend {
        let diff = latest - previous
        if abs(diff) < max(0.005 * abs(previous), 0.05) { return .flat }
        return diff > 0 ? .up : .down
    }

    private func shortDate(_ key: String) -> String {
        (DayKey.date(from: key) ?? Date()).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
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
