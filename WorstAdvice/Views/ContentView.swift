import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab = 0
    @State private var session: AppSessionViewModel?

    var body: some View {
        Group {
            if let session {
                ZStack {
                    Theme.backgroundGradient(for: session.settings.theme)
                        .ignoresSafeArea()

                    if session.settings.theme == .neon {
                        FloatingParticlesView(theme: session.settings.theme, reduceMotion: session.settings.reduceMotion)
                            .ignoresSafeArea()
                    }

                    TabView(selection: $selectedTab) {
                        GenerateTabView(
                            viewModel: session.generate,
                            settings: session.settings,
                            onDataChanged: { session.refreshLists() }
                        )
                        .tag(0)
                        .tabItem {
                            Label("Generate", systemImage: "sparkles")
                        }

                        FavoritesTabView(viewModel: session.favorites, settings: session.settings)
                            .tag(1)
                            .tabItem {
                                Label("Favorites", systemImage: "bookmark.fill")
                            }

                        HistoryTabView(
                            viewModel: session.history,
                            settings: session.settings,
                            onUseRecord: { record in
                                session.generate.current = record
                                selectedTab = 0
                            },
                            onDataChanged: { session.refreshLists() }
                        )
                        .tag(2)
                        .tabItem {
                            Label("History", systemImage: "clock")
                        }

                        SettingsTabView(viewModel: session.settings, generateViewModel: session.generate)
                            .tag(3)
                            .tabItem {
                                Label("Settings", systemImage: "gearshape")
                            }
                    }
                    .tint(Theme.accent(for: session.settings.theme))
                }
            } else {
                ProgressView("Loading")
                    .task {
                        if session == nil {
                            session = AppSessionViewModel(context: modelContext)
                        }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AdviceRecord.self, AdviceFingerprint.self, UserAdviceSuggestion.self, AppSettingsEntity.self], inMemory: true)
}
