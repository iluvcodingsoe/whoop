import SwiftUI
import Charts

// MARK: - Strength Tab

/// Strength Trainer home: start a workout, templates, weekly muscle sets,
/// progress per lift and workout history.
struct StrengthView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [StrengthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ScreenBackground()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            header
                            if model.activeStrength != nil {
                                activeBanner
                                    .padding(.top, 18)
                            }
                            startButton
                                .padding(.top, 20)

                            SectionHeading(text: "Templates")
                                .padding(.top, 32)
                            templates
                                .padding(.top, 14)

                            SectionHeading(text: "This Week")
                                .padding(.top, 32)
                            weekStats
                                .padding(.top, 14)

                            SectionHeading(text: "Muscles")
                                .padding(.top, 32)
                                .id("muscles")
                            muscles
                                .padding(.top, 14)

                            SectionHeading(text: "Progress")
                                .padding(.top, 32)
                                .id("progress")
                            progress
                                .padding(.top, 14)

                            SectionHeading(text: "History")
                                .padding(.top, 32)
                            history
                                .padding(.top, 14)

                            ScreenshotScrollAnchor(proxy: proxy)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-screenshotTemplateEditor") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        model.editingTemplate = model.strengthTemplates.first
                    }
                } else if args.contains("-screenshotStrengthDetail"), let last = model.strengthWorkouts.last {
                    path = [.workout(last.id)]
                } else if args.contains("-screenshotStrengthExercise"), let id = model.recentExercises.first {
                    path = [.exercise(id)]
                }
            }
            .navigationDestination(for: StrengthRoute.self) { route in
                switch route {
                case .workout(let id): StrengthWorkoutDetailView(workoutID: id)
                case .exercise(let id): ExerciseProgressView(exerciseID: id)
                }
            }
        }
    }

    private var header: some View {
        ZStack {
            ScreenTitle(text: "Strength Trainer")
            HStack {
                Spacer()
                DeviceStatus()
            }
        }
        .frame(height: 44)
        .padding(.top, 6)
    }

    // MARK: Start

    private var activeBanner: some View {
        Button {
            model.showStrengthLogger = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.green))
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.activeStrength?.name ?? "Workout")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("In progress · \(ElapsedText.format(model.activeStrength?.start ?? Date()))")
                            .font(.system(size: 14).monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Text("RESUME")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(Theme.green)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.green.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.green.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        Button {
            if model.activeStrength != nil {
                model.showStrengthLogger = true
            } else {
                model.startStrength(template: nil)
            }
        } label: {
            Label("Start Empty Workout", systemImage: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(.plain)
    }

    // MARK: Templates

    private var templates: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button {
                    model.editingTemplate = StrengthTemplate(name: "", entries: [])
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                        Text("Create\nTemplate")
                            .font(.system(size: 15, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(width: 130, height: 196)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
                }
                .buttonStyle(.plain)

                ForEach(model.strengthTemplates) { template in
                    Button {
                        if model.activeStrength == nil {
                            model.startStrength(template: template)
                        } else {
                            model.showStrengthLogger = true
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(template.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text("\(template.entries.count) exercises")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(template.entries.prefix(3)) { entry in
                                    Text(entry.exercise?.name ?? entry.exerciseID)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary.opacity(0.85))
                                        .lineLimit(1)
                                }
                                if template.entries.count > 3 {
                                    Text("+\(template.entries.count - 3) more")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                                }
                            }
                            .padding(.top, 4)
                            Spacer(minLength: 0)
                            HStack {
                                Text("START")
                                    .font(.system(size: 12, weight: .bold))
                                    .kerning(1.2)
                                    .foregroundStyle(Theme.strainBlue)
                                Spacer()
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 32, height: 28)
                                    .contentShape(Rectangle())
                                    .onTapGesture { model.editingTemplate = template }
                            }
                        }
                        .padding(16)
                        .frame(width: 190, height: 196, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            model.editingTemplate = template
                        } label: {
                            Label("Edit template", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            model.deleteTemplate(template.id)
                        } label: {
                            Label("Delete template", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: Woche

    private var weekStats: some View {
        let week = model.strengthWeek()
        let scores = week.map { model.strengthScore($0) }
        let volume = scores.reduce(0) { $0 + $1.volumeKg }
        let sets = scores.reduce(0) { $0 + $1.doneSets }
        let prs = scores.reduce(0) { $0 + $1.personalRecords.count }
        let strains = week.map { model.sessionStrain($0).total }
        let avgStrain = strains.isEmpty ? nil : strains.reduce(0, +) / Double(strains.count)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(label: "Workouts", value: "\(week.count)", sub: "Last 7 days")
            StatTile(label: "Avg Strain", value: avgStrain.map { String(format: "%.1f", $0) } ?? "–", sub: "Per session")
            StatTile(label: "Volume", value: model.volumeText(volume), unit: model.weightUnit, sub: "\(sets) sets")
            StatTile(label: "Records", value: "\(prs)", sub: prs == 1 ? "New best" : "New bests", subColor: prs > 0 ? Theme.green : Theme.textSecondary)
        }
    }

    // MARK: Muskeln

    private var muscles: some View {
        let sets = StrengthEngine.weeklySets(model.strengthWeek())
        return Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CapsLabel(text: "Weekly sets", color: Theme.textSecondary, size: 12)
                    Spacer()
                    Text("Target 10–20")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(Muscle.allCases) { muscle in
                    let value = sets[muscle] ?? 0
                    MuscleSetBar(title: muscle.title, sets: value)
                }
                Text("Primary muscles count a full set, helpers count half. Around 10 to 20 hard sets a week per muscle builds strength.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: Fortschritt

    private var progress: some View {
        let ids = Array(model.recentExercises.prefix(6))
        return Group {
            if ids.isEmpty {
                Panel {
                    Text("Finish a workout to see your estimated max for each lift.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                Panel(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                            if index > 0 { PanelDivider() }
                            NavigationLink(value: StrengthRoute.exercise(id)) {
                                ExerciseProgressRow(exerciseID: id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    // MARK: Verlauf

    private var history: some View {
        let recent = Array(model.strengthWorkouts.reversed().prefix(12))
        return Group {
            if recent.isEmpty {
                Panel {
                    Text("No workouts yet. Start one above or pick a template.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                Panel(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(recent.enumerated()), id: \.element.id) { index, workout in
                            if index > 0 { PanelDivider() }
                            NavigationLink(value: StrengthRoute.workout(workout.id)) {
                                WorkoutHistoryRow(workout: workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }
}

enum StrengthRoute: Hashable {
    case workout(UUID)
    case exercise(String)
}

enum ElapsedText {
    static func format(_ start: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

struct MuscleSetBar: View {
    let title: String
    let sets: Double

    private var color: Color {
        switch sets {
        case ..<0.5: return Color.white.opacity(0.15)
        case ..<10: return Theme.yellow
        case ...20: return Theme.green
        default: return Theme.orange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 96, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    // Target band 10–20 of a 25-set scale.
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: geo.size.width * 0.4)
                        .offset(x: geo.size.width * 0.4)
                    Capsule()
                        .fill(color)
                        .frame(width: max(sets > 0 ? 6 : 0, geo.size.width * CGFloat(min(sets, 25) / 25)))
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            Text(sets.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(sets))" : String(format: "%.1f", sets))
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

struct ExerciseProgressRow: View {
    @Environment(AppModel.self) private var model
    let exerciseID: String

    var body: some View {
        let exercise = ExerciseCatalog.exercise(exerciseID)
        let points = StrengthEngine.progress(for: exerciseID, in: model.strengthWorkouts, bodyweight: model.bodyweightKg)
        let latest = points.last?.value
        let monthAgo = points.last(where: { $0.date < Date().addingTimeInterval(-28 * 86400) })?.value ?? points.first?.value
        let change: Double? = {
            guard let latest, let monthAgo, monthAgo > 0, points.count > 1 else { return nil }
            return (latest - monthAgo) / monthAgo * 100
        }()
        let timed = exercise?.measure == .seconds

        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise?.name ?? exerciseID)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(timed ? "Longest hold" : "Estimated 1-rep max")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            if points.count > 1 {
                Chart(Array(points.enumerated()), id: \.offset) { item in
                    LineMark(x: .value("Date", item.element.date), y: .value("Max", item.element.value))
                        .foregroundStyle(Theme.strainBlue)
                        .interpolationMethod(.monotone)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(width: 70, height: 30)
            }
            VStack(alignment: .trailing, spacing: 2) {
                if let latest {
                    Text(timed ? "\(Int(latest)) s" : "\(model.weightText(latest)) \(model.weightUnit)")
                        .font(.system(size: 17, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                }
                if let change {
                    Text(String(format: "%+.0f%%", change))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(change >= 0 ? Theme.green : Theme.red)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary.opacity(0.6))
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

struct WorkoutHistoryRow: View {
    @Environment(AppModel.self) private var model
    let workout: StrengthWorkout

    var body: some View {
        let score = model.strengthScore(workout)
        HStack(spacing: 14) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.strainBlue)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.strainBlue.opacity(0.15)))
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(workout.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · \(score.doneSets) sets · \(model.volumeText(score.volumeKg)) \(model.weightUnit)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if !score.personalRecords.isEmpty {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.yellow)
            }
            Text(String(format: "%.1f", model.sessionStrain(workout).total))
                .font(.system(size: 18, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.strainBlue)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Workout-Details

struct StrengthWorkoutDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let workoutID: UUID
    @State private var confirmDelete = false
    @State private var namingTemplate = false
    @State private var templateName = ""

    var body: some View {
        ZStack {
            ScreenBackground()
            if let workout = model.strengthWorkout(workoutID) {
                content(workout)
            } else {
                Text("This workout no longer exists.")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func content(_ workout: StrengthWorkout) -> some View {
        let score = model.strengthScore(workout)
        let strain = model.sessionStrain(workout)
        let maxMuscle = score.muscleLoad.values.max() ?? 1
        let muscles = score.muscleLoad.sorted { $0.value > $1.value }

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(workout.name)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(workout.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) · \(Fmt.clock(workout.start)) – \(Fmt.clock(workout.end ?? workout.start)) · \(Int(workout.durationMinutes.rounded())) min")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)

                Panel(padding: 22) {
                    HStack(spacing: 22) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.08), lineWidth: 9)
                            Circle()
                                .trim(from: 0, to: CGFloat(strain.total / 21))
                                .stroke(Theme.strainBlue, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                Text(String(format: "%.1f", strain.total))
                                    .font(.system(size: 30, weight: .bold).monospacedDigit())
                                    .foregroundStyle(Theme.textPrimary)
                                Text("STRAIN")
                                    .font(.system(size: 10, weight: .bold))
                                    .kerning(1.2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .frame(width: 112, height: 112)
                        VStack(alignment: .leading, spacing: 12) {
                            loadLine("Cardio", value: strain.cardio, color: Theme.red)
                            loadLine("Muscular", value: max(0, strain.total - strain.cardio), color: Theme.strainBlue, prefix: "+")
                            Text("Muscular load comes from your sets, reps and weight.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 20)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    StatTile(label: "Volume", value: model.volumeText(score.volumeKg), unit: model.weightUnit)
                    StatTile(label: "Sets", value: "\(score.doneSets)", sub: "\(score.totalReps) reps")
                }
                .padding(.top, 12)

                if !score.personalRecords.isEmpty {
                    Panel(padding: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("New personal bests", systemImage: "trophy.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.yellow)
                            ForEach(score.personalRecords, id: \.self) { id in
                                Text(ExerciseCatalog.exercise(id)?.name ?? id)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                    .padding(.top, 12)
                }

                SectionHeading(text: "Muscles Worked")
                    .padding(.top, 30)
                Panel(padding: 20) {
                    VStack(spacing: 12) {
                        ForEach(Array(muscles.prefix(8)), id: \.key) { item in
                            let muscle = item.key
                            let load = item.value
                            HStack(spacing: 12) {
                                Text(muscle.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 96, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.06))
                                        Capsule()
                                            .fill(Theme.strainBlue)
                                            .frame(width: geo.size.width * CGFloat(load / maxMuscle))
                                    }
                                }
                                .frame(height: 8)
                                Text("\(Int((load / maxMuscle * 100).rounded()))%")
                                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(.top, 14)

                SectionHeading(text: "Exercises")
                    .padding(.top, 30)
                VStack(spacing: 12) {
                    ForEach(workout.entries) { entry in
                        exerciseCard(entry, isPR: score.personalRecords.contains(entry.exerciseID))
                    }
                }
                .padding(.top, 14)

                VStack(spacing: 10) {
                    actionButton("Edit Workout", symbol: "pencil") {
                        model.editStrength(workout)
                    }
                    actionButton("Save as Template", symbol: "square.on.square") {
                        templateName = workout.name
                        namingTemplate = true
                    }
                    actionButton("Delete Workout", symbol: "trash", destructive: true) {
                        confirmDelete = true
                    }
                }
                .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.deleteStrength(workout.id)
                dismiss()
            }
        }
        .alert("Template name", isPresented: $namingTemplate) {
            TextField("Name", text: $templateName)
            Button("Save") {
                let name = templateName.trimmingCharacters(in: .whitespaces)
                model.saveTemplate(from: workout, name: name.isEmpty ? workout.name : name)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func loadLine(_ title: String, value: Double, color: Color, prefix: String = "") -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(prefix + String(format: "%.1f", value))
                .font(.system(size: 17, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func exerciseCard(_ entry: StrengthEntry, isPR: Bool) -> some View {
        let exercise = entry.exercise
        let timed = exercise?.measure == .seconds
        return Panel(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(exercise?.name ?? entry.exerciseID)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if isPR {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.yellow)
                    }
                    Spacer()
                    NavigationLink {
                        ExerciseProgressView(exerciseID: entry.exerciseID)
                    } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 22, alignment: .leading)
                        Text(StrengthFormat.set(set, exercise: exercise, model: model))
                            .font(.system(size: 15).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if !timed, let exercise, let e = StrengthEngine.estimatedMax(set, exercise: exercise, bodyweight: model.bodyweightKg) {
                            Text("1RM \(model.weightText(e))")
                                .font(.system(size: 13).monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func actionButton(_ title: String, symbol: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(destructive ? Theme.red : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

enum StrengthFormat {
    @MainActor
    static func set(_ set: StrengthSet, exercise: Exercise?, model: AppModel) -> String {
        if exercise?.measure == .seconds {
            return set.weightKg > 0 ? "\(model.weightText(set.weightKg)) \(model.weightUnit) × \(set.reps) s" : "\(set.reps) s"
        }
        if (exercise?.bodyweightFraction ?? 0) > 0 && set.weightKg == 0 {
            return "Bodyweight × \(set.reps)"
        }
        let sign = set.weightKg > 0 && (exercise?.bodyweightFraction ?? 0) > 0 ? "+" : ""
        return "\(sign)\(model.weightText(set.weightKg)) \(model.weightUnit) × \(set.reps)"
    }
}

// MARK: - Übungsfortschritt

struct ExerciseProgressView: View {
    @Environment(AppModel.self) private var model
    let exerciseID: String

    var body: some View {
        let exercise = ExerciseCatalog.exercise(exerciseID)
        let timed = exercise?.measure == .seconds
        let points = StrengthEngine.progress(for: exerciseID, in: model.strengthWorkouts, bodyweight: model.bodyweightKg)
        let best = points.max { $0.value < $1.value }
        let sessions = model.strengthWorkouts.reversed().filter { w in w.entries.contains { $0.exerciseID == exerciseID } }

        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(exercise?.name ?? exerciseID)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if let exercise {
                        Text((exercise.primary.map(\.title) + [exercise.equipment.title]).joined(separator: " · "))
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 4)
                    }

                    Panel(padding: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            CapsLabel(text: timed ? "Longest hold" : "Estimated 1-rep max", color: Theme.textSecondary, size: 12)
                            if points.count > 1 {
                                Chart(Array(points.enumerated()), id: \.offset) { item in
                                    let shown = timed ? item.element.value : model.displayWeight(item.element.value)
                                    LineMark(x: .value("Date", item.element.date), y: .value("Max", shown))
                                        .foregroundStyle(Theme.strainBlue)
                                        .interpolationMethod(.monotone)
                                    PointMark(x: .value("Date", item.element.date), y: .value("Max", shown))
                                        .foregroundStyle(Theme.strainBlue)
                                        .symbolSize(30)
                                }
                                .chartYScale(domain: .automatic(includesZero: false))
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .trailing) { _ in
                                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                                        AxisValueLabel().foregroundStyle(Theme.textSecondary)
                                    }
                                }
                                .frame(height: 200)
                            } else {
                                Text("Log this lift in at least two workouts to see a trend.")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 20)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        if let best {
                            StatTile(
                                label: timed ? "Best hold" : "Best 1RM",
                                value: timed ? "\(Int(best.value))" : model.weightText(best.value),
                                unit: timed ? "s" : model.weightUnit,
                                sub: best.date.formatted(.dateTime.month(.abbreviated).day())
                            )
                            StatTile(
                                label: "Best set",
                                value: StrengthFormat.set(best.bestSet, exercise: exercise, model: model)
                            )
                        }
                        StatTile(label: "Sessions", value: "\(sessions.count)")
                        if let next = nextTarget(points: points, exercise: exercise) {
                            StatTile(label: "Next goal", value: next, sub: "Small step up")
                        }
                    }
                    .padding(.top, 12)

                    SectionHeading(text: "History")
                        .padding(.top, 30)
                    VStack(spacing: 12) {
                        ForEach(sessions.prefix(15)) { workout in
                            if let entry = workout.entries.first(where: { $0.exerciseID == exerciseID }) {
                                Panel(padding: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(workout.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                        ForEach(entry.sets) { set in
                                            Text(StrengthFormat.set(set, exercise: exercise, model: model))
                                                .font(.system(size: 14).monospacedDigit())
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    /// Progressive overload hint: one more rep, or a small weight jump once reps reach 10.
    private func nextTarget(points: [(date: Date, value: Double, bestSet: StrengthSet)], exercise: Exercise?) -> String? {
        guard let exercise, let last = model.lastSets(for: exerciseID).max(by: { $0.weightKg < $1.weightKg }) else { return nil }
        if exercise.measure == .seconds { return "\(last.reps + 5) s" }
        if last.reps >= 10 || (last.reps >= 5 && points.count > 2 && last.weightKg > 0) {
            let step = model.usePounds ? 5 / 2.20462 : 2.5
            var next = last
            next.weightKg += step
            return StrengthFormat.set(next, exercise: exercise, model: model)
        }
        var next = last
        next.reps += 1
        return StrengthFormat.set(next, exercise: exercise, model: model)
    }
}
