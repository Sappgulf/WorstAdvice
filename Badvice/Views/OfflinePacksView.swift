import SwiftUI

struct OfflinePacksView: View {
    let settings: SettingsViewModel
    @State private var cache = OfflinePackCache()

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }

    var body: some View {
        ZStack {
            Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionShell(accent: accent, cardColor: cardColor) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.copperEmbossGradient)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Theme.espressoInk)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("OFFLINE VAULT")
                                    .font(.caption2.weight(.heavy))
                                    .tracking(1.1)
                                    .foregroundStyle(accent)
                                Text("Download content packs for offline chaos.")
                                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                                    .foregroundStyle(primaryText)
                                Text("Packs expand phrase banks without changing the flow. Cache them for flights and dead zones.")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } content: {
                        Text("Packs expand phrase banks without changing the app flow.")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                    }

                    ForEach(ContentPack.allCases, id: \.self) { pack in
                        let status = cache.status(for: pack)
                        packRow(pack: pack, status: status)
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, Theme.tabContentBottomInset)
            }
        }
        .navigationTitle("Offline Packs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }

    private func packRow(pack: ContentPack, status: OfflinePackStatus) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(primaryText)
                Text(statusLabel(status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(status))
            }
            Spacer(minLength: 8)
            packAction(pack: pack, status: status)
        }
        .padding(14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                    .fill(cardColor)
                if Theme.usesPaperGrain(for: settings.theme) {
                    PaperGrainOverlay(opacity: 0.04)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func packAction(pack: ContentPack, status: OfflinePackStatus) -> some View {
        switch status {
        case .notCached:
            TabCommandActionButton(
                title: "Download",
                systemImage: "arrow.down.circle",
                accent: accent,
                buttonText: buttonText,
                prominent: true,
                minHeight: 36
            ) {
                Task { await cache.download(pack) }
            }
            .frame(width: 120)
        case .downloading:
            ProgressView()
                .tint(accent)
                .frame(width: 44, height: 36)
        case .cached:
            TabCommandActionButton(
                title: "Remove",
                systemImage: "trash",
                accent: accent,
                buttonText: buttonText,
                prominent: false,
                minHeight: 36
            ) {
                cache.evict(pack)
            }
            .frame(width: 110)
        case .stale:
            TabCommandActionButton(
                title: "Update",
                systemImage: "arrow.triangle.2.circlepath",
                accent: accent,
                buttonText: buttonText,
                prominent: true,
                minHeight: 36
            ) {
                Task { await cache.download(pack) }
            }
            .frame(width: 110)
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
        case .notCached: return secondaryText
        case .downloading: return accent
        case .cached: return Color.green.opacity(0.9)
        case .stale: return .orange
        }
    }
}
