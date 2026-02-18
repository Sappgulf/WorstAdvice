import SwiftUI

struct ChaosHubTabView: View {
    @Bindable var generateViewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    var onOpenTab: (AppTab) -> Void
    var onDataChanged: () -> Void

    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var contentAppeared = false

    private var isMotionReduced: Bool {
        settings.reduceMotion || accessibilityReduceMotion
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    missionCard
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    winsStrip
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    pulseCard
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    quickActionsCard
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .coordinateSpace(name: "scroll")
            .trackScrollForTabBar()
            .navigationTitle("Chaos Hub")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                tabBarVisible.wrappedValue = true
                generateViewModel.trackChaosHubOpened()
                if isMotionReduced {
                    contentAppeared = true
                } else {
                    contentAppeared = false
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        contentAppeared = true
                    }
                }
            }
        }
    }

    private var missionCard: some View {
        let mission = generateViewModel.dailyMissionState
        return cardShell {
            VStack(alignment: .leading, spacing: 12) {
                Label("Daily Mission", systemImage: "flag.checkered.2.crossed")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.primaryText(for: settings.theme))

                Text(mission.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText(for: settings.theme))

                Text(mission.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))

                HStack(spacing: 8) {
                    statPill(title: mission.category.title, systemImage: mission.category.icon)
                    statPill(title: mission.tone.title, systemImage: "dial.medium")
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(mission.currentCount)/\(mission.targetCount) completed")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText(for: settings.theme))
                        Spacer(minLength: 8)
                        if mission.isComplete {
                            Text("Completed")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.accent(for: settings.theme))
                        }
                    }

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(Theme.secondaryText(for: settings.theme).opacity(0.15))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(Theme.accent(for: settings.theme))
                                    .frame(width: geo.size.width * CGFloat(mission.progressFraction))
                            }
                    }
                    .frame(height: 8)
                }

                HStack(spacing: 10) {
                    Button {
                        generateViewModel.trackChaosHubAction("run_mission")
                        generateViewModel.runDailyMissionGeneration()
                        onDataChanged()
                        onOpenTab(.generate)
                    } label: {
                        Label(mission.isComplete ? "Run Again" : "Run Mission", systemImage: "bolt.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent(for: settings.theme))
                    .foregroundStyle(Theme.buttonText(for: settings.theme))

                    Button {
                        generateViewModel.trackChaosHubAction("open_advice")
                        onOpenTab(.generate)
                    } label: {
                        Label("Open Advice", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent(for: settings.theme))
                }
            }
        }
    }

    private var winsStrip: some View {
        cardShell {
            VStack(alignment: .leading, spacing: 10) {
                Label("Wins", systemImage: "trophy")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.primaryText(for: settings.theme))

                HStack(spacing: 8) {
                    winMetric(title: "Streak", value: "\(generateViewModel.challengeStreakDays)")
                    winMetric(title: "Today", value: "\(generateViewModel.todayGeneratedCount)")
                    winMetric(title: "Total", value: "\(generateViewModel.totalGeneratedCount)")
                    winMetric(title: "Saved", value: "\(generateViewModel.favoriteCount)")
                }

                Text(generateViewModel.chaosHubSummaryLine)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText(for: settings.theme))
            }
        }
    }

    private var pulseCard: some View {
        cardShell {
            VStack(alignment: .leading, spacing: 12) {
                Label("Community Pulse", systemImage: "chart.bar.xaxis")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.primaryText(for: settings.theme))

                if let topic = generateViewModel.topCommunityTopics.first {
                    pulseRow(
                        title: "Top Topic",
                        body: topic.topic,
                        detail: "\(topic.category.title) • \(topic.submissions)x"
                    )
                } else {
                    pulsePlaceholder("No community topics yet")
                }

                if let liked = generateViewModel.topLikedAdvice.first {
                    pulseRow(
                        title: "Most Liked",
                        body: liked.adviceLine,
                        detail: "\(liked.category.title) • \(liked.tone.title) • \(liked.votes)x likes"
                    )
                } else {
                    pulsePlaceholder("No liked advice yet")
                }

                if let disliked = generateViewModel.topDislikedAdvice.first {
                    pulseRow(
                        title: "Most Disliked",
                        body: disliked.adviceLine,
                        detail: "\(disliked.category.title) • \(disliked.tone.title) • \(disliked.votes)x dislikes"
                    )
                } else {
                    pulsePlaceholder("No disliked advice yet")
                }
            }
        }
    }

    private var quickActionsCard: some View {
        cardShell {
            VStack(alignment: .leading, spacing: 10) {
                Label("Quick Actions", systemImage: "bolt.horizontal.circle")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.primaryText(for: settings.theme))

                HStack(spacing: 10) {
                    Button {
                        generateViewModel.trackChaosHubAction("daily_drop")
                        generateViewModel.generateDailyDrop()
                        onDataChanged()
                        onOpenTab(.generate)
                    } label: {
                        Label("Daily Drop", systemImage: "calendar.badge.clock")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent(for: settings.theme))

                    Button {
                        generateViewModel.trackChaosHubAction("open_settings")
                        onOpenTab(.settings)
                    } label: {
                        Label("Open Labs", systemImage: "gearshape")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent(for: settings.theme))
                }
            }
        }
    }

    private func statPill(title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.accent(for: settings.theme))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.accent(for: settings.theme).opacity(0.12))
        )
    }

    private func winMetric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.primaryText(for: settings.theme))
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.accent(for: settings.theme).opacity(0.08))
        )
    }

    private func pulseRow(title: String, body: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
            Text(body)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.secondaryText(for: settings.theme).opacity(0.09))
        )
    }

    private func pulsePlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.secondaryText(for: settings.theme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.secondaryText(for: settings.theme).opacity(0.09))
            )
    }

    private func cardShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardColor(for: settings.theme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.accent(for: settings.theme).opacity(0.12), lineWidth: 1)
            )
    }
}
