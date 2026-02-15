import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: AppTab = .generate
    @State private var session: AppSessionViewModel?
    @State private var showConfetti = false

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if let session {
                ZStack {
                    ThemeBackgroundView(mode: session.settings.theme)
                        .ignoresSafeArea()

                    if session.settings.theme == .neon {
                        FloatingParticlesView(theme: session.settings.theme, reduceMotion: session.settings.reduceMotion)
                            .ignoresSafeArea()
                    }

                    TabView(selection: $selectedTab) {
                        ForEach(session.settings.tabOrder) { tab in
                            tabView(for: tab, session: session)
                                .tag(tab)
                                .tabItem {
                                    Label(tab.title, systemImage: tab.systemImage)
                                }
                        }
                    }
                    .tint(Theme.accent(for: session.settings.theme))
                    .toolbarBackground(Theme.tabBarBackground(for: session.settings.theme), for: .tabBar)
                    .toolbarBackground(.visible, for: .tabBar)

                    // Confetti overlay — fires on streak milestones
                    ConfettiView(isActive: $showConfetti)
                }
                .fullScreenCover(isPresented: .init(
                    get: { !hasSeenOnboarding },
                    set: { if !$0 { hasSeenOnboarding = true } }
                )) {
                    OnboardingFlow(isPresented: .init(
                        get: { !hasSeenOnboarding },
                        set: { if !$0 { hasSeenOnboarding = true } }
                    ))
                }
                .onChange(of: session.generate.challengeStreakDays) { _, days in
                    if [3, 7, 14, 30].contains(days) {
                        showConfetti = true
                    }
                }
            } else {
                ZStack {
                    Color(hex: "F7F2E8").ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(Color(hex: "8F4A22").opacity(0.7))
                        ProgressView()
                            .tint(Color(hex: "8F4A22"))
                    }
                }
                .task {
                    if session == nil {
                        session = AppSessionViewModel(context: modelContext)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tabView(for tab: AppTab, session: AppSessionViewModel) -> some View {
        switch tab {
        case .generate:
            GenerateTabView(
                viewModel: session.generate,
                settings: session.settings,
                onDataChanged: { session.refreshLists() }
            )
        case .quotes:
            QuotesTabView(viewModel: session.quotes, settings: session.settings)
        case .favorites:
            FavoritesTabView(viewModel: session.favorites, settings: session.settings)
        case .history:
            HistoryTabView(
                viewModel: session.history,
                settings: session.settings,
                onUseRecord: { record in
                    session.generate.current = record
                    selectedTab = .generate
                },
                onDataChanged: { session.refreshLists() }
            )
        case .settings:
            SettingsTabView(
                viewModel: session.settings,
                generateViewModel: session.generate,
                quotesViewModel: session.quotes
            )
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                AdviceRecord.self,
                AdviceFingerprint.self,
                UserAdviceSuggestion.self,
                UserQuoteSuggestion.self,
                QuoteVoteRecord.self,
                AppSettingsEntity.self
            ],
            inMemory: true
        )
}
