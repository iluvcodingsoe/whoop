import SwiftUI

// MARK: - Karten

struct SectionCard<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title.uppercased())
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .kerning(1.1)
                    .foregroundStyle(Theme.textSecondary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }
}

// MARK: - Gauges

struct RingGauge<Center: View>: View {
    var progress: Double // 0–1
    var color: Color
    var lineWidth: CGFloat = 16
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.003, min(1, progress))))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center
        }
        .padding(lineWidth / 2)
    }
}

/// 270°-Bogen für die Strain-Skala (0–21). `marker` (0–1) zeichnet einen
/// weißen Ziel-Strich auf den Bogen (wie Whoops Strain Target).
struct ArcGauge<Center: View>: View {
    var fraction: Double // 0–1
    var color: Color
    var lineWidth: CGFloat = 16
    var marker: Double? = nil
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(color.opacity(0.14), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * CGFloat(max(0.004, min(1, fraction))))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
            if let marker {
                GeometryReader { geo in
                    let radius = min(geo.size.width, geo.size.height) / 2
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 3, height: lineWidth + 8)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 - radius)
                        // 12-Uhr-Position → Startpunkt (135°) + Anteil des 270°-Bogens.
                        .rotationEffect(.degrees(Stats.clamp(marker, 0, 1) * 270 - 135))
                }
            }
            center
        }
        .padding(lineWidth / 2)
    }
}

// MARK: - Kleinteile

struct StatCell: View {
    let label: String
    let value: String
    var sub: String? = nil
    var color: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            if let sub {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PillBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.16)))
            .foregroundStyle(color)
    }
}

struct EmptyDataHint: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.title2)
                .foregroundStyle(Theme.textSecondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Tages-Übersicht (3 Ringe)

/// Konzentrische Ringe: außen Recovery, Mitte Schlaf-Performance, innen
/// Strain relativ zum Tagesziel. Einheitliche Skala: „% von dem, was heute
/// für dich richtig ist".
struct TripleRingView: View {
    var recovery: Double?      // 0–1
    var sleep: Double?         // 0–1
    var strainOfTarget: Double? // 0–1 (Strain / Tagesziel, gekappt)
    var recoveryColor: Color
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            ring(recovery, color: recoveryColor, inset: 0)
            ring(sleep, color: Theme.sleepPurple, inset: lineWidth + 3)
            ring(strainOfTarget, color: Theme.strainBlue, inset: 2 * (lineWidth + 3))
        }
        .padding(lineWidth / 2)
    }

    @ViewBuilder
    private func ring(_ value: Double?, color: Color, inset: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(Stats.clamp(value ?? 0, 0.004, 1)))
                .stroke(
                    color.opacity(value == nil ? 0.25 : 1),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .padding(inset)
    }
}

/// Kompakte „Heute"-Übersicht ganz oben im Dashboard (tippbar → große Ringe).
struct TodayOverviewCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let key = model.selectedDayKey
        let recovery = model.recovery(for: key)
        let sleep = model.sleep(for: key)
        let strain = model.strain(for: key)
        let target = recovery.map { StrainEngine.targetStrain(forRecovery: $0.score) }
        let sleepPerf: Double? = (sleep?.hasData == true) ? sleep?.performance : nil

        HStack(spacing: 10) {
            NavigationLink {
                SleepDetailView()
            } label: {
                HeroTile(
                    label: model.loc("Schlaf", "Sleep"),
                    value: sleepPerf.map { "\(Int($0.rounded()))" } ?? "–",
                    unit: sleepPerf == nil ? "" : "%",
                    fraction: (sleepPerf ?? 0) / 100,
                    color: Theme.sleepPurple
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                RecoveryDetailView()
            } label: {
                HeroTile(
                    label: "Recovery",
                    value: recovery.map { "\($0.score)" } ?? "–",
                    unit: recovery == nil ? "" : "%",
                    fraction: recovery.map { Double($0.score) / 100 } ?? 0,
                    color: recovery.map { Theme.recoveryColor(zone: $0.zone) } ?? Theme.textSecondary,
                    emphasized: true
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                StrainDetailView()
            } label: {
                HeroTile(
                    label: "Strain",
                    value: strain.map { String(format: "%.1f", $0.strain) } ?? "–",
                    unit: "",
                    fraction: strain.map { $0.strain / 21 } ?? 0,
                    color: Theme.accent,
                    marker: target.map { $0 / 21 }
                )
            }
            .buttonStyle(.plain)
        }
    }
}

/// One of the three headline tiles at the top of Today.
struct HeroTile: View {
    let label: String
    let value: String
    let unit: String
    let fraction: Double
    let color: Color
    var marker: Double? = nil
    var emphasized: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .kerning(0.8)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            ArcGauge(fraction: fraction, color: color, lineWidth: emphasized ? 9 : 7, marker: marker) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(.system(size: emphasized ? 30 : 24, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .frame(height: emphasized ? 96 : 84)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(emphasized ? Theme.cardElevated : Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(emphasized ? color.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }
}

/// Kleines Helferlein: zip für zwei Optionals.
/// Recovery-Komponenten kommen mit deutschem Label aus der Engine — der
/// stabile key erlaubt die Übersetzung im UI.
func recoveryComponentLabel(_ key: String, fallback: String, _ lang: PulseLanguage) -> String {
    guard lang == .en else { return fallback }
    switch key {
    case "hrv": return "HRV"
    case "rhr": return "Resting HR"
    case "sleep": return "Sleep"
    case "resp": return "Respiration"
    default: return fallback
    }
}

func zip2<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}

// MARK: - Journal

/// One yes/no question with two pill buttons. Tapping the chosen answer again clears it.
struct JournalQuestionRow: View {
    @Environment(AppModel.self) private var model
    let behavior: JournalBehavior
    let dayKey: String

    var body: some View {
        let answer = model.journalEntry(for: dayKey).answer(behavior.id)
        HStack(spacing: 14) {
            Image(systemName: behavior.symbol)
                .font(.system(size: 18))
                .foregroundStyle(answer == nil ? Theme.textSecondary : Theme.textPrimary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(behavior.question)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(behavior.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                pill("No", selected: answer == false) { set(false, current: answer) }
                pill("Yes", selected: answer == true) { set(true, current: answer) }
            }
        }
        .padding(.vertical, 14)
    }

    private func set(_ value: Bool, current: Bool?) {
        model.setJournalAnswer(behavior.id, current == value ? nil : value, on: dayKey)
    }

    private func pill(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text.uppercased())
                .font(.system(size: 13, weight: .bold))
                .kerning(1)
                .foregroundStyle(selected ? Color.black : Theme.textPrimary)
                .frame(width: 52, height: 34)
                .background(Capsule().fill(selected ? Color.white : Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

/// The daily journal: every tracked behavior as a yes/no question, grouped by category.
struct JournalPromptSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let dayKey: String
    @State private var showPicker = false

    var body: some View {
        let progress = model.journalProgress(for: dayKey)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Fmt.dayTitle(dayKey))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Answer for this day. Pulse links your answers to the next morning\u{2019}s recovery.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)

                    JournalProgressBar(answered: progress.answered, total: progress.total)
                        .padding(.top, 18)

                    if model.trackedBehaviors.isEmpty {
                        Text("You are not tracking any behaviors yet.")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 24)
                    }

                    ForEach(JournalCategory.allCases) { category in
                        let items = model.trackedBehaviors.filter { $0.category == category }
                        if !items.isEmpty {
                            SectionHeading(text: category.title)
                                .padding(.top, 28)
                            Panel(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(Array(items.enumerated()), id: \.element.id) { index, behavior in
                                        if index > 0 { PanelDivider() }
                                        JournalQuestionRow(behavior: behavior, dayKey: dayKey)
                                    }
                                }
                                .padding(.horizontal, 18)
                            }
                            .padding(.top, 12)
                        }
                    }

                    Button {
                        showPicker = true
                    } label: {
                        Label("Add or remove behaviors", systemImage: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 28)

                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .bold))
                            .kerning(1.6)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(Color.white))
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPicker) {
                BehaviorPickerSheet()
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }
}

struct JournalProgressBar: View {
    let answered: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CapsLabel(text: "Answered", size: 13)
                Spacer()
                Text("\(answered) of \(total)")
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(answered >= total && total > 0 ? Theme.green : Theme.accent)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(answered) / CGFloat(total) : 0)
                }
            }
            .frame(height: 6)
        }
    }
}

/// Choose which behaviors the journal asks about.
struct BehaviorPickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Tracking \(model.trackedBehaviorIDs.count). Track \(JournalCatalog.recommendedMax) or fewer at a time for clearer results.")
                        .font(.system(size: 14))
                        .foregroundStyle(model.trackedBehaviorIDs.count > JournalCatalog.recommendedMax ? Theme.orange : Theme.textSecondary)
                        .listRowBackground(Color.clear)
                }
                ForEach(JournalCategory.allCases) { category in
                    let items = filtered.filter { $0.category == category }
                    if !items.isEmpty {
                        Section(category.title) {
                            ForEach(items) { behavior in
                                row(behavior)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .searchable(text: $search, prompt: "Search behaviors")
            .navigationTitle("Behaviors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var filtered: [JournalBehavior] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return JournalCatalog.all }
        return JournalCatalog.all.filter {
            $0.title.lowercased().contains(query) || $0.question.lowercased().contains(query)
        }
    }

    private func row(_ behavior: JournalBehavior) -> some View {
        let tracked = model.isTracked(behavior.id)
        return Button {
            model.toggleTracked(behavior.id)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: behavior.symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(behavior.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(behavior.question)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: tracked ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(tracked ? Theme.green : Theme.textSecondary)
            }
        }
        .listRowBackground(Theme.card)
    }
}

// MARK: - Intensitätszonen

struct ZoneBarsView: View {
    let zoneMinutes: [Double]

    var body: some View {
        let maxMinutes = max(zoneMinutes.max() ?? 1, 1)
        VStack(spacing: 8) {
            ForEach(Array(zoneMinutes.enumerated().reversed()), id: \.offset) { index, minutes in
                HStack(spacing: 10) {
                    Text(StrainEngine.zoneLabels(Fmt.language)[index])
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 80, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.cardElevated)
                            Capsule()
                                .fill(zoneColor(index))
                                .frame(width: max(3, geo.size.width * CGFloat(minutes / maxMinutes)))
                        }
                    }
                    .frame(height: 8)
                    Text(minutes >= 1 ? "\(Int(minutes.rounded())) min" : "–")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 52, alignment: .trailing)
                }
            }
        }
    }

    private func zoneColor(_ index: Int) -> Color {
        [Theme.textSecondary, Theme.teal, Theme.green, Theme.yellow, Theme.orange, Theme.red][min(index, 5)]
    }
}

// MARK: - Schlafphasen-Timeline (Hypnogramm)

/// Hypnogramm im „fließenden" Stil: pro Phase eine Zeile mit Label + Dauer,
/// abgerundete Blöcke, verbunden durch dünne Übergangssäulen.
struct StagesTimelineView: View {
    let session: SleepSession

    private let lanes: [SleepStage] = [.awake, .rem, .light, .deep]
    private let rowHeight: CGFloat = 38
    private let blockHeight: CGFloat = 18

    private func laneIndex(_ stage: SleepStage) -> Int {
        lanes.firstIndex(of: stage == .unknown ? .light : stage) ?? 2
    }

    private var sortedStages: [StageSpan] {
        session.stages.sorted { $0.start < $1.start }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // Label-Spalte: Phase + Dauer, je Zeile so hoch wie eine Lane.
                VStack(spacing: 0) {
                    ForEach(lanes, id: \.self) { stage in
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 5) {
                                Circle().fill(Theme.stageColor(stage)).frame(width: 7, height: 7)
                                Text(Theme.stageName(stage))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            Text(durationText(session.minutes(in: stage)))
                                .font(.system(size: 9).monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: rowHeight)
                    }
                }
                .frame(width: 74)

                hypnogram
                    .frame(height: CGFloat(lanes.count) * rowHeight)
            }

            HStack {
                Text(Fmt.clock(session.start))
                Spacer()
                Text(Fmt.clock(midTime))
                Spacer()
                Text(Fmt.clock(session.end))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private var hypnogram: some View {
        Canvas { context, size in
            let total = session.end.timeIntervalSince(session.start)
            guard total > 0, size.width > 0 else { return }

            func xPos(_ date: Date) -> CGFloat {
                CGFloat(date.timeIntervalSince(session.start) / total) * size.width
            }
            func laneCenter(_ i: Int) -> CGFloat {
                CGFloat(i) * rowHeight + rowHeight / 2
            }

            let spans = sortedStages
            let cornerRadius: CGFloat = 5

            // 1. Pill-Tracks je Lane (dezenter Hintergrund).
            for i in lanes.indices {
                let track = CGRect(x: 0, y: laneCenter(i) - blockHeight / 2, width: size.width, height: blockHeight)
                context.fill(Path(roundedRect: track, cornerRadius: blockHeight / 2), with: .color(Theme.cardElevated))
            }

            // 2. Übergangssäulen: EINE einheitliche, dezente Farbe. Sie docken
            //    Kante-an-Kante an und ragen 3 px in die Blöcke, die sie danach
            //    überdecken → nahtloser Anschluss ohne sichtbaren Versatz.
            for i in 0..<max(0, spans.count - 1) {
                let from = laneIndex(spans[i].stage)
                let to = laneIndex(spans[i + 1].stage)
                guard from != to else { continue }
                let x = xPos(spans[i + 1].start)
                let top = min(laneCenter(from), laneCenter(to)) + blockHeight / 2 - 3
                let bottom = max(laneCenter(from), laneCenter(to)) - blockHeight / 2 + 3
                guard bottom > top else { continue }
                let riser = CGRect(x: x - 1.25, y: top, width: 2.5, height: bottom - top)
                context.fill(Path(roundedRect: riser, cornerRadius: 1.25), with: .color(Theme.textSecondary.opacity(0.4)))
            }

            // 3. Blöcke je Phase: FESTER Eckradius → auch kurze Phasen bleiben
            //    saubere Rechtecke (keine Kreise).
            for span in spans {
                let i = laneIndex(span.stage)
                let x0 = xPos(span.start)
                let x1 = xPos(span.end)
                let block = CGRect(x: x0, y: laneCenter(i) - blockHeight / 2,
                                   width: max(6, x1 - x0), height: blockHeight)
                context.fill(Path(roundedRect: block, cornerRadius: cornerRadius),
                             with: .color(Theme.stageColor(span.stage)))
            }
        }
    }

    private var midTime: Date {
        Date(timeIntervalSince1970: (session.start.timeIntervalSince1970 + session.end.timeIntervalSince1970) / 2)
    }

    private func durationText(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m < 60 { return Fmt.language == .de ? "\(m) Min." : "\(m) min" }
        return "\(m / 60) h \(m % 60) min"
    }
}

// MARK: - Phasen-Verteilung

struct StageDistributionView: View {
    let stageMinutes: [SleepStage: Double]

    private var orderedStages: [(SleepStage, Double)] {
        [SleepStage.deep, .rem, .light, .awake].compactMap { stage in
            guard let minutes = stageMinutes[stage], minutes > 0 else { return nil }
            return (stage, minutes)
        }
    }

    var body: some View {
        let total = max(orderedStages.reduce(0) { $0 + $1.1 }, 1)
        VStack(spacing: 12) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(orderedStages, id: \.0) { stage, minutes in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.stageColor(stage))
                            .frame(width: max(2, geo.size.width * CGFloat(minutes / total)))
                    }
                }
            }
            .frame(height: 10)

            VStack(spacing: 6) {
                ForEach(orderedStages, id: \.0) { stage, minutes in
                    HStack {
                        Circle().fill(Theme.stageColor(stage)).frame(width: 8, height: 8)
                        Text(Theme.stageName(stage))
                            .font(.caption)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(Fmt.hm(minutes)) h")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(Int((minutes / total * 100).rounded())) %")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
    }
}
