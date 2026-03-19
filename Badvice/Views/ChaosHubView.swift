import SwiftUI

struct ChaosHubTabView: View {
    @Bindable var generateViewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var social: SocialViewModel
    var onOpenTab: (AppTab) -> Void
    var onDataChanged: () -> Void

    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var contentAppeared = false
    @State private var visibleContracts: [ChaosContract] = []
    @State private var dailyMissionWasComplete = false
    @State private var weeklyMissionWasComplete = false
    @State private var missionCompletePulse = false
    @State private var weeklyCompletePulse = false
    @State private var showingBracket = false
    @State private var showingChaosFormula = false

    private var chaosScore: Int {
        let streak = min(generateViewModel.challengeStreakDays, 14)
        let today = min(generateViewModel.todayGeneratedCount, 10)
        let total = min(generateViewModel.totalGeneratedCount, 120)
        let saved = min(generateViewModel.favoriteCount, 40)
        let score = (Double(streak) * 2.4)
            + (Double(today) * 3.2)
            + (Double(saved) * 1.6)
            + (Double(total) * 0.25)
            + 18
        return min(99, max(8, Int(score)))
    }

    private var chaosScoreProgress: Double {
        Double(chaosScore) / 100.0
    }

    private var chaosScoreHeadline: String {
        switch chaosScore {
        case 85...:
            return "Chaos Elite"
        case 65..<85:
            return "Chaos Surge"
        case 45..<65:
            return "Chaos Stable"
        default:
            return "Chaos Warming"
        }
    }

    private var chaosScoreCaption: String {
        switch chaosScore {
        case 85...:
            return "You are operating at legendary intensity."
        case 65..<85:
            return "Momentum is peaking. Keep the streak hot."
        case 45..<65:
            return "Steady chaos. A few more wins will spike it."
        default:
            return "Kick off a mission to build momentum."
        }
    }

    private var isMotionReduced: Bool {
        settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion
    }

    // Hoist per-theme lookups — single switch per body render instead of ~30 repeated calls
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    chaosMeterCard
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    missionCard
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    winsStrip
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    socialLeaderboardCard
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.clear)
            .preferredColorScheme(Theme.colorScheme(for: settings.theme))
            .refreshable {
                if social.currentUser != nil {
                    await social.refreshLeaderboard()
                }
            }
            .onAppear {
                tabBarVisible.wrappedValue = true
                generateViewModel.trackChaosHubOpened()
                // Only shuffle contracts on first visit; preserve them across tab switches
                if visibleContracts.isEmpty {
                    visibleContracts = Array(Self.allContracts.shuffled().prefix(2))
                }
                // Seed initial completion state so first onChange fires correctly
                dailyMissionWasComplete = generateViewModel.dailyMissionState.isComplete
                weeklyMissionWasComplete = generateViewModel.weeklyMissionState.isComplete
                guard !contentAppeared else { return }
                if isMotionReduced {
                    contentAppeared = true
                } else {
                    withAnimation(.spring(response: Theme.animSlow, dampingFraction: 0.82)) {
                        contentAppeared = true
                    }
                }
                Task {
                    if social.currentUser != nil {
                        await social.refreshLeaderboard()
                    }
                }
            }
            .onChange(of: generateViewModel.dailyMissionState.isComplete) { _, isComplete in
                guard isComplete, !dailyMissionWasComplete, !isMotionReduced else {
                    dailyMissionWasComplete = isComplete
                    return
                }
                dailyMissionWasComplete = true
                HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                missionCompletePulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { missionCompletePulse = false }
            }
            .onChange(of: generateViewModel.weeklyMissionState.isComplete) { _, isComplete in
                guard isComplete, !weeklyMissionWasComplete, !isMotionReduced else {
                    weeklyMissionWasComplete = isComplete
                    return
                }
                weeklyMissionWasComplete = true
                HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                weeklyCompletePulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { weeklyCompletePulse = false }
            }
        }
    }

    private var chaosMeterCard: some View {
        cardShell {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(secondaryText.opacity(0.18), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: chaosScoreProgress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [accent.opacity(0.6), accent, accent.opacity(0.9)]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(
                            isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.78),
                            value: chaosScoreProgress
                        )

                    VStack(spacing: 2) {
                        Text("\(chaosScore)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryText)
                        Text("Chaos")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(secondaryText)
                    }
                }
                .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 6) {
                    Text(chaosScoreHeadline)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text(chaosScoreCaption)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }

                Spacer()

                Button {
                    showingChaosFormula = true
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                } label: {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(secondaryText.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("How is Chaos Score calculated?")
            }
        }
        .sheet(isPresented: $showingChaosFormula) {
            ChaosFormulaSheet(primaryText: primaryText, secondaryText: secondaryText, cardColor: cardColor, accent: accent)
                .presentationDetents([.medium])
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
                                .scaleEffect(missionCompletePulse ? 1.18 : 1.0)
                                .animation(isMotionReduced ? nil : .spring(response: 0.25, dampingFraction: 0.5), value: missionCompletePulse)
                        }
                    }

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(secondaryText.opacity(0.15))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(accent)
                                    .frame(width: geo.size.width * CGFloat(mission.progressFraction))
                                    .animation(isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.75), value: mission.progressFraction)
                                    .shadow(color: mission.isComplete ? accent.opacity(missionCompletePulse ? 0.7 : 0.3) : .clear, radius: missionCompletePulse ? 8 : 4)
                                    .animation(isMotionReduced ? nil : .easeInOut(duration: 0.6), value: missionCompletePulse)
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
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("Reward ready")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(accent)
                                Text("Bonus chaos points unlocked")
                                    .font(.caption2)
                                    .foregroundStyle(accent.opacity(0.7))
                            }
                            .scaleEffect(weeklyCompletePulse ? 1.12 : 1.0)
                            .animation(isMotionReduced ? nil : .spring(response: 0.25, dampingFraction: 0.5), value: weeklyCompletePulse)
                        }
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(secondaryText.opacity(0.15))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(accent.opacity(0.7))
                                    .frame(width: geo.size.width * CGFloat(weekly.progressFraction))
                                    .animation(isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.75), value: weekly.progressFraction)
                                    .shadow(color: weekly.isComplete ? accent.opacity(weeklyCompletePulse ? 0.65 : 0.25) : .clear, radius: weeklyCompletePulse ? 7 : 3)
                                    .animation(isMotionReduced ? nil : .easeInOut(duration: 0.6), value: weeklyCompletePulse)
                            }
                    }
                    .frame(height: 6)
                }

                HStack(spacing: 10) {
                    Button {
                        generateViewModel.trackChaosHubAction("run_mission")
                        generateViewModel.runDailyMissionGeneration()
                        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                        onDataChanged()
                        onOpenTab(.generate)
                    } label: {
                        Label(mission.isComplete ? "Run Again" : "Run Mission", systemImage: "bolt.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .foregroundStyle(buttonText)
                    .disabled(generateViewModel.isGenerating)
                    .accessibilityLabel(mission.isComplete ? "Run mission again: \(mission.title)" : "Run daily mission: \(mission.title)")

                    Button {
                        generateViewModel.trackChaosHubAction("open_advice")
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
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

                Group {
                    if let topic = generateViewModel.topCommunityTopics.first {
                        pulseRow(
                            title: "Top Topic",
                            body: topic.topic,
                            detail: "\(topic.category.title) • \(topic.submissions)x"
                        )
                    } else {
                        pulsePlaceholder("No community topics yet")
                    }
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 6)
                .animation(isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.8).delay(0.05), value: contentAppeared)

                Group {
                    if let liked = generateViewModel.topLikedAdvice.first {
                        pulseRow(
                            title: "Most Liked",
                            body: liked.adviceLine,
                            detail: "\(liked.category.title) • \(liked.tone.title) • \(liked.votes)x likes"
                        )
                    } else {
                        pulsePlaceholder("No liked advice yet")
                    }
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 6)
                .animation(isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.8).delay(0.12), value: contentAppeared)

                Group {
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
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 6)
                .animation(isMotionReduced ? nil : .spring(response: Theme.animMedium, dampingFraction: 0.8).delay(0.19), value: contentAppeared)
            }
        }
    }

    private var socialLeaderboardCard: some View {
        cardShell {
            VStack(alignment: .leading, spacing: 10) {
                Label("Season Leaderboard", systemImage: "list.number")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)

                Text("Season: \(social.leaderboardSeasonID)")
                    .font(.caption)
                    .foregroundStyle(secondaryText)

                if !social.availability.isAvailable {
                    Text(social.availability.message)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                } else if social.currentUser == nil {
                    Text("Create your profile in Friends to compete in leaderboard seasons.")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                } else if social.leaderboard.isEmpty {
                    Text("No scores yet — submit yours and kick off the season!")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(social.leaderboard.prefix(5).enumerated()), id: \.offset) {
                            idx, item in
                            HStack(spacing: 8) {
                                Text("\(idx + 1).")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(secondaryText)
                                    .frame(width: 18, alignment: .leading)
                                Text(item.user?.displayName ?? "@unknown")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(primaryText)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text("\(item.score)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(accent)
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await social.submitChaosScore(Int64(chaosScore))
                        }
                    } label: {
                        Label("Submit Score", systemImage: "paperplane.fill")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .foregroundStyle(buttonText)
                    .disabled(!social.socialFeaturesEnabled)
                    .accessibilityIdentifier("chaos.social.submitScore")

                    Button {
                        Task { await social.refreshLeaderboard() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                    .disabled(!social.socialFeaturesEnabled)
                    .accessibilityIdentifier("chaos.social.refreshLeaderboard")
                }
            }
        }
        .accessibilityIdentifier("chaos.social.leaderboardCard")
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
                        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                        onDataChanged()
                        onOpenTab(.generate)
                    } label: {
                        Label("Daily Drop", systemImage: "calendar.badge.clock")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                    .disabled(generateViewModel.isGenerating)

                    Button {
                        generateViewModel.trackChaosHubAction("open_settings")
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        onOpenTab(.settings)
                    } label: {
                        Label("Open Labs", systemImage: "gearshape")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                    .accessibilityIdentifier("chaos.quickActions.openLabs")
                }

                Button {
                    HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                    showingBracket = true
                } label: {
                    Label("Advice Brackets", systemImage: "trophy.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.bordered)
                .tint(accent)
            }
        }
        .sheet(isPresented: $showingBracket) {
            AdviceBracketView(settings: settings, generateViewModel: generateViewModel)
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
        HStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.caption.weight(.medium))
                .foregroundStyle(secondaryText.opacity(0.45))
            Text(text)
                .font(.caption)
                .foregroundStyle(secondaryText.opacity(0.7))
            Spacer(minLength: 0)
        }
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
                    .fill(cardColor)
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

            ForEach(visibleContracts) { contract in
                contractRow(contract: contract)
            }
        }
    }

    private static let allContracts: [ChaosContract] = [
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
        ),
        ChaosContract(
            title: "The Chaos Franchise",
            description: "Scale your worst idea until it becomes someone else's problem.",
            icon: "building.2",
            category: .money,
            tone: .corporateConsultant,
            contentPack: nil,
            reward: "Franchise Badge"
        ),
        ChaosContract(
            title: "Friend Roast Protocol",
            description: "Deploy targeted social sabotage disguised as helpful advice.",
            icon: "flame",
            category: .social,
            tone: .friendRoast,
            contentPack: nil,
            reward: "Roast Master"
        ),
        ChaosContract(
            title: "Career Implosion",
            description: "Accelerate to the top via the express elevator to chaos.",
            icon: "chart.line.uptrend.xyaxis",
            category: .career,
            tone: .corporateConsultant,
            contentPack: nil,
            reward: "Executive Chaos"
        ),
        ChaosContract(
            title: "The Conspiracy Gym",
            description: "Apply fringe logic to fitness. Gains not guaranteed. Neither is safety.",
            icon: "dumbbell",
            category: .fitness,
            tone: .conspiracyTheorist,
            contentPack: nil,
            reward: "Cryptid Athlete"
        ),
        ChaosContract(
            title: "Finance Wildfire",
            description: "Invest aggressively in ideas your family warned you about.",
            icon: "dollarsign.circle",
            category: .money,
            tone: .cryptoBro,
            contentPack: nil,
            reward: "Burning Wallet"
        ),
        ChaosContract(
            title: "Wizard's Dilemma",
            description: "Conjure solutions to problems that didn't exist until now.",
            icon: "wand.and.stars",
            category: .productivity,
            tone: .wizard,
            contentPack: nil,
            reward: "Arcane Badge"
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
                    applyContract(contract)
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    onDataChanged()
                    onOpenTab(.generate)
                } label: {
                    Text("Accept")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(accent))
                        .foregroundStyle(buttonText)
                }
                .accessibilityLabel("Accept contract: \(contract.title)")
            }
        }
    }

    private func applyContract(_ contract: ChaosContract) {
        if let category = contract.category {
            generateViewModel.selectedCategory = category
        }
        if let tone = contract.tone {
            generateViewModel.selectedTone = tone
        }
        if let pack = contract.contentPack {
            settings.preferredContentPack = pack
        }
        if !contract.description.isEmpty {
            generateViewModel.scenarioText = contract.description
        }
    }
}

// MARK: - Chaos Formula Sheet

private struct ChaosFormulaSheet: View {
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color
    let accent: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Chaos Score Formula", systemImage: "function")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(primaryText)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 12) {
                formulaRow(icon: "flame", label: "Streak", formula: "× 2.4", cap: "max 14 days", color: .orange)
                formulaRow(icon: "bolt", label: "Generated Today", formula: "× 3.2", cap: "max 10", color: accent)
                formulaRow(icon: "bookmark.fill", label: "Saved Advice", formula: "× 1.6", cap: "max 40", color: .purple)
                formulaRow(icon: "chart.bar.fill", label: "All-Time Total", formula: "× 0.25", cap: "max 120", color: .blue)
                Divider().opacity(0.3)
                HStack {
                    Image(systemName: "plusminus.circle.fill")
                        .foregroundStyle(secondaryText)
                        .frame(width: 24)
                    Text("Base score of 18, clamped to 8–99")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
            }

            Text("Score updates live as you generate, save, and streak.")
                .font(.caption2)
                .foregroundStyle(secondaryText.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(cardColor)
    }

    private func formulaRow(icon: String, label: String, formula: String, cap: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryText)
                Text("capped at \(cap)")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            Text(formula)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }
}
