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
        .sheet(isPresented: Binding(
            get: { model.journalPromptDay != nil },
            set: { if !$0 { model.journalPromptDay = nil } }
        )) {
            if let dayKey = model.journalPromptDay {
                JournalPromptSheet(dayKey: dayKey)
            }
        }
    }
}

/// Die vier Hauptbereiche der App.
enum MainTab: String, CaseIterable, Identifiable {
    case home, health, journal, more

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .health: return "heart.text.square"
        case .journal: return "square.and.pencil"
        case .more: return "line.3.horizontal"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .home: return "house.fill"
        case .health: return "heart.text.square.fill"
        case .journal: return "square.and.pencil"
        case .more: return "line.3.horizontal"
        }
    }

    func title(_ model: AppModel) -> String {
        switch self {
        case .home: return model.loc("Start", "Home")
        case .health: return model.loc("Gesundheit", "Health")
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
                .tag(MainTab.home)
                .toolbar(.hidden, for: .tabBar)
            HealthMonitorView()
                .tag(MainTab.health)
                .toolbar(.hidden, for: .tabBar)
            JournalView()
                .tag(MainTab.journal)
                .toolbar(.hidden, for: .tabBar)
            SettingsView()
                .tag(MainTab.more)
                .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $model.selectedTab)
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
