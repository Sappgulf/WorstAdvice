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

    // Hoist per-theme lookups — single switch per body render instead of ~30 repeated calls
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }

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

                    contractsSection
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
                guard !contentAppeared else { return }
                if isMotionReduced {
                    contentAppeared = true
                } else {
                    withAnimation(.spring(response: Theme.animSlow, dampingFraction: 0.82)) {
                        contentAppeared = true
                    }
                }
            }
        }
    }

    private var missionCard: some View {
        let mission = generateViewModel.dailyMissionState
        let weekly = generateViewModel.weeklyMissionState
        return cardShell {
            VStack(alignment: .leading, spacing: 12) {
                Label("Daily Mission", systemImage: "flag.checkered.2.crossed")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)

                Text(mission.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(primaryText)

                Text(mission.subtitle)
                    .font(.caption)
                    .foregroundStyle(secondaryText)

                HStack(spacing: 8) {
                    statPill(title: mission.category.title, systemImage: mission.category.icon)
                    statPill(title: mission.tone.title, systemImage: "dial.medium")
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(mission.currentCount)/\(mission.targetCount) completed")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryText)
                        Spacer(minLength: 8)
                        if mission.isComplete {
                            Text("Completed")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(accent)
                        }
                    }

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(secondaryText.opacity(0.15))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(accent)
                                    .frame(width: geo.size.width * CGFloat(mission.progressFraction))
                                    .animation(.spring(response: Theme.animMedium, dampingFraction: 0.75), value: mission.progressFraction)
                            }
                    }
                    .frame(height: 8)
                }

                Divider()
                    .overlay(secondaryText.opacity(0.18))

                VStack(alignment: .leading, spacing: 8) {
                    Label("Weekly Mission", systemImage: "calendar.badge.clock")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(secondaryText)
                    Text(weekly.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                    Text(weekly.subtitle)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                    HStack {
                        Text("\(weekly.currentCount)/\(weekly.targetCount) completed")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryText)
                        Spacer(minLength: 8)
                        if weekly.isComplete {
                            Text("Reward ready")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(accent)
                        }
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(secondaryText.opacity(0.15))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(accent.opacity(0.7))
                                    .frame(width: geo.size.width * CGFloat(weekly.progressFraction))
                                    .animation(.spring(response: Theme.animMedium, dampingFraction: 0.75), value: weekly.progressFraction)
                            }
                    }
                    .frame(height: 6)
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
                    .tint(accent)
                    .foregroundStyle(Theme.buttonText(for: settings.theme))
                    .accessibilityLabel(mission.isComplete ? "Run mission again: \(mission.title)" : "Run daily mission: \(mission.title)")

                    Button {
                        generateViewModel.trackChaosHubAction("open_advice")
                        onOpenTab(.generate)
                    } label: {
                        Label("Open Advice", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                }
            }
        }
    }

    private var winsStrip: some View {
        cardShell {
            VStack(alignment: .leading, spacing: 10) {
                Label("Wins", systemImage: "trophy")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)

                HStack(spacing: 8) {
                    winMetric(title: "Streak", value: "\(generateViewModel.challengeStreakDays)")
                    winMetric(title: "Today", value: "\(generateViewModel.todayGeneratedCount)")
                    winMetric(title: "Total", value: "\(generateViewModel.totalGeneratedCount)")
                    winMetric(title: "Saved", value: "\(generateViewModel.favoriteCount)")
                }

                Text(generateViewModel.chaosHubSummaryLine)
                    .font(.caption)
                    .foregroundStyle(secondaryText)

                Text(settings.streakFreezeAvailableThisWeek ? "Streak Freeze: available this week" : "Streak Freeze: already used this week")
                    .font(.caption2)
                    .foregroundStyle(secondaryText.opacity(0.88))
            }
        }
    }

    private var pulseCard: some View {
        cardShell {
            VStack(alignment: .leading, spacing: 12) {
                Label("Community Pulse", systemImage: "chart.bar.xaxis")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)

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
                    .foregroundStyle(primaryText)

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
                    .tint(accent)

                    Button {
                        generateViewModel.trackChaosHubAction("open_settings")
                        onOpenTab(.settings)
                    } label: {
                        Label("Open Labs", systemImage: "gearshape")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
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
        .foregroundStyle(accent)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(0.12))
        )
    }

    private func winMetric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(primaryText)
            Text(title)
                .font(.caption2)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }

    private func pulseRow(title: String, body: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(secondaryText)
            Text(body)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(primaryText)
            Text(detail)
                .font(.caption)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(secondaryText.opacity(0.09))
        )
    }

    private func pulsePlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(secondaryText.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(secondaryText.opacity(0.06))
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
                    .stroke(accent.opacity(0.12), lineWidth: 1)
            )
    }

    private var contractsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Chaos Contracts", systemImage: "signature")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(primaryText)
                .padding(.horizontal, 4)

            ForEach(sampleContracts) { contract in
                contractRow(contract: contract)
            }
        }
    }

    private let sampleContracts = [
        ChaosContract(
            title: "The Neural Glitch",
            description: "Force all advice to prioritize efficiency over ethics.",
            icon: "cpu",
            category: .tech,
            tone: .corporateConsultant,
            contentPack: .cyberInfluence,
            reward: "Cyber Unlock"
        ),
        ChaosContract(
            title: "Social Overwrite",
            description: "Redirect conversation protocols to social engineering.",
            icon: "network",
            category: .social,
            tone: .influencer,
            contentPack: .cyberInfluence,
            reward: "Glitch Aura"
        )
    ]

    private func contractRow(contract: ChaosContract) -> some View {
        cardShell {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: contract.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(contract.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text(contract.description)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    generateViewModel.trackChaosHubAction("accept_contract_\(contract.title)")
                    onDataChanged()
                    onOpenTab(.generate)
                } label: {
                    Text("Accept")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(accent))
                        .foregroundStyle(Theme.buttonText(for: settings.theme))
                }
                .accessibilityLabel("Accept contract: \(contract.title)")
            }
        }
    }
}
