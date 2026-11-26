import SwiftUI
import Charts

extension AppModel {
    /// Illness Watch for the selected day.
    var illness: IllnessAssessment? {
        IllnessEngine.assess(records: store.chronological(upTo: selectedDayKey, count: 40))
    }

    func illness(for key: String) -> IllnessAssessment? {
        IllnessEngine.assess(records: store.chronological(upTo: key, count: 40))
    }

    /// Last 14 nights of Illness Watch, oldest first.
    var illnessHistory: [IllnessAssessment] {
        IllnessEngine.history(records: store.chronological(upTo: selectedDayKey, count: 54), days: 14)
            .filter { $0.level != .calibrating }
    }

    /// Other things from the day before that can move the same vitals.
    func illnessContext(for key: String) -> [(symbol: String, text: String)] {
        let dayBefore = DayKey.addDays(key, -1)
        var items: [(String, String)] = []
        let entry = journalEntry(for: dayBefore)
        let reasons: [(String, String)] = [
            ("alcohol", "You logged alcohol. It raises resting heart rate and lowers HRV for a night or two."),
            ("sick", "You logged feeling sick."),
            ("lateMeal", "You ate late. A late meal can raise resting heart rate overnight."),
            ("lateCaffeine", "You had caffeine late, which can raise heart rate and hurt sleep."),
            ("stress", "You logged stress, which can lower HRV."),
            ("travel", "You traveled."),
            ("timeZone", "You changed time zones."),
            ("highAltitude", "You were at high altitude, which raises breathing rate and lowers blood oxygen."),
            ("hotWeather", "You were in hot weather, which can raise skin temperature and heart rate."),
            ("lateNight", "You stayed up late."),
            ("injured", "You logged an injury, which can raise resting heart rate."),
        ]
        for (id, text) in reasons where entry.answer(id) == true {
            let symbol = JournalCatalog.behavior(id)?.symbol ?? "exclamationmark.circle"
            items.append((symbol, text))
        }
        if let strain = strain(for: dayBefore)?.strain, strain >= 14 {
            items.append(("flame", String(format: "The day before had high strain (%.1f). Hard training can push these vitals off for a night.", strain)))
        }
        if let sleep = sleep(for: key), sleep.hasData, sleep.sleptMinutes < 6 * 60 {
            items.append(("bed.double", "You slept only \(Fmt.hm(sleep.sleptMinutes)) h. Short sleep raises resting heart rate and lowers HRV."))
        }
        return items.map { (symbol: $0.0, text: $0.1) }
    }
}

extension IllnessLevel {
    var color: Color {
        switch self {
        case .calibrating: return Theme.textSecondary
        case .normal: return Theme.green
        case .watch: return Theme.yellow
        case .warning: return Theme.red
        }
    }

    var symbol: String {
        switch self {
        case .calibrating: return "hourglass"
        case .normal: return "checkmark.shield"
        case .watch: return "eye"
        case .warning: return "exclamationmark.shield"
        }
    }
}

// MARK: - Karte

/// Summary card for the Health tab.
struct IllnessCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let assessment = model.illness {
            NavigationLink {
                IllnessWatchView()
            } label: {
                Panel(padding: 18) {
                    HStack(spacing: 16) {
                        IllnessGauge(score: assessment.score, level: assessment.level, size: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            CapsLabel(text: "Illness Watch", size: 12)
                            Text(assessment.headline)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            if !assessment.driftingSignals.isEmpty {
                                Text(assessment.driftingSignals.map { $0.kind.shortName }.joined(separator: " · "))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(assessment.level.color)
                            }
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

extension HealthMetricKind {
    var shortName: String {
        switch self {
        case .restingHR: return "RHR"
        case .hrv: return "HRV"
        case .respiratoryRate: return "Resp. rate"
        case .spo2: return "SpO₂"
        case .bodyTemp: return "Skin temp"
        }
    }

    var illnessSymbol: String {
        switch self {
        case .restingHR: return "heart"
        case .hrv: return "waveform.path.ecg"
        case .respiratoryRate: return "lungs"
        case .spo2: return "drop"
        case .bodyTemp: return "thermometer.medium"
        }
    }

    /// Direction that points to illness.
    var illnessDirection: String {
        switch self {
        case .hrv, .spo2: return "Lower"
        default: return "Higher"
        }
    }
}

struct IllnessGauge: View {
    let score: Int
    let level: IllnessLevel
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * CGFloat(max(score, 2)) / 100)
                .stroke(level.color, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(135))
            if level == .calibrating {
                Image(systemName: level.symbol)
                    .font(.system(size: size * 0.26))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("\(score)")
                    .font(.system(size: size * 0.32, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Detail

struct IllnessWatchView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            ScreenBackground()
            if let assessment = model.illness {
                content(assessment)
            }
        }
        .navigationTitle("Illness Watch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func content(_ a: IllnessAssessment) -> some View {
        let context = model.illnessContext(for: model.selectedDayKey)
        let history = model.illnessHistory
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero
                VStack(spacing: 14) {
                    IllnessGauge(score: a.score, level: a.level, size: 150)
                    Label(a.level.title.uppercased(), systemImage: a.level.symbol)
                        .font(.system(size: 14, weight: .bold))
                        .kerning(1.2)
                        .foregroundStyle(a.level.color)
                    Text(a.headline)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(a.detail)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

                if a.level != .calibrating {
                    SectionHeading(text: "Overnight Signals")
                        .padding(.top, 32)
                    Text("Last night compared with your previous 30 nights. Bars show how far each one moved in the direction linked to getting sick.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                    Panel(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(sortedSignals(a).enumerated()), id: \.element.id) { index, signal in
                                if index > 0 { PanelDivider() }
                                IllnessSignalRow(signal: signal)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                    .padding(.top, 14)

                    if history.count > 2 {
                        SectionHeading(text: "Last 14 Nights")
                            .padding(.top, 30)
                        Panel(padding: 18) {
                            IllnessHistoryChart(history: history)
                        }
                        .padding(.top, 14)
                    }

                    supporting
                        .padding(.top, 30)

                    if !context.isEmpty && a.level >= .watch {
                        SectionHeading(text: "Other Possible Causes")
                            .padding(.top, 30)
                        Panel(padding: 18) {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(Array(context.enumerated()), id: \.offset) { _, item in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: item.symbol)
                                            .font(.system(size: 16))
                                            .foregroundStyle(Theme.textSecondary)
                                            .frame(width: 24)
                                        Text(item.text)
                                            .font(.system(size: 15))
                                            .foregroundStyle(Theme.textPrimary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .padding(.top, 14)
                    }

                    SectionHeading(text: "What To Do")
                        .padding(.top, 30)
                    Panel(padding: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(tips(a.level), id: \.self) { tip in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle().fill(a.level.color).frame(width: 6, height: 6).padding(.top, 7)
                                    Text(tip)
                                        .font(.system(size: 15))
                                        .foregroundStyle(Theme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.top, 14)
                }

                howItWorks
                    .padding(.top, 30)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private func sortedSignals(_ a: IllnessAssessment) -> [IllnessSignal] {
        a.signals.sorted { lhs, rhs in
            if lhs.concern * lhs.weight != rhs.concern * rhs.weight { return lhs.concern * lhs.weight > rhs.concern * rhs.weight }
            return lhs.weight > rhs.weight
        }
    }

    private var supporting: some View {
        let key = model.selectedDayKey
        let recovery = model.recovery(for: key)?.score
        let sleep = model.sleep(for: key).flatMap { $0.hasData ? $0.performance : nil }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeading(text: "Also Affected")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                StatTile(label: "Recovery", value: recovery.map { "\($0)" } ?? "–", unit: "%",
                         sub: recovery.map { $0 < 34 ? "Low" : $0 < 67 ? "Moderate" : "Good" },
                         subColor: recovery.map { $0 < 34 ? Theme.red : $0 < 67 ? Theme.yellow : Theme.green } ?? Theme.textSecondary)
                StatTile(label: "Sleep", value: sleep.map { "\(Int($0.rounded()))" } ?? "–", unit: "%", sub: "Performance")
            }
            Text("When your body is fighting something, recovery and sleep performance usually drop too.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tips(_ level: IllnessLevel) -> [String] {
        switch level {
        case .warning:
            return [
                "Make today a rest or light day. Hard training while your body is fighting something can make it worse.",
                "Aim for an extra hour of sleep tonight and go to bed early.",
                "Drink more water than usual and eat regular meals.",
                "If you feel symptoms like a sore throat, fever or cough, rest and talk to a parent or doctor.",
            ]
        case .watch:
            return [
                "Keep training light to moderate until your vitals settle.",
                "Prioritize sleep tonight and skip late meals and caffeine.",
                "Check back tomorrow. One off night is common; two or more in a row matters more.",
            ]
        case .normal:
            return [
                "Nothing unusual. Train as planned.",
                "Good sleep and steady hydration keep your baseline stable.",
            ]
        case .calibrating:
            return []
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(text: "How It Works")
            Text("Pulse compares last night\u{2019}s respiratory rate, skin temperature, resting heart rate, HRV and blood oxygen with your own previous 30 nights, not a general normal range. Respiratory rate counts the most because it barely changes from night to night unless something is going on. Skin temperature counts next.")
            Text("One odd reading only raises a Watch. A warning needs two or more signals off together, or a signal that stays off for more than one night. The score goes from 0 to 100 and rises with how far and how many signals moved.")
            Text("This is not a diagnosis and can\u{2019}t tell you that you are sick. Alcohol, hard training, late meals, travel and short sleep can move the same signals. If you feel unwell, talk to a doctor.")
        }
        .font(.system(size: 14))
        .foregroundStyle(Theme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct IllnessSignalRow: View {
    let signal: IllnessSignal

    private var color: Color {
        if signal.isOut { return Theme.red }
        if signal.isDrifting { return Theme.yellow }
        return Theme.green
    }

    private var statusText: String {
        if signal.baselineMean == nil { return "Learning" }
        if signal.value == nil { return "No data" }
        if signal.isOut { return signal.nightsOff >= 2 ? "Off \(signal.nightsOff) nights" : "Out of range" }
        if signal.isDrifting { return "Drifting" }
        return "Normal"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: signal.kind.illnessSymbol)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(signal.kind.label)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(baselineText)
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(valueText)
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(signal.baselineMean == nil || signal.value == nil ? Theme.textSecondary : color)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    // Out-of-range mark at 1.65 of a 3-spread scale.
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 1.5)
                        .offset(x: geo.size.width * CGFloat(IllnessEngine.outThreshold / 3))
                    Capsule()
                        .fill(color)
                        .frame(width: signal.concern > 0 ? max(6, geo.size.width * CGFloat(min(signal.concern, 3) / 3)) : 0)
                }
            }
            .frame(height: 6)
            .padding(.leading, 42)
        }
        .padding(.vertical, 14)
    }

    private var valueText: String {
        guard let value = signal.value else { return "–" }
        return "\(signal.kind.formatted(value)) \(signal.kind.displayUnit)"
    }

    private var baselineText: String {
        guard let mean = signal.baselineMean else { return "Needs about a week of nights" }
        var text = "Normal \(signal.kind.formatted(mean))"
        if let delta = signal.delta {
            let sign = delta >= 0 ? "+" : "−"
            text += " · \(sign)\(signal.kind.formatted(abs(delta)))"
        }
        return text
    }
}

extension HealthMetricKind {
    var displayUnit: String {
        switch self {
        case .restingHR: return "bpm"
        case .hrv: return "ms"
        case .respiratoryRate: return "rpm"
        case .spo2: return "%"
        case .bodyTemp: return "°C"
        }
    }
}

struct IllnessHistoryChart: View {
    let history: [IllnessAssessment]

    var body: some View {
        Chart(history, id: \.dayKey) { item in
            BarMark(
                x: .value("Night", DayKey.date(from: item.dayKey) ?? Date(), unit: .day),
                y: .value("Score", max(item.score, 2))
            )
            .foregroundStyle(item.level.color)
            .cornerRadius(3)
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 50, 100]) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(height: 150)
    }
}
