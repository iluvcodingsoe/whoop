import SwiftUI
import UIKit

/// Live workout logger: exercises with sets of weight × reps, check off each
/// set, rest timer between sets and a running strain estimate.
struct StrengthLoggerView: View {
    @Environment(AppModel.self) private var model
    @State private var showPicker = false
    @State private var replacing: UUID?
    @State private var confirmCancel = false
    @State private var restEnd: Date?
    @State private var restLength: TimeInterval = 90

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScreenBackground()
                if let workout = model.activeStrength {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            summary(workout)
                            if workout.entries.isEmpty {
                                Text("Add your first exercise to start logging sets.")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.textSecondary)
                                    .padding(.top, 30)
                            }
                            ForEach(workout.entries) { entry in
                                ExerciseLogCard(entry: entry, onSetDone: startRest) {
                                    replacing = entry.id
                                    showPicker = true
                                }
                                .padding(.top, 16)
                            }
                            Button {
                                replacing = nil
                                showPicker = true
                            } label: {
                                Label("Add Exercise", systemImage: "plus")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.strainBlue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(Capsule().fill(Theme.strainBlue.opacity(0.14)))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 22)

                            Button(role: .destructive) {
                                confirmCancel = true
                            } label: {
                                Text("Cancel Workout")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.red)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, restEnd == nil ? 40 : 130)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollIndicators(.hidden)

                    if let restEnd {
                        RestTimerBar(end: restEnd, length: restLength) { delta in
                            self.restEnd = restEnd.addingTimeInterval(delta)
                            restLength = max(15, restLength + delta)
                        } onSkip: {
                            self.restEnd = nil
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.showStrengthLogger = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .principal) {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(ElapsedText.format(model.activeStrength?.start ?? Date(), now: model.activeStrength?.end ?? Date()))
                            .font(.system(size: 17, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hideKeyboard()
                        model.finishActive()
                    } label: {
                        Text("Finish")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Theme.green))
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .sheet(isPresented: $showPicker) {
                ExercisePickerSheet { exerciseID in
                    add(exerciseID)
                }
            }
            .confirmationDialog("Cancel this workout? Logged sets will be lost.", isPresented: $confirmCancel, titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) {
                    model.discardActive()
                }
                Button("Keep Logging", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.textPrimary)
    }

    private func summary(_ workout: StrengthWorkout) -> some View {
        let score = model.strengthScore(workout)
        let strain = model.sessionStrain(workout)
        return VStack(alignment: .leading, spacing: 14) {
            TextField("Workout name", text: Binding(
                get: { model.activeStrength?.name ?? "" },
                set: { name in model.updateActive { $0.name = name } }
            ))
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            .submitLabel(.done)

            HStack(spacing: 10) {
                summaryTile("Strain", String(format: "%.1f", strain.total), color: Theme.strainBlue)
                summaryTile("Sets", "\(score.doneSets)")
                summaryTile("Volume", "\(model.volumeText(score.volumeKg))", unit: model.weightUnit)
            }
        }
        .padding(.top, 8)
    }

    private func summaryTile(_ label: String, _ value: String, unit: String = "", color: Color = Theme.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            CapsLabel(text: label, color: Theme.textSecondary, size: 11)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
    }

    private func startRest() {
        restEnd = Date().addingTimeInterval(restLength)
    }

    private func add(_ exerciseID: String) {
        let last = model.lastSets(for: exerciseID)
        let sets: [StrengthSet] = last.isEmpty
            ? (0..<3).map { _ in StrengthSet(reps: ExerciseCatalog.exercise(exerciseID)?.measure == .seconds ? 30 : 8, weightKg: 0) }
            : last.map { StrengthSet(reps: $0.reps, weightKg: $0.weightKg) }
        model.updateActive { workout in
            if let replacing, let i = workout.entries.firstIndex(where: { $0.id == replacing }) {
                workout.entries[i] = StrengthEntry(exerciseID: exerciseID, sets: sets)
            } else {
                workout.entries.append(StrengthEntry(exerciseID: exerciseID, sets: sets))
            }
        }
        replacing = nil
    }
}

@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// MARK: - Übungskarte

struct ExerciseLogCard: View {
    @Environment(AppModel.self) private var model
    let entry: StrengthEntry
    var onSetDone: () -> Void
    var onReplace: () -> Void

    var body: some View {
        let exercise = entry.exercise
        let previous = model.lastSets(for: entry.exerciseID, before: model.activeStrength?.start ?? Date())
        let timed = exercise?.measure == .seconds
        let usesBodyweight = (exercise?.bodyweightFraction ?? 0) > 0

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise?.name ?? entry.exerciseID)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.strainBlue)
                    if let exercise {
                        Text(exercise.primary.map(\.title).joined(separator: ", "))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Menu {
                    Button {
                        onReplace()
                    } label: {
                        Label("Replace exercise", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button(role: .destructive) {
                        model.updateActive { $0.entries.removeAll { $0.id == entry.id } }
                    } label: {
                        Label("Remove exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }

            HStack(spacing: 8) {
                header("SET").frame(width: 30)
                header("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
                header(usesBodyweight ? "+\(model.weightUnit.uppercased())" : model.weightUnit.uppercased()).frame(width: 70)
                header(timed ? "SEC" : "REPS").frame(width: 58)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36)
            }

            ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                SetLogRow(
                    entryID: entry.id,
                    set: set,
                    number: index + 1,
                    previous: index < previous.count ? StrengthFormat.set(previous[index], exercise: exercise, model: model) : "–",
                    onDone: onSetDone
                )
            }

            Button {
                model.updateActive { workout in
                    guard let i = workout.entries.firstIndex(where: { $0.id == entry.id }) else { return }
                    let last = workout.entries[i].sets.last
                    workout.entries[i].sets.append(StrengthSet(reps: last?.reps ?? 8, weightKg: last?.weightKg ?? 0))
                }
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card.opacity(0.75)))
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// One editable set row. Text fields keep their own text so typing is smooth.
struct SetLogRow: View {
    @Environment(AppModel.self) private var model
    let entryID: UUID
    let set: StrengthSet
    let number: Int
    let previous: String
    var onDone: () -> Void

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var loaded = false

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 30)
            Text(previous)
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            field($weightText, keyboard: .decimalPad)
                .frame(width: 70)
            field($repsText, keyboard: .numberPad)
                .frame(width: 58)
            Button {
                hideKeyboard()
                let nowDone = !set.done
                update { $0.done = nowDone }
                if nowDone {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDone()
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(set.done ? Color.black : Theme.textSecondary)
                    .frame(width: 36, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(set.done ? Theme.green : Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(set.done ? Theme.green.opacity(0.10) : Color.clear))
        .contextMenu {
            Button(role: .destructive) {
                model.updateActive { workout in
                    guard let i = workout.entries.firstIndex(where: { $0.id == entryID }) else { return }
                    workout.entries[i].sets.removeAll { $0.id == set.id }
                }
            } label: {
                Label("Delete set", systemImage: "trash")
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            weightText = set.weightKg == 0 ? "" : model.weightText(set.weightKg)
            repsText = "\(set.reps)"
        }
        .onChange(of: weightText) { _, text in
            guard text != (set.weightKg == 0 ? "" : model.weightText(set.weightKg)) else { return }
            let value = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
            let kg = model.kilograms(fromDisplay: value)
            if abs(kg - set.weightKg) > 0.001 { update { $0.weightKg = kg } }
        }
        .onChange(of: repsText) { _, text in
            let value = Int(text) ?? 0
            if value != set.reps { update { $0.reps = value } }
        }
    }

    private func field(_ text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField("0", text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.system(size: 17, weight: .semibold).monospacedDigit())
            .foregroundStyle(Theme.textPrimary)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.08)))
    }

    private func update(_ change: @escaping (inout StrengthSet) -> Void) {
        model.updateActive { workout in
            guard let i = workout.entries.firstIndex(where: { $0.id == entryID }),
                  let j = workout.entries[i].sets.firstIndex(where: { $0.id == set.id }) else { return }
            change(&workout.entries[i].sets[j])
        }
    }
}

// MARK: - Pausen-Timer

struct RestTimerBar: View {
    let end: Date
    let length: TimeInterval
    var onAdjust: (TimeInterval) -> Void
    var onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = max(0, end.timeIntervalSince(context.date))
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(remaining > 0 ? "Rest" : "Rest done")
                        .font(.system(size: 13, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(Theme.textSecondary)
                    Text(remaining > 0 ? String(format: "%d:%02d", Int(remaining) / 60, Int(remaining) % 60) : "Next set")
                        .font(.system(size: 26, weight: .bold).monospacedDigit())
                        .foregroundStyle(remaining > 0 ? Theme.textPrimary : Theme.green)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(Theme.strainBlue)
                                .frame(width: geo.size.width * CGFloat(length > 0 ? remaining / length : 0))
                        }
                    }
                    .frame(height: 4)
                }
                adjust("−15") { onAdjust(-15) }
                adjust("+15") { onAdjust(15) }
                Button("Skip", action: onSkip)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: 0x1E2226).opacity(0.98)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        }
    }

    private func adjust(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 48, height: 38)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Übungsauswahl

struct ExercisePickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var onPick: (String) -> Void
    @State private var search = ""
    @State private var muscle: Muscle?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip("All", selected: muscle == nil) { muscle = nil }
                            ForEach(Muscle.allCases) { m in
                                chip(m.title, selected: muscle == m) { muscle = m }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
                let recent = model.recentExercises.compactMap(ExerciseCatalog.exercise).filter(matches)
                if !recent.isEmpty && search.isEmpty {
                    Section("Recent") {
                        ForEach(recent.prefix(6)) { row($0) }
                    }
                }
                Section(search.isEmpty && muscle == nil ? "All Exercises" : "Results") {
                    ForEach(ExerciseCatalog.all.filter(matches).sorted { $0.name < $1.name }) { row($0) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func matches(_ exercise: Exercise) -> Bool {
        if let muscle, !(exercise.primary.contains(muscle) || exercise.secondary.contains(muscle)) { return false }
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return query.isEmpty || exercise.name.lowercased().contains(query) || exercise.equipment.title.lowercased().contains(query)
    }

    private func row(_ exercise: Exercise) -> some View {
        Button {
            onPick(exercise.id)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: exercise.symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.strainBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text((exercise.primary.map(\.title) + [exercise.equipment.title]).joined(separator: " · "))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .listRowBackground(Theme.card)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Color.black : Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(selected ? Color.white : Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vorlagen-Editor

/// Build or edit a workout template: name, exercises, and planned sets.
struct TemplateEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var template: StrengthTemplate
    @State private var showPicker = false
    @State private var confirmDelete = false
    private let isNew: Bool

    init(template: StrengthTemplate) {
        _template = State(initialValue: template)
        isNew = template.name.isEmpty && template.entries.isEmpty
    }

    private var canSave: Bool {
        !template.name.trimmingCharacters(in: .whitespaces).isEmpty && !template.entries.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Template name", text: $template.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .submitLabel(.done)
                        Text("Add exercises and the sets you plan to do. Weights fill in from your last session when you start it.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)

                        ForEach($template.entries) { $entry in
                            TemplateExerciseCard(entry: $entry) {
                                template.entries.removeAll { $0.id == entry.id }
                            } onMove: { offset in
                                move(entry.id, by: offset)
                            }
                            .padding(.top, 16)
                        }

                        Button {
                            showPicker = true
                        } label: {
                            Label("Add Exercise", systemImage: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.strainBlue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Capsule().fill(Theme.strainBlue.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 22)

                        if !isNew {
                            Button {
                                confirmDelete = true
                            } label: {
                                Text("Delete Template")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.red)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
            .navigationTitle(isNew ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        hideKeyboard()
                        template.name = template.name.trimmingCharacters(in: .whitespaces)
                        model.saveTemplate(template)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerSheet { id in
                    let timed = ExerciseCatalog.exercise(id)?.measure == .seconds
                    let last = model.lastSets(for: id)
                    let sets = last.isEmpty
                        ? (0..<3).map { _ in StrengthSet(reps: timed ? 30 : 8, weightKg: 0) }
                        : last.map { StrengthSet(reps: $0.reps, weightKg: $0.weightKg) }
                    template.entries.append(StrengthEntry(exerciseID: id, sets: sets))
                }
            }
            .confirmationDialog("Delete this template?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    model.deleteTemplate(template.id)
                    dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.textPrimary)
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let i = template.entries.firstIndex(where: { $0.id == id }) else { return }
        let j = i + offset
        guard template.entries.indices.contains(j) else { return }
        template.entries.swapAt(i, j)
    }
}

struct TemplateExerciseCard: View {
    @Environment(AppModel.self) private var model
    @Binding var entry: StrengthEntry
    var onRemove: () -> Void
    var onMove: (Int) -> Void

    var body: some View {
        let exercise = entry.exercise
        let timed = exercise?.measure == .seconds
        let usesBodyweight = (exercise?.bodyweightFraction ?? 0) > 0

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise?.name ?? entry.exerciseID)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.strainBlue)
                    if let exercise {
                        Text(exercise.primary.map(\.title).joined(separator: ", "))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Menu {
                    Button { onMove(-1) } label: { Label("Move up", systemImage: "arrow.up") }
                    Button { onMove(1) } label: { Label("Move down", systemImage: "arrow.down") }
                    Button(role: .destructive, action: onRemove) { Label("Remove exercise", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }

            HStack(spacing: 8) {
                columnHeader("SET").frame(width: 30)
                Spacer()
                columnHeader(usesBodyweight ? "+\(model.weightUnit.uppercased())" : model.weightUnit.uppercased()).frame(width: 80)
                columnHeader(timed ? "SEC" : "REPS").frame(width: 64)
                Color.clear.frame(width: 30, height: 1)
            }

            ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                TemplateSetRow(number: index + 1, set: set) { updated in
                    if let i = entry.sets.firstIndex(where: { $0.id == set.id }) { entry.sets[i] = updated }
                } onDelete: {
                    entry.sets.removeAll { $0.id == set.id }
                }
            }

            Button {
                let last = entry.sets.last
                entry.sets.append(StrengthSet(reps: last?.reps ?? (timed ? 30 : 8), weightKg: last?.weightKg ?? 0))
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card.opacity(0.75)))
    }

    private func columnHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
    }
}

struct TemplateSetRow: View {
    @Environment(AppModel.self) private var model
    let number: Int
    let set: StrengthSet
    var onChange: (StrengthSet) -> Void
    var onDelete: () -> Void

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var loaded = false

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 30)
            Spacer()
            field($weightText, keyboard: .decimalPad).frame(width: 80)
            field($repsText, keyboard: .numberPad).frame(width: 64)
            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            weightText = set.weightKg == 0 ? "" : model.weightText(set.weightKg)
            repsText = "\(set.reps)"
        }
        .onChange(of: weightText) { _, text in
            guard text != (set.weightKg == 0 ? "" : model.weightText(set.weightKg)) else { return }
            var updated = set
            updated.weightKg = model.kilograms(fromDisplay: Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0)
            onChange(updated)
        }
        .onChange(of: repsText) { _, text in
            let value = Int(text) ?? 0
            guard value != set.reps else { return }
            var updated = set
            updated.reps = value
            onChange(updated)
        }
    }

    private func field(_ text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField("0", text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.system(size: 17, weight: .semibold).monospacedDigit())
            .foregroundStyle(Theme.textPrimary)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.08)))
    }
}
