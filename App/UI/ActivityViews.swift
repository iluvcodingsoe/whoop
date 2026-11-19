import SwiftUI
import UIKit

// MARK: - Aktivitäts-Katalog

/// Eine Sportart zum Erfassen.
struct ActivityKind: Identifiable, Hashable {
    enum Section: String { case activity, recovery, sleep }
    let name: String
    let symbol: String
    var section: Section = .activity
    /// Zählt zur Kraft-Aktivitätszeit (Strength activity time).
    var countsAsStrength = false
    var id: String { name }
}

/// Alle Aktivitäten zum Erfassen, plus die häufigsten oben.
enum ActivityCatalog {
    static let popular = [
        "Running", "Cycling", "Weightlifting", "Walking", "Golf", "Swimming",
        "HIIT", "Yoga", "Functional Fitness", "Hiking", "Tennis", "Basketball",
    ]

    static let all: [ActivityKind] = [
        ActivityKind(name: "Air Travel", symbol: "airplane", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Archery", symbol: "figure.archery", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Assault Bike", symbol: "figure.indoor.cycle", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Australian Rules Football", symbol: "figure.australian.football", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Babywearing", symbol: "figure.and.child.holdinghands", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Badminton", symbol: "figure.badminton", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Ballet", symbol: "figure.dance", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Barre", symbol: "figure.barre", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Barre3", symbol: "figure.barre", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Barry's", symbol: "figure.run.treadmill", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Bartending", symbol: "wineglass", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Baseball", symbol: "figure.baseball", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Basketball", symbol: "figure.basketball", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Billiards", symbol: "circle.circle", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Bodybuilding", symbol: "figure.strengthtraining.traditional", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Bouldering", symbol: "figure.climbing", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Bowling", symbol: "figure.bowling", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Box Fitness", symbol: "figure.boxing", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Boxing", symbol: "figure.boxing", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Breakdancing", symbol: "figure.dance", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Caddying", symbol: "figure.golf", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Canoeing", symbol: "oar.2.crossed", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Cheerleading", symbol: "figure.dance", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Chess", symbol: "checkerboard.rectangle", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Circus Arts", symbol: "figure.gymnastics", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Cleaning", symbol: "sparkles", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Climber", symbol: "figure.stair.stepper", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Coaching", symbol: "person.wave.2", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Commuting", symbol: "figure.walk", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Cooking", symbol: "frying.pan", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Cricket", symbol: "figure.cricket", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Cross Country Skiing", symbol: "figure.skiing.crosscountry", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Curling", symbol: "figure.curling", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Cycling", symbol: "figure.outdoor.cycle", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Dance", symbol: "figure.dance", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Darts", symbol: "target", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Dedicated Parenting", symbol: "figure.and.child.holdinghands", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Disc Golf", symbol: "figure.disc.sports", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Diving", symbol: "figure.open.water.swim", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Dog Walking", symbol: "dog", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Driving", symbol: "car", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Duathlon", symbol: "figure.run", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Elliptical", symbol: "figure.elliptical", section: .activity, countsAsStrength: false),
        ActivityKind(name: "F45 Training", symbol: "figure.highintensity.intervaltraining", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Fencing", symbol: "figure.fencing", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Field Hockey", symbol: "figure.hockey", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Firefighting", symbol: "flame", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Fishing", symbol: "figure.fishing", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Football", symbol: "figure.american.football", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Freediving", symbol: "figure.open.water.swim", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Functional Fitness", symbol: "figure.strengthtraining.functional", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Gaelic Football", symbol: "figure.australian.football", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Gaming", symbol: "gamecontroller", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Golf", symbol: "figure.golf", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Gymnastics", symbol: "figure.gymnastics", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Hacky Sack", symbol: "figure.soccer", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Handball", symbol: "figure.handball", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Hand Cycling", symbol: "figure.hand.cycling", section: .activity, countsAsStrength: false),
        ActivityKind(name: "High-Stress Work", symbol: "brain.head.profile", section: .activity, countsAsStrength: false),
        ActivityKind(name: "HIIT", symbol: "figure.highintensity.intervaltraining", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Hiking", symbol: "figure.hiking", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Horseback Riding", symbol: "figure.equestrian.sports", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Hot Yoga", symbol: "figure.yoga", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Hurling/Camogie", symbol: "figure.hockey", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Ice Hockey", symbol: "figure.hockey", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Ice Skating", symbol: "figure.skating", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Inline Skating", symbol: "figure.skating", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Jet Skiing", symbol: "figure.skiing.downhill", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Jiu Jitsu", symbol: "figure.martial.arts", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Judo", symbol: "figure.martial.arts", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Jumping Rope", symbol: "figure.jumprope", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Kayaking", symbol: "oar.2.crossed", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Kickball", symbol: "figure.kickball", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Kickboxing", symbol: "figure.boxing", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Kite boarding", symbol: "wind", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Lacrosse", symbol: "figure.lacrosse", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Manual Labor", symbol: "hammer", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Martial Arts", symbol: "figure.martial.arts", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Motocross", symbol: "bicycle", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Motor Racing", symbol: "car", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Mountain Biking", symbol: "figure.outdoor.cycle", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Mountaineering", symbol: "mountain.2", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Muay Thai", symbol: "figure.kickboxing", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Musical Performance", symbol: "music.note", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Netball", symbol: "figure.basketball", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Nordic Walking", symbol: "figure.walk", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Nursing a Baby", symbol: "figure.and.child.holdinghands", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Obstacle Course Racing", symbol: "figure.mixed.cardio", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Operations - Flying", symbol: "airplane", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Operations - Medical", symbol: "cross.case", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Operations - Tactical", symbol: "shield", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Operations - Water", symbol: "water.waves", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Other", symbol: "figure.mixed.cardio", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Paddle Tennis", symbol: "figure.racquetball", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Paddleboarding", symbol: "figure.surfing", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Padel", symbol: "figure.racquetball", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Paintball", symbol: "scope", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Parkour", symbol: "figure.run", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Physical Therapy", symbol: "cross.case", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Pickleball", symbol: "figure.pickleball", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Pilates", symbol: "figure.pilates", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Polo", symbol: "figure.equestrian.sports", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Poker", symbol: "suit.spade", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Powerlifting", symbol: "figure.strengthtraining.traditional", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Public Speaking", symbol: "mic", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Pumping", symbol: "drop", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Racquetball", symbol: "figure.racquetball", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Race Walking", symbol: "figure.walk", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Refereeing", symbol: "flag", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Reformer Pilates", symbol: "figure.pilates", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Rock Climbing", symbol: "figure.climbing", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Roller Hockey", symbol: "figure.hockey", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Rowing", symbol: "figure.rower", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Rucking", symbol: "figure.hiking", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Rugby", symbol: "figure.rugby", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Running", symbol: "figure.run", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Sailing", symbol: "sailboat", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Scootering", symbol: "scooter", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Sculpt Yoga", symbol: "figure.yoga", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Skateboarding", symbol: "figure.skateboarding", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Ski Erg", symbol: "figure.skiing.crosscountry", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Ski Touring", symbol: "figure.skiing.crosscountry", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Skiing", symbol: "figure.skiing.downhill", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Skydiving", symbol: "figure.open.water.swim", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Snowshoeing", symbol: "figure.hiking", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Snow Shoveling", symbol: "snowflake", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Snowboarding", symbol: "figure.snowboarding", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Soccer", symbol: "figure.soccer", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Softball", symbol: "figure.softball", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Solidcore", symbol: "figure.strengthtraining.functional", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Spikeball", symbol: "circle.dotted", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Spin", symbol: "figure.indoor.cycle", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Sport Fishing", symbol: "figure.fishing", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Sprint Training", symbol: "figure.run", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Squash", symbol: "figure.squash", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Stadium Steps", symbol: "figure.stairs", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Stage Performance", symbol: "theatermasks", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Stairmaster", symbol: "figure.stair.stepper", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Stroller Jogging", symbol: "figure.run", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Stroller Walking", symbol: "figure.walk", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Surfing", symbol: "figure.surfing", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Swimming", symbol: "figure.pool.swim", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Table Tennis/Ping Pong", symbol: "figure.table.tennis", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Taekwondo", symbol: "figure.martial.arts", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Tennis", symbol: "figure.tennis", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Thrill Ride", symbol: "sparkles", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Toddler wearing", symbol: "figure.and.child.holdinghands", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Track & Field", symbol: "figure.track.and.field", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Trail Running", symbol: "figure.run", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Trampoline", symbol: "figure.gymnastics", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Triathlon", symbol: "figure.open.water.swim", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Ultimate", symbol: "figure.disc.sports", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Unicycling", symbol: "figure.outdoor.cycle", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Vagus Nerve Stimulation", symbol: "waveform.path", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Volleyball", symbol: "figure.volleyball", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Wakeboarding", symbol: "figure.surfing", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Walking", symbol: "figure.walk", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Watching Sports", symbol: "tv", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Water Aerobics", symbol: "figure.water.fitness", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Water Polo", symbol: "figure.equestrian.sports", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Water Skiing", symbol: "figure.skiing.downhill", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Weightlifting", symbol: "figure.strengthtraining.traditional", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Wheelchair Pushing", symbol: "figure.roll", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Winter Biathlon", symbol: "figure.skiing.crosscountry", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Woodchopping", symbol: "hammer", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Wrestling", symbol: "figure.wrestling", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Yard Work/Gardening", symbol: "leaf", section: .activity, countsAsStrength: false),
        ActivityKind(name: "Yoga", symbol: "figure.yoga", section: .activity, countsAsStrength: true),
        ActivityKind(name: "Acupuncture", symbol: "cross.case", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Air Compression", symbol: "wind", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Air Compression (Normatec)", symbol: "wind", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Breathwork", symbol: "lungs", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Bright Light Therapy", symbol: "sun.max", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Chiropractor", symbol: "cross.case", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Cuddling with Child", symbol: "figure.and.child.holdinghands", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Cold Shower", symbol: "shower", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Contrast Therapy", symbol: "thermometer.snowflake", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Dry Sauna", symbol: "flame", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Foam Rolling", symbol: "figure.rolling", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Guided Breathing - Increase Alertness", symbol: "lungs", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Guided Breathing - Increase Relaxation", symbol: "lungs", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Hot Tub", symbol: "bathtub", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Ice Bath", symbol: "snowflake", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Infrared Sauna", symbol: "flame", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Knitting", symbol: "scribble", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Massage Therapy", symbol: "hand.raised", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Meditation", symbol: "figure.mind.and.body", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Non-sleep, deep rest", symbol: "moon.zzz", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Other - Recovery", symbol: "figure.mixed.cardio", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Percussive Massage", symbol: "hand.raised", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Percussive Massage (Hypervolt)", symbol: "hand.raised", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Playing with Child", symbol: "figure.and.child.holdinghands", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "QiGong", symbol: "figure.taichi", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Red Light Therapy", symbol: "sun.max", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Restorative Yoga", symbol: "figure.yoga", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Sound healing", symbol: "speaker.wave.2", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Steam Room", symbol: "cloud", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Stretching", symbol: "figure.flexibility", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Tai Chi", symbol: "figure.taichi", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Warm Bath", symbol: "bathtub", section: .recovery, countsAsStrength: false),
        ActivityKind(name: "Nap", symbol: "powersleep", section: .sleep, countsAsStrength: false),
        ActivityKind(name: "Sleep", symbol: "moon", section: .sleep, countsAsStrength: false),
    ]

    static let sports = all.filter { $0.section == .activity }
    static let recovery = all.filter { $0.section == .recovery }
    static let sleep = all.filter { $0.section == .sleep }

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
                if search.isEmpty {
                    Section("Activities") {
                        ForEach(ActivityCatalog.sports) { kind in row(kind) }
                    }
                    Section("Recovery activities") {
                        ForEach(ActivityCatalog.recovery) { kind in row(kind) }
                    }
                    Section("Sleep activities") {
                        ForEach(ActivityCatalog.sleep) { kind in row(kind) }
                    }
                } else {
                    Section("Results") {
                        ForEach(filtered) { kind in row(kind) }
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
