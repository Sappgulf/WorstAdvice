import SwiftUI

struct OfflinePacksView: View {
    let settings: SettingsViewModel
    @State private var cache = OfflinePackCache()

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }

    var body: some View {
        ZStack {
            Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()
            List {
                Section {
                    ForEach(ContentPack.allCases, id: \.self) { pack in
                        let status = cache.status(for: pack)
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pack.title)
                                    .font(.body)
                                    .foregroundStyle(primaryText)
                                Text(statusLabel(status))
                                    .font(.caption)
                                    .foregroundStyle(statusColor(status))
                            }
                            Spacer()
                            packAction(pack: pack, status: status)
                        }
                        .listRowBackground(cardColor)
                    }
                } header: {
                    Text("Download packs for offline use")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Offline Packs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }

    @ViewBuilder
    private func packAction(pack: ContentPack, status: OfflinePackStatus) -> some View {
        switch status {
        case .notCached:
            Button("Download") { Task { await cache.download(pack) } }
                .buttonStyle(.bordered).tint(accent)
        case .downloading:
            ProgressView().tint(accent)
        case .cached:
            Button("Remove", role: .destructive) { cache.evict(pack) }
                .buttonStyle(.bordered)
        case .stale:
            Button("Update") { Task { await cache.download(pack) } }
                .buttonStyle(.bordered).tint(.orange)
        }
    }

    private func statusLabel(_ status: OfflinePackStatus) -> String {
        switch status {
        case .notCached: return "Not downloaded"
        case .downloading: return "Downloading…"
        case .cached: return "Available offline"
        case .stale: return "Update available"
        }
    }

    private func statusColor(_ status: OfflinePackStatus) -> Color {
        switch status {
        case .notCached: return .secondary
        case .downloading: return .blue
        case .cached: return .green
        case .stale: return .orange
        }
    }
}
