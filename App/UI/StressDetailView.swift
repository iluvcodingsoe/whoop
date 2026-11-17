import SwiftUI
import Charts

/// Stress-Monitor: Verlauf des Tages (0–3) und Zeit je Stufe.
struct StressDetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let key = model.selectedDayKey
        let stress = model.stress(for: key)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let stress, let latest = stress.latest {
                    let level = StressLevel(score: latest.value)
                    Panel {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                CapsLabel(text: model.loc("Aktuell", "Latest"), color: Theme.textSecondary)
                                Spacer()
                                Text(Fmt.clock(latest.t))
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(String(format: "%.1f", latest.value))
                                    .font(.system(size: 52, weight: .bold).monospacedDigit())
                                    .foregroundStyle(Theme.textPrimary)
                                Text("/ 3")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            PillBadge(text: level.label(model.language).uppercased(), color: HomeView.stressColor(level))
                        }
                    }

                    Panel {
                        VStack(alignment: .leading, spacing: 14) {
                            CapsLabel(text: model.loc("Tagesverlauf", "Today"), color: Theme.textSecondary)
                            Chart {
                                RuleMark(y: .value("Medium", 1))
                                    .foregroundStyle(Theme.yellow.opacity(0.35))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                RuleMark(y: .value("High", 2))
                                    .foregroundStyle(Theme.orange.opacity(0.35))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                ForEach(stress.points, id: \.t) { point in
                                    LineMark(x: .value("Time", point.t), y: .value("Stress", point.value))
                                        .interpolationMethod(.monotone)
                                        .foregroundStyle(HomeView.stressColor(.low))
                                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                                }
                            }
                            .chartYScale(domain: 0...3)
                            .chartYAxis {
                                AxisMarks(values: [0, 1, 2, 3]) { value in
                                    AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                                    AxisValueLabel().foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                    AxisValueLabel(format: .dateTime.hour()).foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .frame(height: 190)
                        }
                    }

                    Panel(padding: 0) {
                        VStack(spacing: 0) {
                            levelRow(.high, minutes: stress.minutesHigh)
                            PanelDivider()
                            levelRow(.medium, minutes: stress.minutesMedium)
                            PanelDivider()
                            levelRow(.low, minutes: stress.minutesLow)
                        }
                        .padding(.horizontal, 20)
                    }
                } else {
                    EmptyDataHint(text: model.loc("Für diesen Tag gibt es keine Herzfrequenz-Daten im Tagesverlauf.", "No daytime heart rate data for this day."))
                        .padding(.top, 40)
                }

                Text(model.loc(
                    "Stress (0–3) zeigt, wie weit dein Puls im Wachzustand über deinem Ruhepuls liegt. Schlaf und Workouts zählen nicht mit. Kein medizinischer Messwert.",
                    "Stress (0–3) shows how far your awake heart rate sits above your resting heart rate. Sleep and workouts don\u{2019}t count. Not a medical measurement."
                ))
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(ScreenBackground())
        .navigationTitle("Stress monitor")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func levelRow(_ level: StressLevel, minutes: Double) -> some View {
        HStack {
            Circle().fill(HomeView.stressColor(level)).frame(width: 10, height: 10)
            Text(level.label(model.language))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(Fmt.hm(minutes) + " h")
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 16)
    }
}
