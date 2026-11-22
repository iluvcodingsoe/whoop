import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.onboarded {
                MainTabs()
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .sheet(item: Binding(
            get: { model.journalPrompt },
            set: { model.journalPrompt = $0 }
        )) { prompt in
            JournalPromptSheet(prompt: prompt)
        }
    }
}

/// Die vier Hauptbereiche der App.
enum MainTab: String, CaseIterable, Identifiable {
    case home, health, strength, journal, more

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .health: return "heart.text.square"
        case .strength: return "dumbbell"
        case .journal: return "square.and.pencil"
        case .more: return "line.3.horizontal"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .home: return "house.fill"
        case .health: return "heart.text.square.fill"
        case .strength: return "dumbbell.fill"
        case .journal: return "square.and.pencil"
        case .more: return "line.3.horizontal"
        }
    }

    @MainActor func title(_ model: AppModel) -> String {
        switch self {
        case .home: return model.loc("Start", "Home")
        case .health: return model.loc("Gesundheit", "Health")
        case .strength: return "Strength"
        case .journal: return "Journal"
        case .more: return model.loc("Mehr", "More")
        }
    }
}

struct MainTabs: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            HomeView()
                .contentMargins(.bottom, 100, for: .scrollContent)
                .tag(MainTab.home)
                .toolbar(.hidden, for: .tabBar)
            HealthMonitorView()
                .contentMargins(.bottom, 100, for: .scrollContent)
                .tag(MainTab.health)
                .toolbar(.hidden, for: .tabBar)
            StrengthView()
                .contentMargins(.bottom, 100, for: .scrollContent)
                .tag(MainTab.strength)
                .toolbar(.hidden, for: .tabBar)
            JournalView()
                .contentMargins(.bottom, 100, for: .scrollContent)
                .tag(MainTab.journal)
                .toolbar(.hidden, for: .tabBar)
            SettingsView()
                .contentMargins(.bottom, 100, for: .scrollContent)
                .tag(MainTab.more)
                .toolbar(.hidden, for: .tabBar)
        }
        .overlay(alignment: .bottom) {
            FloatingTabBar(selection: $model.selectedTab)
        }
        .fullScreenCover(isPresented: $model.showStrengthLogger) {
            StrengthLoggerView()
        }
        .sheet(item: $model.editingTemplate) { template in
            TemplateEditorView(template: template)
        }
    }
}

/// Schwebende Tab-Leiste: abgerundete Kapsel, aktiver Tab hell hinterlegt.
struct FloatingTabBar: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: MainTab
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases) { tab in
                let active = tab == selection
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: active ? tab.selectedSymbol : tab.symbol)
                            .font(.system(size: 20, weight: .medium))
                            .frame(height: 24)
                        Text(tab.title(model))
                            .font(.system(size: 12, weight: active ? .semibold : .medium))
                    }
                    .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if active {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .matchedGeometryEffect(id: "tab", in: highlight)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(Color(hex: 0x1E2226).opacity(0.96))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}
