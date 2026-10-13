import SwiftUI

/// Displays actual backend posts. Empty/error states never manufacture community activity.
struct GlobalCommunityFeedView: View {
    let social: SocialViewModel
    let settings: SettingsViewModel
    let onJumpToGenerate: (AdviceCategory, ToneMode) -> Void

    private var accent: Color { Theme.accent(for: settings.theme) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text("Friends feed")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                Text("Posts use CloudKit's public database. The friends filter helps you find your people; it does not make these posts private.")
                    .font(.caption).foregroundStyle(Theme.secondaryText(for: settings.theme))
                if !NetworkMonitor.shared.isOnline { OfflineBanner() }
                if social.isRefreshingSocialData {
                    ProgressView("Checking for fresh bad ideas…").tint(accent)
                } else if let status = social.statusMessage, !social.socialFeaturesEnabled {
                    Text(status).font(.subheadline)
                    Button("Try again") { Task { await social.retryFriendsLoad() } }.tint(accent)
                } else if social.feedPosts.isEmpty {
                    ContentUnavailableView {
                        Label("No bad ideas here yet", systemImage: "text.bubble")
                    } description: {
                        Text(social.socialFeaturesEnabled ? "Your friends' shared takes will appear here." : "Connect an iCloud profile in settings to use social features. Local advice and party mode work offline.")
                    } actions: {
                        Button("Make a bad idea") { onJumpToGenerate(.random, .random) }.tint(accent)
                    }
                } else {
                    ForEach(social.feedPosts.sorted { $0.createdAt > $1.createdAt }) { post in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(post.author.map { "@\($0.handle)" } ?? "Badvice member")
                                .font(.caption.weight(.bold)).foregroundStyle(accent)
                            Text(post.text).font(.system(.title3, design: .serif, weight: .semibold))
                            HStack {
                                Text(post.createdAt, style: .date).font(.caption)
                                Spacer()
                                ShareLink(item: post.text) { Label("Share", systemImage: "square.and.arrow.up") }
                            }
                            .foregroundStyle(Theme.secondaryText(for: settings.theme))
                        }
                        .padding(20)
                        .background(Theme.cardColor(for: settings.theme), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .foregroundStyle(Theme.primaryText(for: settings.theme))
            .padding(20)
        }
        .refreshable { await social.refreshSocialData() }
        .task { await social.retryFriendsLoad() }
    }
}
