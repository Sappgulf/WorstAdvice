import SwiftUI

// MARK: - Activity Feed View (#6)
// Shows what friends have been up to: streaks, achievements, shared advice, etc.

struct ActivityFeedView: View {
    let social: SocialViewModel
    let settings: SettingsViewModel

    @State private var events: [SocialActivityEvent] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var lastLoadedRefreshAt: Date?
    private var isOnline: Bool { NetworkMonitor.shared.isOnline }

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading activity…")
                        .tint(accent)
                } else if loadFailed {
                    feedErrorState
                } else if events.isEmpty {
                    emptyState
                } else {
                    feedList
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !isOnline {
                    OfflineBanner()
                }
            }
            .navigationTitle("Friend Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task(id: social.lastSocialRefreshAt) { await loadEvents() }
            .refreshable { await loadEvents(force: true) }
        }
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }

    // MARK: Feed List

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(events) { event in
                    ActivityEventRow(event: event, accent: accent, primaryText: primaryText, secondaryText: secondaryText, cardColor: cardColor)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: Error State

    private var feedErrorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(secondaryText)
            Text("Couldn't Load Activity")
                .font(.headline)
                .foregroundStyle(primaryText)
            Text("Something went wrong fetching your friends' activity.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await loadEvents(force: true) }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(accent.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Failed to load activity. Double-tap to retry.")
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 44))
                .foregroundStyle(secondaryText)
            Text("No Activity Yet")
                .font(.headline)
                .foregroundStyle(primaryText)
            Text("When your friends generate advice, unlock achievements, or hit streaks, you'll see it here.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: Load

    private func loadEvents(force: Bool = false) async {
        let refreshAt = social.lastSocialRefreshAt
        if !force, lastLoadedRefreshAt == refreshAt, !events.isEmpty {
            isLoading = false
            return
        }

        isLoading = true
        loadFailed = false
        defer {
            isLoading = false
            lastLoadedRefreshAt = refreshAt
        }

        do {
            try Task.checkCancellation()
        } catch {
            loadFailed = true
            return
        }

        // In production this would call social.fetchActivityFeed().
        // For now, generate plausible demo events from the current friends list.
        let now = Date()
        var generated: [SocialActivityEvent] = []
        for (i, friend) in social.friends.prefix(5).enumerated() {
            let eventTypes = SocialActivityEvent.ActivityEventType.allCases
            let type = eventTypes[i % eventTypes.count]
            generated.append(SocialActivityEvent(
                id: UUID(),
                actorHandle: friend.handle,
                actorDisplayName: friend.displayName,
                type: type,
                targetText: type == .friendSharedAdvice ? "Always double-check your work by skipping it entirely." : nil,
                targetCategory: type == .friendSharedAdvice ? .productivity : nil,
                targetTone: type == .friendSharedAdvice ? .corporateConsultant : nil,
                occurredAt: now.addingTimeInterval(Double(-i) * 1800)
            ))
        }
        events = generated.sorted { $0.occurredAt > $1.occurredAt }
        isLoading = false
    }
}

// MARK: - Activity Event Row

private struct ActivityEventRow: View {
    let event: SocialActivityEvent
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Actor avatar placeholder
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 40, height: 40)
                Text(String(event.actorDisplayName.prefix(1)).uppercased())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(event.actorDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                    Text(event.type.templateText)
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                    Image(systemName: event.type.icon)
                        .font(.caption)
                        .foregroundStyle(accent)
                }

                if let text = event.targetText {
                    Text("\"\(text)\"")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(cardColor.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Text(event.occurredAt.relativeDescription)
                    .font(.caption2)
                    .foregroundStyle(secondaryText.opacity(0.7))
            }
            Spacer()
        }
        .padding(12)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Date helper

private extension Date {
    var relativeDescription: String {
        let diff = Date().timeIntervalSince(self)
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
