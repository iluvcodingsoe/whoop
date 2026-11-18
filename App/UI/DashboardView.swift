import SwiftUI

/// Startseite: Kopfleiste, drei Ringe, Coach-Karte, Health- und Stress-Monitor, "My Day".
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var logSheet: LogKind?
    /// Nur für CI-Screenshots: öffnet direkt eine Unterseite.
    @State private var screenshotPage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                if model.hasData {
                    content
                } else {
                    VStack(spacing: 0) {
                        topBar
                            .padding(.horizontal, 20)
                        Spacer()
                        EmptyDataHint(text: model.isConnected
                            ? model.loc("Noch keine Daten – tippe oben rechts auf das Armband zum Synchronisieren.", "No data yet – tap the band in the top right to sync.")
                            : model.loc("Keine Daten vorhanden. Verbinde Google Health oder starte den Demo-Modus unter „Mehr“.", "No data. Connect Google Health or start demo mode under More."))
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $logSheet) { kind in
                LogSheet(kind: kind, dayKey: model.selectedDayKey)
            }
            .navigationDestination(item: $screenshotPage) { page in
                switch page {
                case "stress": StressDetailView()
                case "review": DayReviewView()
                case "sleep": SleepDetailView()
                case "recovery": RecoveryDetailView()
                case "strain": StrainDetailView()
                case "widget": WidgetPreviewPage()
                default: VitalDetailView(kind: .hrv)
                }
            }
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-screenshotPage"), i + 1 < args.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { screenshotPage = args[i + 1] }
                }
            }
        }
    }

    private var content: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                topBar

                Text("PULSE")
                    .font(.system(size: 34, weight: .medium))
                    .kerning(7)
                    .foregroundStyle(Theme.textPrimary.opacity(0.72))
                    .padding(.top, 26)

                rings
                    .padding(.top, 22)

                if model.syncing {
                    syncBanner.padding(.top, 20)
                }
                if let error = model.lastError, !model.syncing {
                    errorBanner(error).padding(.top, 20)
                }

                CoachCard()
                    .padding(.top, 30)

                HStack(spacing: 14) {
                    healthTile
                    stressTile
                }
                .padding(.top, 22)

                myDay
                    .id("myday")
                    .padding(.top, 34)

                footer
                    .padding(.top, 18)
                ScreenshotScrollAnchor(proxy: proxy)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            if model.isConnected {
                await model.syncNow()
            }
        }
        }
    }

    // MARK: - Kopfleiste

    private var topBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: -6) {
                Button {
                    model.selectedTab = .more
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Theme.textPrimary)
                        .background(Circle().fill(Theme.bgTop))
                }
                .buttonStyle(.plain)
                .zIndex(1)

                if model.streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(
                                LinearGradient(colors: [Theme.yellow, Theme.orange, Theme.red], startPoint: .top, endPoint: .bottom)
                            )
                        Text("\(model.streakDays)")
                            .font(.system(size: 15, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 10)
                    .frame(height: 30)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DayStepper()
                .fixedSize()

            DeviceStatus()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.top, 6)
    }

    // MARK: - Ringe

    private var rings: some View {
        let key = model.selectedDayKey
        let recovery = model.recovery(for: key)
        let sleep = model.sleep(for: key)
        let strain = model.strain(for: key)
        let target = recovery.map { StrainEngine.targetStrain(forRecovery: $0.score) }
        let sleepPerf: Double? = (sleep?.hasData == true) ? sleep?.performance : nil

        return HStack(alignment: .top, spacing: 20) {
            NavigationLink {
                SleepDetailView()
            } label: {
                ScoreRing(
                    value: sleepPerf.map { "\(Int($0.rounded()))" } ?? "–",
                    unit: sleepPerf == nil ? "" : "%",
                    fraction: (sleepPerf ?? 0) / 100,
                    color: Theme.sleepPurple,
                    label: model.loc("Schlaf", "Sleep")
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                RecoveryDetailView()
            } label: {
                ScoreRing(
                    value: recovery.map { "\($0.score)" } ?? "–",
                    unit: recovery == nil ? "" : "%",
                    fraction: recovery.map { Double($0.score) / 100 } ?? 0,
                    color: recovery.map { Theme.recoveryColor(zone: $0.zone) } ?? Theme.textSecondary,
                    label: "Recovery"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                StrainDetailView()
            } label: {
                ScoreRing(
                    value: strain.map { String(format: "%.1f", $0.strain) } ?? "–",
                    unit: "",
                    fraction: strain.map { $0.strain / 21 } ?? 0,
                    color: Theme.strainBlue,
                    marker: target.map { $0 / 21 },
                    label: "Strain"
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .id(key)
    }

    // MARK: - Monitore

    private var healthTile: some View {
        let measured = model.healthStatuses.filter { $0.state != .noData }
        let calibrating = !measured.isEmpty && measured.allSatisfy { $0.state == .calibrating }
        let inRange = measured.filter { $0.state == .inRange || $0.state == .calibrating }.count
        let ok = inRange == measured.count
        let color: Color = measured.isEmpty || calibrating ? Theme.textSecondary : (ok ? Theme.green : Theme.orange)
        let status: String = {
            if measured.isEmpty { return model.loc("Keine Daten", "No data") }
            if calibrating { return model.loc("Kalibriert", "Calibrating") }
            return ok ? model.loc("Im Bereich", "Within range") : model.loc("Auffällig", "Out of range")
        }()

        return Button {
            model.selectedTab = .health
        } label: {
            MonitorTile(
                title: "Health monitor",
                status: status,
                statusColor: color,
                detail: measured.isEmpty ? "–" : model.loc("\(inRange)/\(measured.count) im Bereich", "\(inRange)/\(measured.count) within range")
            ) {
                TintedSquare(color: color) {
                    Image(systemName: ok || measured.isEmpty ? "checkmark" : "exclamationmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(color)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var stressTile: some View {
        let stress = model.stress(for: model.selectedDayKey)
        let latest = stress?.latest
        let level = latest.map { StressLevel(score: $0.value) }
        let color = level.map(Self.stressColor) ?? Theme.textSecondary

        return NavigationLink {
            StressDetailView()
        } label: {
            MonitorTile(
                title: "Stress monitor",
                status: level?.label(model.language) ?? model.loc("Keine Daten", "No data"),
                statusColor: color,
                detail: latest.map { Fmt.clock($0.t) } ?? "–"
            ) {
                TintedSquare(color: color) {
                    Text(latest.map { String(format: "%.1f", $0.value) } ?? "–")
                        .font(.system(size: 19, weight: .bold).monospacedDigit())
                        .foregroundStyle(color)
                }
            }
        }
        .buttonStyle(.plain)
    }

    static func stressColor(_ level: StressLevel) -> Color {
        switch level {
        case .low: return Color(hex: 0x5AA9F2)
        case .medium: return Theme.yellow
        case .high: return Theme.orange
        }
    }

    // MARK: - My Day

    private var myDay: some View {
        VStack(spacing: 16) {
            HStack {
                Text("My Day")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Menu {
                    Button {
                        model.journalPromptDay = model.selectedDayKey
                    } label: {
                        Label("Check-in", systemImage: "checkmark.circle")
                    }
                    ForEach(LogKind.allCases) { kind in
                        Button {
                            logSheet = kind
                        } label: {
                            Label(kind.title(model), systemImage: kind.symbol)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.black)
                        .frame(width: 50, height: 50)
                        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white))
                }
            }

            ActivitiesCard()

            TonightSleepCard()

            NavigationLink {
                DayReviewView()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "moon")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Theme.textPrimary.opacity(0.75))
                    Text(model.loc("Dein Tag im Rückblick", "Your day in review"))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, 22)
                .frame(height: 68)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(hex: 0x33335A), Color(hex: 0x2D3A50)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            dayRows
        }
    }

    private var dayRows: some View {
        let key = model.selectedDayKey
        let record = model.record(for: key)
        let age = model.ageResult(for: key)

        return Panel(padding: 0) {
            VStack(spacing: 0) {
                NavigationLink {
                    StrainDetailView()
                } label: {
                    MetricRow(
                        symbol: "shoeprints.fill",
                        title: model.loc("Schritte", "Steps"),
                        subtitle: model.loc("Ziel 8.000", "Goal 8,000"),
                        value: record?.steps.map { $0.formatted(.number.grouping(.automatic)) } ?? "–",
                        unit: ""
                    )
                }
                .buttonStyle(.plain)
                PanelDivider()
                NavigationLink {
                    AgeDetailView()
                } label: {
                    MetricRow(
                        symbol: "hourglass",
                        title: "Pulse Age",
                        subtitle: age?.deltaYears.map { DashboardView.deltaText($0) } ?? model.loc("Wird kalibriert", "Calibrating"),
                        value: age?.pulseAge.map { "\(Int($0.rounded()))" } ?? "–",
                        unit: model.loc("Jahre", "yrs")
                    )
                }
                .buttonStyle(.plain)
                PanelDivider()
                NavigationLink {
                    TrendsView(embedded: true)
                } label: {
                    MetricRow(
                        symbol: "chart.xyaxis.line",
                        title: "Trends",
                        subtitle: model.loc("7, 30 und 90 Tage", "7, 30 and 90 days"),
                        value: "",
                        unit: ""
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Banner

    private var syncBanner: some View {
        Panel(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ProgressView()
                    Text(model.syncMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                ProgressView(value: model.syncFraction)
                    .tint(Theme.accent)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Panel(padding: 16) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.yellow)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    model.lastError = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var footer: some View {
        Group {
            if let lastSync = model.lastSyncAt {
                Text(model.loc("Letzter Sync: \(Fmt.relative(lastSync))", "Last sync: \(Fmt.relative(lastSync))"))
            } else if model.demoMode {
                Text(model.loc("Demo-Modus – generierte Beispieldaten", "Demo mode – generated sample data"))
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.textSecondary)
    }
}

// MARK: - Coach-Karte

/// Ein Hinweis des Coaches.
struct CoachTip: Identifiable {
    let id: String
    let title: String
    let message: String
}

/// Gestapelte Karte mit Tageshinweisen. Der Zähler rechts blättert weiter.
struct CoachCard: View {
    @Environment(AppModel.self) private var model
    @State private var index = 0

    private var tips: [CoachTip] {
        let key = model.selectedDayKey
        var result: [CoachTip] = []
        let recovery = model.recovery(for: key)
        let strain = model.strain(for: key)?.strain ?? 0
        let isToday = key == DayKey.today()

        if let recovery {
            let target = StrainEngine.targetStrain(forRecovery: recovery.score)
            let t = String(format: "%.1f", target)
            if strain >= target {
                result.append(CoachTip(
                    id: "strain",
                    title: model.loc("Ziel übertroffen", "Past your target"),
                    message: isToday
                        ? model.loc("Du hast dein Tagesziel überschritten. Setze heute Nacht auf Schlaf, um dich zu erholen.", "You are past today\u{2019}s target. Prioritise sleep tonight to recover.")
                        : model.loc("Du lagst über deinem Ziel von \(t).", "You went past your target of \(t) that day.")
                ))
            } else if target - strain <= 2 {
                result.append(CoachTip(
                    id: "strain",
                    title: model.loc("Fast am Ziel", "Almost at your target"),
                    message: model.loc("Noch \(String(format: "%.1f", target - strain)) bis zu deinem Ziel von \(t). Eine kurze Einheit reicht.", "You\u{2019}re \(String(format: "%.1f", target - strain)) away from today\u{2019}s target of \(t). A short session gets you there.")
                ))
            } else if !isToday {
                result.append(CoachTip(id: "strain", title: model.loc("Unter dem Ziel", "Below your target"),
                    message: model.loc("Du lagst bei \(String(format: "%.1f", strain)) von \(t). Eine ruhigere Belastung passt zu deiner Recovery.", "You reached \(String(format: "%.1f", strain)) of your \(t) target that day.")))
            } else {
                switch recovery.zone {
                case .green:
                    result.append(CoachTip(id: "strain", title: model.loc("Bereit für mehr", "Ready to perform"),
                        message: model.loc("Deine Recovery ist hoch. Peile heute einen Strain von \(t) an.", "Your recovery is high. Aim for a strain of \(t) today.")))
                case .yellow:
                    result.append(CoachTip(id: "strain", title: model.loc("Halten", "Maintain"),
                        message: model.loc("Du bist teilweise erholt. Moderate Belastung bis \(t) ist ideal.", "You\u{2019}re partly recovered. Moderate effort up to \(t) is ideal.")))
                case .red:
                    result.append(CoachTip(id: "strain", title: model.loc("Ruhig angehen", "Take it easy"),
                        message: model.loc("Deine Recovery ist niedrig. Bleib unter \(t) und gönn dir Ruhe.", "Your recovery is low. Stay under \(t) and give your body rest.")))
                }
            }
        } else {
            result.append(CoachTip(id: "calibrating", title: model.loc("Kalibrierung", "Calibrating"),
                message: model.loc("Trage dein Armband ein paar Nächte, dann gibt es hier Tipps.", "Wear your band for a few nights and tips will show up here.")))
        }

        if isToday, let bed = model.bedtimeTonight?.recommendedBedtimeMinutes {
            result.append(CoachTip(id: "bed", title: model.loc("Schlafenszeit", "Bedtime"),
                message: model.loc("Geh heute bis \(Fmt.clockFromMinutes(bed)) ins Bett, um deinen Schlafbedarf zu decken.", "Be in bed by \(Fmt.clockFromMinutes(bed)) tonight to cover your sleep need.")))
        }
        if let alert = model.healthAlert {
            result.append(CoachTip(id: "health", title: model.loc("Gesundheits-Hinweis", "Health notice"), message: alert.message))
        }
        if let sleep = model.sleep(for: key), sleep.hasData, sleep.debtAfterMinutes > 30 {
            result.append(CoachTip(id: "debt", title: model.loc("Schlafschuld", "Sleep debt"),
                message: model.loc("Dir fehlen \(Fmt.hm(sleep.debtAfterMinutes)) h Schlaf. Eine frühere Nacht hilft.", "You\u{2019}re carrying \(Fmt.hm(sleep.debtAfterMinutes)) h of sleep debt. An earlier night helps.")))
        }
        return result
    }

    var body: some View {
        let tips = tips
        let current = tips.isEmpty ? nil : tips[index % tips.count]

        ZStack(alignment: .bottom) {
            if tips.count > 1 {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Theme.card.opacity(0.55))
                    .padding(.horizontal, 22)
                    .offset(y: 12)
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(current?.title ?? "")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(current?.message ?? "")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.textPrimary.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(current?.id)
                .transition(.opacity)

                if tips.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { index += 1 }
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                            Text("\(tips.count - index % tips.count)")
                                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                        }
                        .foregroundStyle(Theme.textPrimary.opacity(0.85))
                        .frame(width: 36)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 26)
            .padding(.trailing, 14)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .padding(.bottom, tips.count > 1 ? 12 : 0)
        .onChange(of: model.selectedDayKey) { _, _ in index = 0 }
    }
}

// MARK: - Tagesrückblick

struct DayReviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let key = model.selectedDayKey
        let recovery = model.recovery(for: key)
        let sleep = model.sleep(for: key)
        let strain = model.strain(for: key)
        let stress = model.stress(for: key)
        let log = model.dayLog(for: key)
        let entry = model.journalEntry(for: key)
        let record = model.record(for: key)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(Fmt.dayTitle(key))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Panel(padding: 0) {
                    VStack(spacing: 0) {
                        reviewRow("bolt.heart", "Recovery", recovery.map { "\($0.score)" } ?? "–", "%")
                        PanelDivider()
                        reviewRow("moon.zzz", model.loc("Schlaf", "Sleep"),
                                  (sleep?.hasData == true) ? Fmt.hm(sleep!.sleptMinutes) : "–", "h")
                        PanelDivider()
                        reviewRow("flame", "Strain", strain.map { String(format: "%.1f", $0.strain) } ?? "–", "")
                        PanelDivider()
                        reviewRow("waveform.path", model.loc("Ø Stress", "Avg stress"), stress?.average.map { String(format: "%.1f", $0) } ?? "–", "/ 3")
                        PanelDivider()
                        reviewRow("shoeprints.fill", model.loc("Schritte", "Steps"), record?.steps.map { $0.formatted(.number) } ?? "–", "")
                    }
                    .padding(.horizontal, 20)
                }

                SectionHeading(text: "Log")
                Panel(padding: 0) {
                    VStack(spacing: 0) {
                        reviewRow("drop", model.loc("Wasser", "Water"), "\(log.waterGlasses)", model.loc("Gläser", "glasses"))
                        PanelDivider()
                        reviewRow("fork.knife", model.loc("Essen", "Food"), "\(log.food.count)", model.loc("Einträge", "entries"))
                        PanelDivider()
                        reviewRow("face.smiling", model.loc("Stimmung", "Mood"), log.mood?.label(model.language) ?? "–", "")
                    }
                    .padding(.horizontal, 20)
                }

                if !entry.factors.isEmpty {
                    SectionHeading(text: "Check-in")
                    FlowTags(tags: entry.factors.sorted { $0.rawValue < $1.rawValue }.map { ($0.symbol, $0.label(model.language)) })
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(ScreenBackground())
        .navigationTitle(model.loc("Rückblick", "Review"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reviewRow(_ symbol: String, _ title: String, _ value: String, _ unit: String) -> some View {
        MetricRow(symbol: symbol, title: title, subtitle: "", value: value, unit: unit, showChevron: false)
    }
}

/// Einfache Tag-Liste (Icon + Text) in Zeilen.
struct FlowTags: View {
    let tags: [(String, String)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(tags, id: \.1) { symbol, text in
                Label(text, systemImage: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
            }
        }
    }
}

// MARK: - Hilfen für Pulse Age (auch von AgeDetailView genutzt)

enum DashboardView {
    static func deltaText(_ delta: Double) -> String {
        let rounded = Int(abs(delta).rounded())
        if Fmt.language == .de {
            if rounded == 0 { return "Genau in deinem Alter" }
            let unit = rounded == 1 ? "Jahr" : "Jahre"
            return delta < 0 ? "\(rounded) \(unit) jünger" : "\(rounded) \(unit) älter"
        }
        if rounded == 0 { return "Exactly your age" }
        let unit = rounded == 1 ? "year" : "years"
        return delta < 0 ? "\(rounded) \(unit) younger" : "\(rounded) \(unit) older"
    }

    static func deltaColor(_ delta: Double) -> Color {
        if delta <= -1 { return Theme.green }
        if delta >= 1 { return Theme.orange }
        return Theme.textSecondary
    }
}

// MARK: - Aktivitäten (My Day)

/// Liste der Aktivitäten des Tages: Schlaf und Workouts mit Startzeit und Ende.
struct ActivitiesCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let record = model.selectedRecord
        let sleep = record?.mainSleep
        let workouts = (record?.workouts ?? []).sorted { $0.start < $1.start }

        VStack(alignment: .leading, spacing: 10) {
            CapsLabel(text: "Activities", size: 13)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)

            if let sleep {
                NavigationLink {
                    SleepDetailView()
                } label: {
                    row(
                        pillColor: Theme.sleepPurple,
                        symbol: "moon.fill",
                        pillText: Fmt.hm(sleep.minutesAsleep),
                        name: "Sleep",
                        start: sleep.start,
                        end: sleep.end,
                        showDay: !Calendar.current.isDate(sleep.start, inSameDayAs: sleep.end)
                    )
                }
                .buttonStyle(.plain)
            }
            ForEach(workouts, id: \.id) { workout in
                NavigationLink {
                    StrainDetailView()
                } label: {
                    row(
                        pillColor: Theme.strainBlue,
                        symbol: workoutSymbol(workout.name),
                        pillText: workout.strain.map { String(format: "%.1f", $0) } ?? "–",
                        name: workout.name,
                        start: workout.start,
                        end: workout.end,
                        showDay: false
                    )
                }
                .buttonStyle(.plain)
            }
            if sleep == nil && workouts.isEmpty {
                Text("No activities recorded yet.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
    }

    private func row(pillColor: Color, symbol: String, pillText: String, name: String, start: Date, end: Date, showDay: Bool) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(pillText)
                    .font(.system(size: 19, weight: .bold).monospacedDigit())
            }
            .foregroundStyle(Color.white)
            .frame(width: 96, height: 46)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(pillColor))

            Text(name.uppercased())
                .font(.system(size: 14, weight: .bold))
                .kerning(1)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text((showDay ? "[\(start.formatted(.dateTime.weekday(.abbreviated)))] " : "") + Fmt.clock(start))
                Text(Fmt.clock(end))
            }
            .font(.system(size: 13).monospacedDigit())
            .foregroundStyle(Theme.textSecondary)

            Capsule()
                .fill(pillColor)
                .frame(width: 3, height: 32)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.cardElevated.opacity(0.6)))
    }
}

// MARK: - Schlafplan für heute Nacht (My Day)

/// Empfohlene Bettzeit und Aufstehzeit für heute Nacht.
struct TonightSleepCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let plan = model.bedtimeTonight

        NavigationLink {
            SleepDetailView()
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    CapsLabel(text: "Tonight\u{2019}s sleep", size: 13)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }

                if let plan, let bed = plan.recommendedBedtimeMinutes {
                    HStack(alignment: .center, spacing: 0) {
                        timeBlock(symbol: "sunset", time: Fmt.clockFromMinutes(bed), label: "Recommended\nbedtime", color: Theme.sleepPurple)
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 1)
                            .overlay(
                                Line()
                                    .stroke(Theme.textSecondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 26)
                        timeBlock(symbol: "alarm", time: plan.habitualWakeMinutes.map { Fmt.clockFromMinutes($0) } ?? "–", label: "Wake-up\ntime", color: Theme.yellow)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "bed.double")
                            .font(.system(size: 13))
                        Text("Sleep need \(Fmt.hm(plan.projectedNeedMinutes)) h" + (plan.debtMinutes > 15 ? " · includes \(Fmt.hm(plan.debtMinutes)) h of sleep debt" : ""))
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("Wear your band for a few nights to get a bedtime recommendation.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
        }
        .buttonStyle(.plain)
    }

    private func timeBlock(symbol: String, time: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(color)
                Text(time)
                    .font(.system(size: 30, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize()
            }
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize()
        }
    }
}

/// Waagerechte Linie für die gestrichelte Verbindung.
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - Widget-Vorschau (nur für CI-Screenshots)

struct WidgetPreviewPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let key = model.selectedDayKey
        let recovery = model.recovery(for: key)
        let zone: String = {
            switch recovery?.zone {
            case .green: return "green"
            case .yellow: return "yellow"
            case .red: return "red"
            case nil: return "none"
            }
        }()
        let sleep = model.sleep(for: key)
        let entry = PulseEntry(
            date: Date(),
            score: recovery?.score,
            zone: zone,
            sleepPerformance: (sleep?.hasData == true) ? sleep?.performance : nil,
            strain: model.strain(for: key)?.strain,
            strainTarget: recovery.map { StrainEngine.targetStrain(forRecovery: $0.score) }
        )
        ZStack {
            Color(red: 0.62, green: 0.85, blue: 0.86).ignoresSafeArea()
            ScoresWidgetView(entry: entry)
                .padding(16)
                .frame(width: 364, height: 170)
                .background(Color(red: 0.133, green: 0.153, blue: 0.176))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
