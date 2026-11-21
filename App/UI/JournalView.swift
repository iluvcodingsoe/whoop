import SwiftUI

/// Journal: Wochenleiste, Tages-Log (Wasser, Essen, Gewicht, Stimmung) und Check-in.
struct JournalView: View {
    @Environment(AppModel.self) private var model
    @State private var logSheet: LogKind?
    @State private var showPicker = false

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

                        WeekStrip()
                            .padding(.top, 30)

                        journalCard
                            .padding(.top, 30)

                        impactsSection
                            .padding(.top, 32)
                            .id("impacts")

                        SectionHeading(text: "Log")
                            .padding(.top, 32)
                        logTiles
                            .padding(.top, 16)
                        Text(model.demoMode
                             ? model.loc("Demo: Deine Einträge bleiben in Pulse und erreichen nie Google.", "Demo: what you log stays in Pulse and never reaches Google.")
                             : model.loc("Deine Einträge bleiben auf deinem iPhone und erreichen nie Google.", "What you log stays on your iPhone and never reaches Google."))
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 14)

                        SectionHeading(text: "Measurements")
                            .padding(.top, 32)
                        MeasurementsPanel { logSheet = .weight }
                            .padding(.top, 16)

                ScreenshotScrollAnchor(proxy: proxy)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $logSheet) { kind in
                LogSheet(kind: kind, dayKey: model.selectedDayKey)
            }
            .sheet(isPresented: $showPicker) {
                BehaviorPickerSheet()
            }
        }
    }

    private var header: some View {
        ZStack {
            ScreenTitle(text: "Journal")
            HStack {
                Spacer()
                DeviceStatus()
            }
        }
        .frame(height: 44)
        .padding(.top, 6)
    }

    // MARK: - Log-Kacheln

    private var logTiles: some View {
        let log = model.dayLog(for: model.selectedDayKey)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LogKind.allCases) { kind in
                    Button {
                        logSheet = kind
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 24, weight: .regular))
                                .foregroundStyle(kind.hasValue(log) ? kind.color : Theme.textPrimary.opacity(0.85))
                                .frame(height: 28)
                            Spacer(minLength: 10)
                            if let summary = kind.summary(log, model) {
                                Text(summary)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            Text(kind.title(model))
                                .font(.system(size: 17, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(14)
                        .frame(width: 96, height: 118, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(kind.hasValue(log) ? kind.color.opacity(0.35) : Color.white.opacity(0.04), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - Journal

    private var journalCard: some View {
        let key = model.selectedDayKey
        let entry = model.journalEntry(for: key)
        let progress = model.journalProgress(for: key)
        let date = DayKey.date(from: key) ?? Date()
        let yes = entry.yesIDs.filter(model.isTracked).compactMap(JournalCatalog.behavior)
        let complete = progress.total > 0 && progress.answered >= progress.total

        return Panel(padding: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    CapsLabel(text: date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), size: 15)
                    Spacer()
                    if complete {
                        Label("Complete", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.green)
                    }
                }
                JournalProgressBar(answered: progress.answered, total: progress.total)
                if yes.isEmpty {
                    Text(progress.answered == 0
                         ? "Answer a few yes or no questions about this day. Pulse links them to the next morning\u{2019}s recovery."
                         : "You answered no to everything so far.")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.textPrimary.opacity(0.72))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    FlowTags(tags: yes.map { ($0.symbol, $0.title) })
                }
                Button {
                    model.journalPromptDay = key
                } label: {
                    Text(progress.answered == 0 ? "Start journal" : complete ? "Edit journal" : "Continue journal")
                        .font(.system(size: 17, weight: .bold))
                        .kerning(1.8)
                        .textCase(.uppercase)
                        .foregroundStyle(complete ? Theme.textPrimary : Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Capsule().fill(complete ? Color.white.opacity(0.1) : Color.white))
                }
                .buttonStyle(.plain)
                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Tracking \(model.trackedBehaviorIDs.count) behaviors")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Impacts

    private var impactsSection: some View {
        let insights = model.journalInsights
        let helps = insights.filter { $0.delta >= 0 }.sorted { $0.delta > $1.delta }
        let hurts = insights.filter { $0.delta < 0 }.sorted { $0.delta < $1.delta }
        let learning = model.trackedBehaviors.filter { b in !insights.contains { $0.behaviorID == b.id } }

        return VStack(alignment: .leading, spacing: 0) {
            SectionHeading(text: "Impacts")
            Text("How each behavior relates to your next-day recovery over the last 90 days.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)

            if !helps.isEmpty {
                impactGroup("Positive", insights: helps)
                    .padding(.top, 16)
            }
            if !hurts.isEmpty {
                impactGroup("Negative", insights: hurts)
                    .padding(.top, 16)
            }
            if !learning.isEmpty {
                CapsLabel(text: "Still learning", size: 13)
                    .padding(.top, 20)
                Panel(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(learning.enumerated()), id: \.element.id) { index, behavior in
                            if index > 0 { PanelDivider() }
                            learningRow(behavior)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 10)
            }
            Text("Needs 5 yes and 5 no answers in 90 days. Shows a link, not proof of cause.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
                .padding(.top, 12)
        }
    }

    private func impactGroup(_ title: String, insights: [FactorInsight]) -> some View {
        let maxDelta = max(insights.map { abs($0.percentChange) }.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 10) {
            CapsLabel(text: title, size: 13)
            Panel(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                        if index > 0 { PanelDivider() }
                        impactRow(insight, maxDelta: maxDelta)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func impactRow(_ insight: FactorInsight, maxDelta: Double) -> some View {
        let positive = insight.delta >= 0
        let color = positive ? Theme.green : Theme.red
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: insight.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(insight.title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(Int(insight.avgWith.rounded()))% with · \(Int(insight.avgWithout.rounded()))% without")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%+.0f%%", insight.percentChange))
                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                        .foregroundStyle(color)
                    Text(insight.confidence == .solid ? "Clear" : "Trend")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(color)
                        .frame(width: max(6, geo.size.width * CGFloat(abs(insight.percentChange) / maxDelta)))
                }
            }
            .frame(height: 5)
            .padding(.leading, 42)
        }
        .padding(.vertical, 16)
    }

    private func learningRow(_ behavior: JournalBehavior) -> some View {
        let counts = model.journalCounts(for: behavior.id)
        let need = JournalEngine.minDaysPerGroup
        return HStack(spacing: 14) {
            Image(systemName: behavior.symbol)
                .font(.system(size: 18))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28)
            Text(behavior.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("Yes \(min(counts.yes, need))/\(need) · No \(min(counts.no, need))/\(need)")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Messwerte (Journal)

/// Gewicht, VO₂ max, Ruhepuls und Schritte: letzter Wert gegen die 30 Tage davor.
struct MeasurementsPanel: View {
    @Environment(AppModel.self) private var model
    var onWeightTap: () -> Void

    // MARK: - Messwerte

    var body: some View {
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
            onWeightTap()
        } label: {
            MetricRow(
                symbol: "scalemass",
                title: model.loc("Gewicht", "Weight"),
                subtitle: latest.map { shortDate($0.date) } ?? "Tap to log your weight",
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

}

// MARK: - Wochenleiste

/// Acht Tage nebeneinander, Häkchen = eingecheckt.
struct WeekStrip: View {
    @Environment(AppModel.self) private var model

    private var keys: [String] {
        let today = DayKey.today()
        let selected = model.selectedDayKey
        // Ausgewählter Tag ist immer sichtbar; sonst endet die Leiste heute.
        let end = DayKey.addDays(selected, 0) > DayKey.addDays(today, -7) ? today : DayKey.addDays(selected, 3)
        return DayKey.keys(from: DayKey.addDays(end, -7), to: end)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(keys, id: \.self) { key in
                let selected = key == model.selectedDayKey
                let done = model.isCheckedIn(key)
                Button {
                    if model.record(for: key) != nil || key == DayKey.today() {
                        model.selectedDayKey = key
                    }
                } label: {
                    VStack(spacing: 10) {
                        Text(Fmt.weekdayLetter(key))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Text(Fmt.dayNumber(key))
                            .font(.system(size: 22, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                        ZStack {
                            if done {
                                Circle().fill(Theme.green.opacity(0.22))
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.green)
                            } else {
                                Circle().stroke(Theme.textSecondary.opacity(0.45), lineWidth: 1.5)
                            }
                        }
                        .frame(width: 24, height: 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selected ? Color.white.opacity(0.08) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Log-Arten

enum LogKind: String, CaseIterable, Identifiable {
    case water, food, weight, mood

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .water: return "drop"
        case .food: return "fork.knife"
        case .weight: return "scalemass"
        case .mood: return "face.smiling"
        }
    }

    var color: Color {
        switch self {
        case .water: return Color(hex: 0x5AA9F2)
        case .food: return Theme.orange
        case .weight: return Theme.green
        case .mood: return Theme.yellow
        }
    }

    @MainActor func title(_ model: AppModel) -> String {
        switch self {
        case .water: return model.loc("Wasser", "Water")
        case .food: return model.loc("Essen", "Food")
        case .weight: return model.loc("Gewicht", "Weight")
        case .mood: return model.loc("Stimmung", "Mood")
        }
    }

    func hasValue(_ log: DailyLog) -> Bool {
        switch self {
        case .water: return log.waterGlasses > 0
        case .food: return !log.food.isEmpty
        case .weight: return log.weightKg != nil
        case .mood: return log.mood != nil
        }
    }

    @MainActor func summary(_ log: DailyLog, _ model: AppModel) -> String? {
        switch self {
        case .water:
            if log.waterGlasses == 0 { return model.loc("Noch nichts", "None today") }
            return model.loc("\(log.waterGlasses) Gläser", "\(log.waterGlasses) glasses")
        case .food:
            if log.food.isEmpty { return nil }
            return model.loc("\(log.food.count) Einträge", "\(log.food.count) logged")
        case .weight:
            return log.weightKg.map { String(format: "%.1f kg", $0) }
        case .mood:
            return log.mood?.label(model.language)
        }
    }
}

// MARK: - Eingabe-Sheet

struct LogSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let kind: LogKind
    let dayKey: String

    @State private var foodText = ""
    @State private var weightText = ""
    @FocusState private var focused: Bool

    var body: some View {
        let log = model.dayLog(for: dayKey)
        NavigationStack {
            ZStack {
                ScreenBackground()
                VStack(alignment: .leading, spacing: 20) {
                    Text(Fmt.dayTitle(dayKey))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                    switch kind {
                    case .water: water(log)
                    case .food: food(log)
                    case .weight: weight(log)
                    case .mood: mood(log)
                    }
                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle(kind.title(model))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.loc("Fertig", "Done")) {
                        if kind == .weight { saveWeight() }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .onAppear {
            if let kg = log.weightKg { weightText = String(format: "%.1f", kg) }
        }
    }

    // Wasser: Gläser zählen.
    private func water(_ log: DailyLog) -> some View {
        VStack(spacing: 22) {
            HStack(spacing: 28) {
                roundButton("minus") {
                    model.updateDayLog(dayKey) { $0.waterGlasses = max(0, $0.waterGlasses - 1) }
                }
                VStack(spacing: 4) {
                    Text("\(log.waterGlasses)")
                        .font(.system(size: 64, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text(model.loc("Gläser · \(log.waterGlasses * 250) ml", "glasses · \(log.waterGlasses * 250) ml"))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(minWidth: 130)
                roundButton("plus") {
                    model.updateDayLog(dayKey) { $0.waterGlasses += 1 }
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.snappy, value: log.waterGlasses)
            Text(model.loc("Ein Glas = 250 ml", "One glass = 250 ml"))
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Theme.card))
        }
        .buttonStyle(.plain)
    }

    // Essen: kurze Einträge mit Uhrzeit.
    private func food(_ log: DailyLog) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TextField(model.loc("Was hast du gegessen?", "What did you eat?"), text: $foodText)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(addFood)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
                Button(action: addFood) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 50, height: 50)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                }
                .buttonStyle(.plain)
                .disabled(foodText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if log.food.isEmpty {
                Text(model.loc("Noch nichts eingetragen.", "Nothing logged yet."))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Panel(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(log.food.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { PanelDivider() }
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 17))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(Fmt.clock(item.time))
                                    .font(.system(size: 15).monospacedDigit())
                                    .foregroundStyle(Theme.textSecondary)
                                Button {
                                    model.updateDayLog(dayKey) { log in log.food.removeAll { $0.id == item.id } }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 14)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    private func addFood() {
        let name = foodText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        model.updateDayLog(dayKey) { $0.food.append(FoodItem(name: name)) }
        foodText = ""
    }

    // Gewicht in kg.
    private func weight(_ log: DailyLog) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0.0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .font(.system(size: 52, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize()
                Text("kg")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            if let kg = parsedWeight {
                Text(String(format: "%.1f lb", kg * 2.20462))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            if log.weightKg != nil {
                Button(model.loc("Eintrag löschen", "Remove entry"), role: .destructive) {
                    model.updateDayLog(dayKey) { $0.weightKg = nil }
                    weightText = ""
                }
                .font(.system(size: 15))
            }
        }
        .onAppear { focused = true }
    }

    private var parsedWeight: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: ".")).flatMap { (20...400).contains($0) ? $0 : nil }
    }

    private func saveWeight() {
        guard let kg = parsedWeight else { return }
        model.updateDayLog(dayKey) { $0.weightKg = kg }
    }

    // Stimmung: fünf Stufen.
    private func mood(_ log: DailyLog) -> some View {
        HStack(spacing: 10) {
            ForEach(Mood.allCases) { mood in
                let active = log.mood == mood
                Button {
                    model.updateDayLog(dayKey) { $0.mood = active ? nil : mood }
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: mood.symbol)
                            .font(.system(size: 24))
                            .frame(height: 28)
                        Text(mood.label(model.language))
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(active ? Color.black : Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(active ? Theme.yellow : Theme.card)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
