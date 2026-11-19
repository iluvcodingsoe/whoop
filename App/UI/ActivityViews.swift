import SwiftUI
import UIKit

// MARK: - Aktivitäts-Katalog

/// Eine Sportart zum Erfassen.
struct ActivityKind: Identifiable, Hashable {
    let name: String
    let symbol: String
    var id: String { name }
}

/// Alle Sportarten zum Erfassen, plus die häufigsten oben.
enum ActivityCatalog {
    static let popular = [
        "Running", "Cycling", "Weightlifting", "Walking", "Golf", "Swimming",
        "HIIT", "Yoga", "Functional Fitness", "Hiking/Rucking", "Tennis", "Basketball",
    ]

    private static let raw: [(String, String)] = [
        ("Activity", "figure.mixed.cardio"),
        ("Air Compression", "wind"),
        ("Assault Bike", "figure.indoor.cycle"),
        ("Australian Football", "figure.australian.football"),
        ("Badminton", "figure.badminton"),
        ("Barre", "figure.barre"),
        ("Baseball", "figure.baseball"),
        ("Basketball", "figure.basketball"),
        ("Box Fitness", "figure.boxing"),
        ("Boxing", "figure.boxing"),
        ("Breathwork", "lungs"),
        ("Caddying", "figure.golf"),
        ("Canoeing", "oar.2.crossed"),
        ("Climber", "figure.stair.stepper"),
        ("Coaching", "person.wave.2"),
        ("Commuting", "figure.walk"),
        ("Cricket", "figure.cricket"),
        ("Cross Country Skiing", "figure.skiing.crosscountry"),
        ("CrossFit", "figure.cross.training"),
        ("Cycling", "figure.outdoor.cycle"),
        ("Dance", "figure.dance"),
        ("Diving", "figure.open.water.swim"),
        ("Disc Golf", "figure.disc.sports"),
        ("Duathlon", "figure.run"),
        ("Elliptical", "figure.elliptical"),
        ("Fencing", "figure.fencing"),
        ("Field Hockey", "figure.hockey"),
        ("Football", "figure.american.football"),
        ("Functional Fitness", "figure.strengthtraining.functional"),
        ("Gaming", "gamecontroller"),
        ("Gardening", "leaf"),
        ("Golf", "figure.golf"),
        ("Gymnastics", "figure.gymnastics"),
        ("Handball", "figure.handball"),
        ("HIIT", "figure.highintensity.intervaltraining"),
        ("Hiking/Rucking", "figure.hiking"),
        ("Horseback Riding", "figure.equestrian.sports"),
        ("Hot Tub", "drop"),
        ("Housework", "house"),
        ("Ice Bath", "snowflake"),
        ("Ice Hockey", "figure.hockey"),
        ("Inline Skating", "figure.skating"),
        ("Jiu Jitsu", "figure.martial.arts"),
        ("Jumping Rope", "figure.jumprope"),
        ("Kayaking", "oar.2.crossed"),
        ("Kickboxing", "figure.kickboxing"),
        ("Kite Boarding", "wind"),
        ("Lacrosse", "figure.lacrosse"),
        ("Manual Labor", "hammer"),
        ("Martial Arts", "figure.martial.arts"),
        ("Massage Therapy", "hand.raised"),
        ("Meditation", "figure.mind.and.body"),
        ("Motocross", "bicycle"),
        ("Motor Racing", "car"),
        ("Mountain Biking", "figure.outdoor.cycle"),
        ("Netball", "figure.basketball"),
        ("Obstacle Course Racing", "figure.run"),
        ("Operations - Flying", "airplane"),
        ("Operations - Medical", "cross.case"),
        ("Operations - Tactical", "shield"),
        ("Operations - Water", "water.waves"),
        ("Paddle Tennis", "figure.racquetball"),
        ("Paddleboarding", "figure.surfing"),
        ("Padel", "figure.racquetball"),
        ("Parenting", "figure.and.child.holdinghands"),
        ("Pickleball", "figure.pickleball"),
        ("Pilates", "figure.pilates"),
        ("Powerlifting", "figure.strengthtraining.traditional"),
        ("Rock Climbing", "figure.climbing"),
        ("Rowing", "figure.rower"),
        ("Rugby", "figure.rugby"),
        ("Running", "figure.run"),
        ("Sailing", "sailboat"),
        ("Sauna", "flame"),
        ("Skateboarding", "figure.skateboarding"),
        ("Skiing", "figure.skiing.downhill"),
        ("Snowboarding", "figure.snowboarding"),
        ("Soccer", "figure.soccer"),
        ("Softball", "figure.softball"),
        ("Spin", "figure.indoor.cycle"),
        ("Squash", "figure.squash"),
        ("Stairmaster", "figure.stair.stepper"),
        ("Stretching", "figure.flexibility"),
        ("Surfing", "figure.surfing"),
        ("Swimming", "figure.pool.swim"),
        ("Table Tennis", "figure.table.tennis"),
        ("Tennis", "figure.tennis"),
        ("Track & Field", "figure.track.and.field"),
        ("Triathlon", "figure.open.water.swim"),
        ("Ultimate", "figure.disc.sports"),
        ("Volleyball", "figure.volleyball"),
        ("Wakeboarding", "figure.surfing"),
        ("Walking", "figure.walk"),
        ("Water Polo", "figure.waterpolo"),
        ("Weightlifting", "figure.strengthtraining.traditional"),
        ("Wheelchair Pushing", "figure.roll"),
        ("Wrestling", "figure.wrestling"),
        ("Yard Work", "leaf"),
        ("Yoga", "figure.yoga"),
    ]

    static let all: [ActivityKind] = raw.map { ActivityKind(name: $0.0, symbol: $0.1) }

    static func kind(named name: String) -> ActivityKind? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Symbol für einen Namen; fällt auf ein allgemeines Symbol zurück, falls es fehlt.
    static func symbol(for name: String) -> String {
        let candidate = kind(named: name)?.symbol ?? workoutSymbol(name)
        return UIImage(systemName: candidate) == nil ? "figure.mixed.cardio" : candidate
    }
}

// MARK: - Auswahl der Sportart

/// Was nach der Auswahl passiert.
enum ActivitySheetMode: String, Identifiable {
    case add, start
    var id: String { rawValue }
}

struct ActivityPickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let mode: ActivitySheetMode
    @State private var search = ""

    private var filtered: [ActivityKind] {
        let q = search.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return ActivityCatalog.all }
        return ActivityCatalog.all.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    Section("Popular") {
                        ForEach(ActivityCatalog.popular.compactMap(ActivityCatalog.kind(named:))) { kind in
                            row(kind)
                        }
                    }
                }
                Section(search.isEmpty ? "All activities" : "Results") {
                    ForEach(filtered) { kind in
                        row(kind)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search activities")
            .navigationTitle(mode == .start ? "Start activity" : "Add activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: ActivityKind.self) { kind in
                AddActivityForm(kind: kind) { dismiss() }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func row(_ kind: ActivityKind) -> some View {
        let label = HStack(spacing: 14) {
            Image(systemName: ActivityCatalog.symbol(for: kind.name))
                .font(.system(size: 18))
                .foregroundStyle(Theme.strainBlue)
                .frame(width: 30)
            Text(kind.name)
                .foregroundStyle(Theme.textPrimary)
        }
        switch mode {
        case .start:
            Button {
                model.startActivity(type: kind.name)
                dismiss()
            } label: {
                label
            }
        case .add:
            NavigationLink(value: kind) { label }
        }
    }
}

// MARK: - Aktivität nachtragen oder planen

struct AddActivityForm: View {
    @Environment(AppModel.self) private var model
    let kind: ActivityKind
    let onDone: () -> Void

    @State private var planOnly = false
    @State private var start = Date().addingTimeInterval(-45 * 60)
    @State private var end = Date()

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: ActivityCatalog.symbol(for: kind.name))
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.strainBlue)
                    Text(kind.name)
                        .font(.system(size: 20, weight: .semibold))
                }
                Picker("When", selection: $planOnly) {
                    Text("Already did it").tag(false)
                    Text("Plan for later").tag(true)
                }
                .pickerStyle(.segmented)
            }

            if planOnly {
                Section {
                    Text("It shows as Pending in today\u{2019}s activities. Tap it when you begin to start the timer.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                Section {
                    DatePicker("Start", selection: $start, in: ...Date())
                    DatePicker("End", selection: $end, in: start...Date())
                    LabeledContent("Duration", value: duration)
                } footer: {
                    Text("Pulse works out the strain from your heart rate during this time.")
                }
            }

            Section {
                Button {
                    if planOnly {
                        model.planActivity(type: kind.name, on: DayKey.today())
                    } else {
                        model.addActivity(type: kind.name, start: start, end: end)
                    }
                    onDone()
                } label: {
                    Text(planOnly ? "Add to today" : "Save activity")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(kind.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var duration: String {
        let minutes = max(0, end.timeIntervalSince(start) / 60)
        return minutes < 60 ? "\(Int(minutes)) min" : "\(Fmt.hm(minutes)) h"
    }
}
