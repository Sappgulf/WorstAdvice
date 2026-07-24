import SwiftUI

// MARK: - Global Community Feed View (#9)
// Curated public advice posts from the entire Badvice community.

struct GlobalCommunityFeedView: View {
    let social: SocialViewModel
    let settings: SettingsViewModel
    let onJumpToGenerate: (AdviceCategory, ToneMode) -> Void

    @State private var allPosts: [CommunityPost] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var selectedFilter: CommunityFeedFilter = .hot
    @State private var reportedPostIDs: Set<String> = []

    private var isOnline: Bool { NetworkMonitor.shared.isOnline }
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var visiblePosts: [CommunityPost] {
        let filtered = allPosts
        switch selectedFilter {
        case .hot:
            return filtered.sorted { $0.likeCount > $1.likeCount }
        case .new:
            return filtered.sorted { $0.postedAt > $1.postedAt }
        case .top:
            return filtered.sorted { ($0.likeCount + $0.shareCount) > ($1.likeCount + $1.shareCount) }
        }
    }
    private var displayedPosts: [CommunityPost] {
        visiblePosts.filter { !reportedPostIDs.contains($0.id.uuidString) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isOnline {
                OfflineBanner()
                    .animation(.easeInOut(duration: 0.25), value: isOnline)
            }
            filterBar
            Divider().opacity(0.15)

            if isLoading {
                Spacer()
                ProgressView("Loading community…").tint(accent)
                Spacer()
            } else if loadFailed {
                communityErrorState
            } else if displayedPosts.isEmpty {
                emptyState
            } else {
                feedContent
            }
        }
        .task { await load() }
    }

    // MARK: Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CommunityFeedFilter.allCases) { filter in
                    FilterChip(
                        title: filter.label,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        accessibilityIdentifier: "globalCommunity.filter.\(filter.rawValue)",
                        buttonText: Theme.buttonText(for: settings.theme)
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: Feed Content

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(displayedPosts) { post in
                    CommunityPostCard(
                        post: post,
                        accent: accent,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        cardColor: cardColor,
                        hapticsEnabled: settings.hapticsEnabled,
                        onTryCategory: { onJumpToGenerate(post.category, post.tone) },
                        onReport: { reportedPostIDs.insert(post.id.uuidString) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: Error State

    private var communityErrorState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(secondaryText)
            Text("Couldn't Load Feed")
                .font(.headline)
                .foregroundStyle(primaryText)
            Text("The community feed failed to load. Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await load(force: true) }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(accent.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Failed to load community feed. Double-tap to retry.")
    }

    // MARK: Empty

    private var emptyState: some View {
        TabEmptyStatePanel(
            icon: "globe.americas.fill",
            title: "The feed is holding its breath.",
            message: "Community posts land here as people share stamped takes. Be the first dispatch — or refresh in a moment.",
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor,
            reduceMotion: settings.reduceMotion || settings.performanceMode
        )
        .padding(.horizontal, 20)
    }

    // MARK: Load

    private func load(force: Bool = false) async {
        guard allPosts.isEmpty || force else {
            isLoading = false
            return
        }
        isLoading = true
        loadFailed = false
        do {
            try Task.checkCancellation()
            allPosts = Self.demoPosts
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}

// MARK: - Supporting Types

struct CommunityPost: Identifiable, Sendable {
    let id: UUID
    let authorHandle: String
    let adviceLine: String
    let category: AdviceCategory
    let tone: ToneMode
    let likeCount: Int
    let shareCount: Int
    let postedAt: Date
}

private extension GlobalCommunityFeedView {
    static let demoPosts: [CommunityPost] = [
        CommunityPost(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            authorHandle: "chaosqueen",
            adviceLine: "Always CC your entire company on anything even mildly personal.",
            category: .career,
            tone: .corporateConsultant,
            likeCount: 312,
            shareCount: 88,
            postedAt: Date().addingTimeInterval(-7200)
        ),
        CommunityPost(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            authorHandle: "cryptobro99",
            adviceLine: "Your dentist is your best financial advisor. Trust the process.",
            category: .money,
            tone: .cryptoBro,
            likeCount: 204,
            shareCount: 55,
            postedAt: Date().addingTimeInterval(-14_400)
        ),
        CommunityPost(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            authorHandle: "mindfulmaster",
            adviceLine: "The best fitness routine is a playlist. Listen until fit.",
            category: .fitness,
            tone: .minimalistMonk,
            likeCount: 178,
            shareCount: 40,
            postedAt: Date().addingTimeInterval(-21_600)
        ),
        CommunityPost(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            authorHandle: "toxiccoach",
            adviceLine: "Tell your crush how you feel via a formal PowerPoint presentation.",
            category: .dating,
            tone: .lifeCoach,
            likeCount: 445,
            shareCount: 132,
            postedAt: Date().addingTimeInterval(-3600)
        ),
        CommunityPost(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            authorHandle: "boomer_dan",
            adviceLine: "Print every email. Emails are just letters with electricity.",
            category: .tech,
            tone: .boomer,
            likeCount: 289,
            shareCount: 76,
            postedAt: Date().addingTimeInterval(-1800)
        ),
    ]
}

enum CommunityFeedFilter: String, CaseIterable, Identifiable {
    case hot, new, top
    var id: String { rawValue }
    var label: String {
        switch self {
        case .hot: return "Hot"
        case .new: return "New"
        case .top: return "All-Time"
        }
    }
    var icon: String {
        switch self {
        case .hot: return "flame"
        case .new: return "sparkles"
        case .top: return "crown"
        }
    }
}

// MARK: - Post Card

private struct CommunityPostCard: View {
    let post: CommunityPost
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color
    let hapticsEnabled: Bool
    let onTryCategory: () -> Void
    let onReport: () -> Void

    @State private var liked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("@\(post.authorHandle)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer()
                Menu {
                    Button("Try this category", action: onTryCategory)
                    Button("Report", role: .destructive, action: onReport)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(secondaryText)
                }
                .accessibilityLabel("Post options")
            }

            Text("\"\(post.adviceLine)\"")
                .font(.body)
                .foregroundStyle(primaryText)
                .lineLimit(4)

            HStack {
                Label(post.category.title, systemImage: post.category.icon)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                Text("·")
                    .foregroundStyle(secondaryText)
                Label(post.tone.title, systemImage: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                Spacer()
                Button {
                    liked.toggle()
                    HapticsManager.play(style: .light, isEnabled: hapticsEnabled)
                } label: {
                    Label("\(post.likeCount + (liked ? 1 : 0))", systemImage: liked ? "heart.fill" : "heart")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(liked ? .pink : secondaryText)
                }
                .buttonStyle(.plain)
                Label("\(post.shareCount)", systemImage: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
        }
        .padding(14)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous))
    }
}
