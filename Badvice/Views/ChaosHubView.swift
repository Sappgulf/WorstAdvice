import SwiftUI

struct ChaosHubTabView: View {
    @Bindable var generateViewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var social: SocialViewModel
    var onOpenTab: (AppTab) -> Void
    var onDataChanged: () -> Void

    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    private let isFocusMode = false

    @State private var contentAppeared = false
    @State private var visibleContracts: [ChaosContract] = []
    @State private var dailyMissionWasComplete = false
    @State private var weeklyMissionWasComplete = false
    @State private var missionCompletePulse = false
    @State private var weeklyCompletePulse = false
    @State private var showingBracket = false
    @State private var showingChaosFormula = false
    @State private var missionPulseTask: Task<Void, Never>?
    @State private var weeklyPulseTask: Task<Void, Never>?
    @State private var appearanceTask: Task<Void, Never>?

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
            return "Mission Elite"
        case 65..<85:
            return "Mission Surge"
        case 45..<65:
            return "Mission Stable"
        default:
            return "Mission Warmup"
        }
    }

    private var chaosScoreCaption: String {
        switch chaosScore {
        case 85...:
            return "You are operating at legendary intensity."
        case 65..<85:
            return "Momentum is peaking. Keep the streak hot."
        case 45..<65:
            return "Steady momentum. A few more wins will spike it."
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
    private var dailyMission: GenerateViewModel.ChaosMissionState { generateViewModel.dailyMissionState }
    private var weeklyMission: GenerateViewModel.WeeklyMissionState { generateViewModel.weeklyMissionState }
    private var primaryNextStepTitle: String {
        if !social.availability.isAccountAvailable {
            return "Continue with today's mission"
        }
        if generateViewModel.isGenerating {
            return "Generating now"
        }
        if !dailyMission.isComplete {
            return "Run today's mission"
        }
        if !weeklyMission.isComplete {
            return "Keep the weekly mission moving"
        }
        if social.socialFeaturesEnabled && social.leaderboard.isEmpty {
            return "Submit your mission score"
        }
        return "Open Advice and keep the streak alive"
    }
    private var primaryNextStepDetail: String {
        if !social.availability.isAccountAvailable {
            return social.availability.message
        }
        if generateViewModel.isGenerating {
            return "Advice is already on the way. Jump back to Generate to track the result."
        }
        if !dailyMission.isComplete {
            return "\(dailyMission.currentCount) of \(dailyMission.targetCount) complete. Run one more piece of advice to move the board."
        }
        if !weeklyMission.isComplete {
            return "\(weeklyMission.currentCount) of \(weeklyMission.targetCount) complete. Keep the week moving from Advice."
        }
        if social.socialFeaturesEnabled && social.leaderboard.isEmpty {
            return "Your mission work is done. Put a score on the board and start the season."
        }
        return "Generate, save, and share to push Mission Score higher."
    }
    private var primaryNextStepButtonTitle: String {
        if !social.availability.isAccountAvailable {
            return "Open Advice"
        }
        if generateViewModel.isGenerating {
            return "Open Advice"
        }
        if !dailyMission.isComplete {
            return "Run Mission"
        }
        if !weeklyMission.isComplete {
            return "Open Advice"
        }
        if social.socialFeaturesEnabled && social.leaderboard.isEmpty {
            return "Submit Score"
        }
        return "Open Advice"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    hubCommandCard
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    cardShell {
                        VStack(alignment: .leading, spacing: 14) {
                            chaosMeterCard
                            groupDivider
                            seasonStatusCard
                            groupDivider
                            missionPathCard
                        }
                    }
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    missionCard
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    if !isFocusMode {
                        cardShell {
                            VStack(alignment: .leading, spacing: 14) {
                                winsStrip
                                groupDivider
                                socialLeaderboardCard
                            }
                        }
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 16)

                        cardShell {
                            VStack(alignment: .leading, spacing: 14) {
                                contractsSection
                                groupDivider
                                pulseCard
                                groupDivider
                                quickActionsCard
                            }
                        }
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 16)
                    }
                }
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.top, 12)
                .padding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 24)
            }
            .coordinateSpace(name: "scroll")
            .trackScrollForTabBar()
            .navigationTitle("Missions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.clear)
            .preferredColorScheme(Theme.colorScheme(for: settings.theme))
            .refreshable {
                if social.currentUser != nil {
                    await social.refreshLeaderboard(force: true)
                }
            }
            .onAppear {
                tabBarVisible.wrappedValue = true
                generateViewModel.trackChaosHubOpened()
                if visibleContracts.isEmpty {
                    visibleContracts = visibleContractSet()
                }
                dailyMissionWasComplete = generateViewModel.dailyMissionState.isComplete
                weeklyMissionWasComplete = generateViewModel.weeklyMissionState.isComplete
                missionPulseTask?.cancel()
                weeklyPulseTask?.cancel()
                appearanceTask?.cancel()
                appearanceTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    guard !Task.isCancelled else { return }
                    if isMotionReduced {
                        contentAppeared = true
                    } else {
                        withAnimation(.spring(response: Theme.animSlow, dampingFraction: 0.82)) {
                            contentAppeared = true
                        }
                    }
                }
            }
            .onDisappear {
                missionPulseTask?.cancel()
                weeklyPulseTask?.cancel()
                appearanceTask?.cancel()
            }
            .onChange(of: generateViewModel.dailyMissionState.isComplete) { _, isComplete in
                guard isComplete, !dailyMissionWasComplete, !isMotionReduced else {
                    dailyMissionWasComplete = isComplete
                    return
                }
                dailyMissionWasComplete = true
                HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                missionCompletePulse = true
                missionPulseTask?.cancel()
                missionPulseTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(550))
                    guard !Task.isCancelled else { return }
                    missionCompletePulse = false
                }
            }
            .onChange(of: generateViewModel.weeklyMissionState.isComplete) { _, isComplete in
                guard isComplete, !weeklyMissionWasComplete, !isMotionReduced else {
                    weeklyMissionWasComplete = isComplete
                    return
                }
                weeklyMissionWasComplete = true
                HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                weeklyCompletePulse = true
                weeklyPulseTask?.cancel()
                weeklyPulseTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(550))
                    guard !Task.isCancelled else { return }
                    weeklyCompletePulse = false
                }
            }
        }
    }

    private var hubCommandCard: some View {
        TabCommandCard(
            eyebrow: "Mission Command",
            title: primaryNextStepTitle,
            detail: primaryNextStepDetail,
            systemImage: "flame.fill",
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor
        ) {
            HStack(spacing: 8) {
                TabCommandMetric(title: "Score", value: "\(chaosScore)", accent: accent, primaryText: primaryText, secondaryText: secondaryText)
                TabCommandMetric(title: "Daily", value: "\(dailyMission.currentCount)/\(dailyMission.targetCount)", accent: accent, primaryText: primaryText, secondaryText: secondaryText)
                TabCommandMetric(title: "Weekly", value: "\(weeklyMission.currentCount)/\(weeklyMission.targetCount)", accent: accent, primaryText: primaryText, secondaryText: secondaryText)
            }
        } actions: {
            HStack(spacing: 10) {
                TabCommandActionButton(
                    title: primaryNextStepButtonTitle,
                    systemImage: "bolt.fill",
                    accent: accent,
                    buttonText: buttonText,
                    isDisabled: generateViewModel.isGenerating && primaryNextStepButtonTitle != "Open Advice",
                    accessibilityIdentifier: "chaos.command.primary"
                ) {
                    performPrimaryNextStep()
                }

                TabCommandActionButton(
                    title: "Advice",
                    systemImage: "sparkles",
                    accent: accent,
                    buttonText: buttonText,
                    prominent: false,
                    accessibilityIdentifier: "chaos.command.generate"
                ) {
                    generateViewModel.trackChaosHubAction("open_generate_from_command")
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    onOpenTab(.generate)
                }
            }
        }
        .accessibilityIdentifier("chaos.command.card")
    }

    private var chaosMeterCard: some View {
        Group {
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
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(primaryText)
                        Text("Score")
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
                .accessibilityLabel("How is Mission Score calculated?")
            }
        }
        .sheet(isPresented: $showingChaosFormula) {
            ChaosFormulaSheet(primaryText: primaryText, secondaryText: secondaryText, cardColor: cardColor, accent: accent)
                .presentationDetents([.medium])
        }
    }

    private var seasonStatusCard: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Season Status")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(primaryText)
                        Text(seasonStatusDetail)
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Text(seasonStatusBadge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(seasonStatusTint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                                .fill(seasonStatusTint.opacity(0.12))
                        )
                }

                HStack(spacing: 10) {
                    seasonPill(
                        title: "Season",
                        value: social.leaderboardSeasonID.isEmpty ? "Offline" : social.leaderboardSeasonID
                    )
                    seasonPill(
                        title: "Profile",
                        value: social.currentUser == nil ? "Missing" : "Ready"
                    )
                    seasonPill(
                        title: "Board",
                        value: social.leaderboard.isEmpty ? "Open" : "Live"
                    )
                }

                if let action = seasonStatusActionTitle {
                    TabCommandActionButton(
                        title: action,
                        systemImage: action == "Continue Locally" ? "iphone" : (social.leaderboard.isEmpty ? "paperplane.fill" : "arrow.clockwise"),
                        accent: accent,
                        buttonText: buttonText,
                        prominent: action != "Continue Locally",
                        accessibilityIdentifier: "chaos.season.primary"
                    ) {
                        performSeasonStatusAction()
                    }
                }
            }
        }
        .accessibilityIdentifier("chaos.season.card")
    }

    private var missionCard: some View {
        let mission = dailyMission
        let weekly = weeklyMission
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

                rewardHintRow(
                    title: mission.isComplete ? "Daily reward unlocked" : "Daily reward",
                    detail: mission.isComplete ? "Mission momentum is banked for today." : "Finish this run to strengthen today's Mission Score.",
                    isComplete: mission.isComplete
                )

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
                    rewardHintRow(
                        title: weekly.isComplete ? "Weekly reward unlocked" : "Weekly reward",
                        detail: weekly.isComplete ? "Bonus mission points are ready." : "Complete the weekly target to unlock bonus mission points.",
                        isComplete: weekly.isComplete
                    )
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
                                Text("Bonus mission points unlocked")
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
                    TabCommandActionButton(
                        title: mission.isComplete ? "Run Again" : "Run Mission",
                        systemImage: "bolt.fill",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: true,
                        isDisabled: generateViewModel.isGenerating,
                        accessibilityIdentifier: "chaos.mission.run",
                        minHeight: 42
                    ) {
                        generateViewModel.trackChaosHubAction("run_mission")
                        generateViewModel.runDailyMissionGeneration()
                        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                        onDataChanged()
                        onOpenTab(.generate)
                    }

                    TabCommandActionButton(
                        title: "Open Advice",
                        systemImage: "sparkles",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: false,
                        accessibilityIdentifier: "chaos.openAdvice",
                        minHeight: 42
                    ) {
                        generateViewModel.trackChaosHubAction("open_advice")
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        onOpenTab(.generate)
                    }
                }
            }
        }
    }

    private var missionPathCard: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Progression Path")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(primaryText)
                            .accessibilityIdentifier("chaos.progressionPath.title")
                        Text("The season is simpler when each next action has a job.")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Text(missionPathBadge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                                .fill(accent.opacity(0.12))
                        )
                }

                VStack(spacing: 9) {
                    missionPathRow(
                        title: "Generate",
                        detail: "Create today’s bad idea.",
                        state: dailyMission.currentCount > 0 ? .done : .now
                    )
                    missionPathRow(
                        title: "Save",
                        detail: "Keep one line worth reusing.",
                        state: generateViewModel.favoriteCount > 0 ? .done : (dailyMission.currentCount > 0 ? .now : .next)
                    )
                    missionPathRow(
                        title: "Streak",
                        detail: "Finish the daily mission and push the week.",
                        state: dailyMission.isComplete ? .done : (generateViewModel.favoriteCount > 0 ? .now : .next)
                    )
                    missionPathRow(
                        title: "Social",
                        detail: "Share, collab, or post a score when the loop is active.",
                        state: social.feedPosts.isEmpty ? (dailyMission.isComplete ? .now : .next) : .done
                    )
                }
            }
        }
        .accessibilityIdentifier("chaos.progressionPath")
    }

    private var missionPathBadge: String {
        if social.feedPosts.isEmpty == false { return "Loop Active" }
        if dailyMission.isComplete { return "Share Next" }
        if generateViewModel.favoriteCount > 0 { return "Finish Daily" }
        if dailyMission.currentCount > 0 { return "Save Next" }
        return "Start"
    }

    private func missionPathRow(title: String, detail: String, state: MissionPathState) -> some View {
        let tint = state.tint(accent: accent)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: state.iconName)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.11)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(primaryText)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(state.label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                .fill(state == .now ? accent.opacity(0.08) : secondaryText.opacity(0.06))
        )
    }

    private func rewardHintRow(title: String, detail: String, isComplete: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isComplete ? "gift.fill" : "gift")
                .font(.caption.weight(.bold))
                .foregroundStyle(isComplete ? accent : secondaryText)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill((isComplete ? accent : secondaryText).opacity(0.11))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(primaryText)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                .fill((isComplete ? accent : secondaryText).opacity(0.07))
        )
    }

    private var winsStrip: some View {
        Group {
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

    private func performPrimaryNextStep() {
        if generateViewModel.isGenerating {
            generateViewModel.trackChaosHubAction("open_advice_during_generation")
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            onOpenTab(.generate)
            return
        }
        if !dailyMission.isComplete {
            generateViewModel.trackChaosHubAction("run_mission_from_command")
            generateViewModel.runDailyMissionGeneration()
            HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
            onDataChanged()
            onOpenTab(.generate)
            return
        }
        if !weeklyMission.isComplete {
            generateViewModel.trackChaosHubAction("open_advice_for_weekly")
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            onOpenTab(.generate)
            return
        }
        if social.socialFeaturesEnabled && social.leaderboard.isEmpty {
            generateViewModel.trackChaosHubAction("submit_score_from_command")
            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
            Task { await social.submitChaosScore(Int64(chaosScore)) }
            return
        }
        generateViewModel.trackChaosHubAction("open_advice_default")
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        onOpenTab(.generate)
    }

    private var pulseCard: some View {
        Group {
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
        Group {
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
                    Text("Social scoring is not ready for this account yet. Continue locally and your mission progress will stay on this device.")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                } else if social.leaderboard.isEmpty {
                    Text("No scores yet — submit yours and kick off the season!")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(social.leaderboard.prefix(5).enumerated()), id: \.element.id) {
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

                if social.socialFeaturesEnabled {
                    HStack(spacing: 10) {
                        TabCommandActionButton(
                            title: "Submit Score",
                            systemImage: "paperplane.fill",
                            accent: accent,
                            buttonText: buttonText,
                            accessibilityIdentifier: "chaos.social.submitScore"
                        ) {
                            Task {
                                HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                                await social.submitChaosScore(Int64(chaosScore))
                            }
                        }

                        TabCommandActionButton(
                            title: "Refresh",
                            systemImage: "arrow.clockwise",
                            accent: accent,
                            buttonText: buttonText,
                            prominent: false,
                            accessibilityIdentifier: "chaos.social.refreshLeaderboard"
                        ) {
                            HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                            Task { await social.refreshLeaderboard(force: true) }
                        }
                    }
                } else {
                    TabCommandActionButton(
                        title: "Continue Locally",
                        systemImage: "iphone",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: false,
                        accessibilityIdentifier: "chaos.social.continueLocally"
                    ) {
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        onOpenTab(.generate)
                    }
                }
            }
        }
        .accessibilityIdentifier("chaos.social.leaderboardCard")
    }

    private var quickActionsCard: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                Label("Quick Actions", systemImage: "bolt.horizontal.circle")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)

                HStack(spacing: 10) {
                    TabCommandActionButton(
                        title: "Daily Drop",
                        systemImage: "calendar.badge.clock",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: false,
                        isDisabled: generateViewModel.isGenerating,
                        accessibilityIdentifier: "chaos.quickActions.dailyDrop",
                        minHeight: 38
                    ) {
                        generateViewModel.trackChaosHubAction("daily_drop")
                        generateViewModel.generateDailyDrop()
                        HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                        onDataChanged()
                        onOpenTab(.generate)
                    }

                    TabCommandActionButton(
                        title: "Open Labs",
                        systemImage: "gearshape",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: false,
                        accessibilityIdentifier: "chaos.quickActions.openLabs",
                        minHeight: 38
                    ) {
                        openSettingsTab()
                    }
                }

                TabCommandActionButton(
                    title: "Advice Brackets",
                    systemImage: "trophy.fill",
                    accent: accent,
                    buttonText: buttonText,
                    prominent: false,
                    accessibilityIdentifier: "chaos.quickActions.adviceBrackets",
                    minHeight: 38
                ) {
                    HapticsManager.playSuccess(isEnabled: settings.hapticsEnabled)
                    showingBracket = true
                }
            }
        }
        .sheet(isPresented: $showingBracket) {
            AdviceBracketView(settings: settings, generateViewModel: generateViewModel)
        }
    }

    private var seasonStatusDetail: String {
        if !social.availability.isAvailable {
            return social.availability.message
        }
        if social.currentUser == nil {
            return "Social scoring is not ready for this account yet. Keep running missions — your local score still counts."
        }
        if social.leaderboard.isEmpty {
            return "You are season-ready. Submit the first score and establish the board instead of waiting for activity to appear."
        }
        return "The season is active. Daily and weekly work now rolls directly into a live leaderboard and visible momentum."
    }

    private var seasonStatusBadge: String {
        if !social.availability.isAvailable {
            return "Offline"
        }
        if social.currentUser == nil {
            return "Local Only"
        }
        if social.leaderboard.isEmpty {
            return "Launch It"
        }
        return "Live"
    }

    private var seasonStatusTint: Color {
        if !social.availability.isAvailable {
            return .orange
        }
        if social.currentUser == nil {
            return accent
        }
        if social.leaderboard.isEmpty {
            return accent
        }
        return .green
    }

    private var seasonStatusActionTitle: String? {
        guard social.availability.isAvailable, social.currentUser != nil else {
            return "Continue Locally"
        }
        if social.leaderboard.isEmpty {
            return "Submit Opening Score"
        }
        return "Refresh Leaderboard"
    }

    private func performSeasonStatusAction() {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        guard social.availability.isAvailable, social.currentUser != nil else {
            onOpenTab(.generate)
            return
        }
        Task {
            if social.leaderboard.isEmpty {
                await social.submitChaosScore(Int64(chaosScore))
            } else {
                await social.refreshLeaderboard(force: true)
            }
        }
    }

    private func seasonPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }

    private func openSettingsTab() {
        generateViewModel.trackChaosHubAction("open_settings")
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        onOpenTab(.settings)
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
            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                .fill(accent.opacity(0.12))
        )
    }

    private func commandMetric(title: String, value: String, isAccent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(isAccent ? accent : primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                .fill(accent.opacity(isAccent ? 0.14 : 0.08))
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
            RoundedRectangle(cornerRadius: Theme.shellMetricCornerRadius, style: .continuous)
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
            RoundedRectangle(cornerRadius: Theme.shellMetricCornerRadius, style: .continuous)
                .fill(secondaryText.opacity(0.09))
        )
    }

    private func pulsePlaceholder(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.caption.weight(.medium))
                .foregroundStyle(secondaryText.opacity(0.65))
            Text(text)
                .font(.caption)
                .foregroundStyle(secondaryText.opacity(0.7))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.shellMetricCornerRadius, style: .continuous)
                .fill(secondaryText.opacity(0.06))
        )
    }

    private var groupDivider: some View {
        Rectangle()
            .fill(secondaryText.opacity(0.12))
            .frame(height: 0.5)
    }

    private func cardShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(0.10),
                                        .clear,
                                        .black.opacity(0.04),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.12), lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.8), accent.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .padding(.vertical, 12)
                    .padding(.leading, 8)
            }
            .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 5)
    }

    private var contractsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mission Contracts", systemImage: "signature")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(primaryText)
                .padding(.horizontal, 4)

            ForEach(visibleContracts) { contract in
                contractRow(contract: contract)
            }
        }
    }

    private func contractRow(contract: ChaosContract) -> some View {
        let state = generateViewModel.contractMissionState(for: contract)
        return cardShell {
            HStack(alignment: .top, spacing: 16) {
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
                    HStack(spacing: 8) {
                        contractStatusPill(state: state)
                        if let category = contract.category {
                            statPill(title: category.title, systemImage: category.icon)
                        }
                        if let tone = contract.tone {
                            statPill(title: tone.title, systemImage: "dial.medium")
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer()

                Button {
                    generateViewModel.trackChaosHubAction("accept_contract_\(contract.id)")
                    generateViewModel.acceptChaosContract(contract)
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    onDataChanged()
                    onOpenTab(.generate)
                } label: {
                    Text(state.isComplete ? "Done" : (state.isActive ? "Active" : "Accept"))
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                                .fill(state.isComplete ? secondaryText.opacity(0.12) : accent)
                        )
                        .foregroundStyle(state.isComplete ? secondaryText : buttonText)
                }
                .disabled(state.isComplete)
                .accessibilityLabel("Accept contract: \(contract.title)")
            }
        }
    }

    private func visibleContractSet() -> [ChaosContract] {
        let catalog = ChaosContract.catalog
        if let activeID = generateViewModel.activeChaosContractID,
           let active = catalog.first(where: { $0.id == activeID }) {
            let others = catalog.filter { $0.id != activeID }.shuffled().prefix(1)
            return [active] + Array(others)
        }
        return Array(catalog.shuffled().prefix(2))
    }

    private func contractStatusPill(state: GenerateViewModel.ContractMissionState) -> some View {
        let title: String
        let icon: String
        if state.rewardClaimed {
            title = "Reward claimed"
            icon = "checkmark.seal.fill"
        } else if state.isActive {
            title = "\(state.currentCount)/\(state.targetCount) active"
            icon = "bolt.fill"
        } else {
            title = "\(state.currentCount)/\(state.targetCount)"
            icon = "signature"
        }
        return Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(state.rewardClaimed || state.isActive ? accent : secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill((state.rewardClaimed || state.isActive ? accent : secondaryText).opacity(0.1))
            )
    }
}

// MARK: - Mission Formula Sheet

private struct ChaosFormulaSheet: View {
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color
    let accent: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Mission Score Formula", systemImage: "function")
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

private enum MissionPathState {
    case done
    case now
    case next

    var label: String {
        switch self {
        case .done: return "Done"
        case .now: return "Now"
        case .next: return "Next"
        }
    }

    var iconName: String {
        switch self {
        case .done: return "checkmark.circle.fill"
        case .now: return "arrow.right.circle.fill"
        case .next: return "circle"
        }
    }

    func tint(accent: Color) -> Color {
        switch self {
        case .done: return .green
        case .now: return accent
        case .next: return .secondary
        }
    }
}
