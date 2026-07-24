import SwiftUI

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct GroupChallengesTabView: View {
    let social: SocialViewModel
    let generateViewModel: GenerateViewModel
    let settings: SettingsViewModel
    let onOpenTab: (AppTab) -> Void
    private let isFocusMode = false

    @State private var activeChallenges: [GroupChallenge] = Self.demoActiveChallenges
    @State private var completedChallenges: [GroupChallenge] = Self.demoCompletedChallenges
    @State private var showCreateSheet = false
    @State private var inviteCodeInput = ""
    @State private var showJoinAlert = false
    @State private var selectedChallenge: GroupChallenge?
    @State private var copiedCode: String?
    @State private var joinFeedback: String?
    @State private var copiedCodeDismissTask: Task<Void, Never>?
    @State private var joinFeedbackDismissTask: Task<Void, Never>?
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var isMotionReduced: Bool { settings.reduceMotion || settings.performanceMode || accessibilityReduceMotion }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !isFocusMode {
                            headerSection
                        }
                        challengeCommandCard

                        if !activeChallenges.isEmpty {
                            activeChallengesSection
                        }
                        if !isFocusMode && !completedChallenges.isEmpty {
                            completedChallengesSection
                        }
                        if isFocusMode && activeChallenges.isEmpty {
                            emptyStateView
                        } else if activeChallenges.isEmpty && completedChallenges.isEmpty {
                            emptyStateView
                        }
                    }
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 24)
                }
                .trackScrollForTabBar()
            }
            .navigationTitle("Group Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreateSheet) {
                CreateChallengeSheet(onCreate: { challenge in
                    activeChallenges.append(challenge)
                    scheduleNotificationForChallenge(challenge)
                }, hapticsEnabled: settings.hapticsEnabled)
            }
            .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailSheet(
                challenge: challenge,
                settings: settings,
                onCopyCode: {
                    UIPasteboard.general.string = challenge.inviteCode
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    copiedCode = challenge.inviteCode
                    copiedCodeDismissTask?.cancel()
                    copiedCodeDismissTask = Task { @MainActor in
                        defer { copiedCodeDismissTask = nil }
                        try? await Task.sleep(for: .seconds(5))
                        guard !Task.isCancelled else { return }
                        withAnimation { copiedCode = nil }
                    }
                },
                onPlay: {
                    generateViewModel.updateSelections(
                        category: challenge.category,
                        tone: challenge.tone,
                        autoGenerate: true
                    )
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    onOpenTab(.generate)
                }
            )
            }
            .alert("Join Challenge", isPresented: $showJoinAlert) {
                TextField("Invite Code", text: $inviteCodeInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                Button("Cancel", role: .cancel) {}
                Button("Join") { joinChallenge() }
            } message: {
                Text("Enter the 6-character invite code to join a group challenge.")
            }
            .overlay {
                VStack {
                    Spacer()
                    if let code = copiedCode {
                        Text("Code \"\(code)\" copied!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(accent)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous))
                            .padding(.bottom, 32)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .accessibilityIdentifier("groupChallenges.copyStatus")
                    } else if let feedback = joinFeedback {
                        Text(feedback)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous))
                            .padding(.bottom, 32)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(Theme.springSmooth, value: copiedCode)
                .animation(Theme.springSmooth, value: joinFeedback)
            }
            .onDisappear {
                copiedCodeDismissTask?.cancel()
                copiedCodeDismissTask = nil
                joinFeedbackDismissTask?.cancel()
                joinFeedbackDismissTask = nil
            }
            .task { await loadChallenges() }
            .refreshable { await loadChallenges() }
            .onAppear {
                tabBarVisible.wrappedValue = true
            }
        }
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Friends Arena", systemImage: "flag.checkered")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(accent)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.bottom, 2)
            Text("Challenge Your Friends")
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(primaryText)
            Text("Spin up local challenge rooms, share an invite code, and stamp matching takes together.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                TabCommandActionButton(
                    title: "Create",
                    systemImage: "plus",
                    accent: accent,
                    buttonText: buttonText,
                    accessibilityIdentifier: "groupChallenges.headerCreate"
                ) {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    showCreateSheet = true
                }

                TabCommandActionButton(
                    title: "Join by Code",
                    systemImage: "person.badge.plus",
                    accent: accent,
                    buttonText: buttonText,
                    prominent: false,
                    accessibilityIdentifier: "groupChallenges.headerJoin"
                ) {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    showJoinAlert = true
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius + 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [cardColor.opacity(0.92), cardColor.opacity(0.84), cardColor.opacity(0.74)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [accent.opacity(0.08), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius + 4, style: .continuous)
                        .stroke(accent.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius + 4, style: .continuous)
                        .fill(accent.opacity(0.09))
                        .frame(height: 1.2),
                    alignment: .top
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    private var challengeCommandCard: some View {
        TabCommandCard(
            eyebrow: "Friends Command",
            title: challengeCommandTitle,
            detail: challengeCommandDetail,
            systemImage: "flag.checkered",
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor
        ) {
            HStack(spacing: 8) {
                TabCommandMetric(
                    title: "Active",
                    value: "\(activeChallenges.count)",
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText
                )
                TabCommandMetric(
                    title: "Done",
                    value: "\(completedChallenges.count)",
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText
                )
                TabCommandMetric(
                    title: "Next",
                    value: activeChallenges.isEmpty ? "Create" : "Generate",
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText
                )
            }
        } actions: {
            HStack(spacing: 10) {
                TabCommandActionButton(
                    title: challengePrimaryActionTitle,
                    systemImage: "play.fill",
                    accent: accent,
                    buttonText: buttonText,
                    accessibilityIdentifier: "groupChallenges.command.primary"
                ) {
                    performChallengePrimaryAction()
                }

                if !isFocusMode {
                    TabCommandActionButton(
                        title: "Join",
                        systemImage: "person.badge.plus",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: false,
                        accessibilityIdentifier: "groupChallenges.command.join"
                    ) {
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        showJoinAlert = true
                    }
                }
            }
        }
        .accessibilityIdentifier("groupChallenges.command.card")
    }

    private var emptyStateView: some View {
        TabEmptyStatePanel(
            icon: "person.3.fill",
            title: "No missions on the board.",
            message: "Start a group challenge or join with a friend's invite code. Shared chaos scores better in company.",
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor,
            reduceMotion: isMotionReduced
        ) {
            HStack(spacing: 10) {
                TabCommandActionButton(
                    title: "Create Mission",
                    systemImage: "plus",
                    accent: accent,
                    buttonText: buttonText,
                    accessibilityIdentifier: "groupChallenges.empty.create"
                ) {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    showCreateSheet = true
                }

                TabCommandActionButton(
                    title: "Join by Code",
                    systemImage: "person.badge.plus",
                    accent: accent,
                    buttonText: buttonText,
                    prominent: false,
                    accessibilityIdentifier: "groupChallenges.empty.join"
                ) {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    showJoinAlert = true
                }
            }
        }
    }

    private var activeChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Active", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(accent)

            ForEach(activeChallenges) { challenge in
                ChallengeCard(
                    challenge: challenge,
                    isCopied: copiedCode == challenge.inviteCode,
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    cardColor: cardColor,
                    buttonText: buttonText,
                    onPlay: {
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        generateViewModel.updateSelections(
                            category: challenge.category,
                            tone: challenge.tone,
                            autoGenerate: true
                        )
                        onOpenTab(.generate)
                    },
                    onCopyCode: {
                        UIPasteboard.general.string = challenge.inviteCode
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        copiedCode = challenge.inviteCode
                        copiedCodeDismissTask?.cancel()
                        copiedCodeDismissTask = Task { @MainActor in
                            defer { copiedCodeDismissTask = nil }
                            try? await Task.sleep(for: .seconds(5))
                            guard !Task.isCancelled else { return }
                            withAnimation { copiedCode = nil }
                        }
                    },
                    onDetails: {
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        selectedChallenge = challenge
                    }
                )
            }
        }
    }

    private var completedChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Completed", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(secondaryText)

            ForEach(completedChallenges) { challenge in
                CompletedChallengeCard(
                    challenge: challenge,
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    cardColor: cardColor
                )
            }
        }
    }

    private func loadChallenges() async {
        guard activeChallenges.isEmpty && completedChallenges.isEmpty else { return }

        activeChallenges = Self.demoActiveChallenges
        completedChallenges = Self.demoCompletedChallenges
    }

    private var challengeCommandTitle: String {
        if activeChallenges.isEmpty {
            return "Create a mission"
        }
        if social.currentUser == nil {
            return "Solo mission ready"
        }
        if social.friends.isEmpty {
            return "Run it solo first"
        }
        return "Run the next mission"
    }

    private var challengeCommandDetail: String {
        if activeChallenges.isEmpty {
            return "Create a concrete action like generate three badvices in one lane, save the best one, then share or remix it."
        }
        if social.currentUser == nil {
            return "Tap Run Mission to jump into Generate with the mission category and tone. Friends can wait."
        }
        if social.friends.isEmpty {
            return "Run the mission locally, then copy or share the best result. Add friends only when you want rankings."
        }
        return "Open the active mission, copy its code, or start the matching Advice run."
    }

    private var challengePrimaryActionTitle: String {
        activeChallenges.isEmpty ? "Create Mission" : "Run Mission"
    }

    private func performChallengePrimaryAction() {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        guard let challenge = activeChallenges.first else {
            showCreateSheet = true
            return
        }
        generateViewModel.updateSelections(
            category: challenge.category,
            tone: challenge.tone,
            autoGenerate: true
        )
        onOpenTab(.generate)
    }

    private static var demoActiveChallenges: [GroupChallenge] {
        [
            GroupChallenge(
                id: UUID(),
                name: "Dating Disaster Week",
                inviteCode: "LOVE12",
                category: .dating,
                tone: .toxicBestFriend,
                creatorID: "user123",
                participantIDs: ["user1", "user2", "user3"],
                startedAt: Date().addingTimeInterval(-86400 * 2),
                endsAt: Date().addingTimeInterval(86400 * 5),
                leaderboard: [
                    ChallengeEntry(id: UUID(), userID: "user1", userName: "Alex", adviceCount: 12, totalLikes: 45),
                    ChallengeEntry(id: UUID(), userID: "user2", userName: "Sam", adviceCount: 8, totalLikes: 32),
                    ChallengeEntry(id: UUID(), userID: "user3", userName: "Jordan", adviceCount: 5, totalLikes: 18),
                ]
            ),
        ]
    }

    private static var demoCompletedChallenges: [GroupChallenge] {
        [
            GroupChallenge(
                id: UUID(),
                name: "Career Chaos Challenge",
                inviteCode: "BOSS99",
                category: .career,
                tone: .corporateConsultant,
                creatorID: "user123",
                participantIDs: ["user1", "user2"],
                startedAt: Date().addingTimeInterval(-86400 * 10),
                endsAt: Date().addingTimeInterval(-86400),
                leaderboard: [
                    ChallengeEntry(id: UUID(), userID: "user1", userName: "Alex", adviceCount: 22, totalLikes: 88),
                    ChallengeEntry(id: UUID(), userID: "user2", userName: "Sam", adviceCount: 15, totalLikes: 61),
                ]
            ),
        ]
    }

    private func joinChallenge() {
        let code = inviteCodeInput.trimmingCharacters(in: .whitespaces).uppercased()
        inviteCodeInput = ""
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        guard code.count == 6 else {
            showJoinFeedback("Code must be 6 characters.")
            return
        }
        // Check active challenges first, then show not-found feedback.
        if let match = activeChallenges.first(where: { $0.inviteCode == code }) {
            selectedChallenge = match
        } else {
            showJoinFeedback("No challenge found for code \"\(code)\".")
        }
    }

    private func showJoinFeedback(_ message: String) {
        withAnimation { joinFeedback = message }
        joinFeedbackDismissTask?.cancel()
        joinFeedbackDismissTask = Task { @MainActor in
            defer { joinFeedbackDismissTask = nil }
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation { joinFeedback = nil }
        }
    }

    private func scheduleNotificationForChallenge(_ challenge: GroupChallenge) {
        NotificationManager.scheduleDailyChallengeNotification(
            title: challenge.name,
            category: challenge.category,
            tone: challenge.tone
        )
    }
}

// MARK: - Completed Challenge Card

private struct CompletedChallengeCard: View {
    let challenge: GroupChallenge
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color

    var winner: ChallengeEntry? {
        challenge.leaderboard.max { $0.score < $1.score }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(challenge.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                Text("Ended")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous))
            }
            if let winner {
                HStack(spacing: 6) {
                    Text("🏆")
                    Text("\(winner.userName) won")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                    Text("· \(winner.score) pts")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [cardColor.opacity(0.8), cardColor.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.mediumCornerRadius, style: .continuous)
                .fill(accent.opacity(0.06))
                .frame(height: 1),
            alignment: .top
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Challenge Detail Sheet

private struct ChallengeDetailSheet: View {
    let challenge: GroupChallenge
    let settings: SettingsViewModel
    let onCopyCode: () -> Void
    let onPlay: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var rankedEntries: [ChallengeEntry] {
        Array(challenge.leaderboard.sorted { $0.score > $1.score }.prefix(3))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Challenge Info") {
                    LabeledContent("Category", value: challenge.category.title)
                    LabeledContent("Tone", value: challenge.tone.title)
                    LabeledContent("Invite Code") {
                        TabCommandActionButton(
                            title: challenge.inviteCode,
                            systemImage: "doc.on.doc",
                            accent: accent,
                            buttonText: Theme.buttonText(for: settings.theme),
                            prominent: false
                        ) {
                            onCopyCode()
                        }
                        .font(.body.monospaced().bold())
                        .accessibilityIdentifier("groupChallenges.detail.copyCode")
                    }
                    LabeledContent("Ends") {
                        Text(challenge.endsAt, style: .relative)
                            .foregroundStyle(secondaryText)
                    }
                }
                Section("Leaderboard") {
                    ForEach(Array(rankedEntries.enumerated()), id: \.element.id) { rank, entry in
                        HStack {
                            Text(rankEmoji(rank + 1))
                            Text(entry.userName).font(.body.weight(.semibold)).foregroundStyle(primaryText)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(entry.score) pts").font(.subheadline.weight(.bold)).foregroundStyle(accent)
                                Text("\(entry.adviceCount) advice · \(entry.totalLikes) likes")
                                    .font(.caption).foregroundStyle(secondaryText)
                            }
                        }
                    }
                }
                Section {
                    TabCommandActionButton(
                        title: "Play Now",
                        systemImage: "play.fill",
                        accent: accent,
                        buttonText: Theme.buttonText(for: settings.theme)
                    ) {
                        onPlay()
                    }
                    .accessibilityIdentifier("groupChallenges.detail.play")
                }
            }
            .navigationTitle(challenge.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func rankEmoji(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)."
        }
    }
}

struct ChallengeCard: View {
    let challenge: GroupChallenge
    let isCopied: Bool
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let cardColor: Color
    let buttonText: Color
    let onPlay: () -> Void
    let onCopyCode: () -> Void
    let onDetails: () -> Void

    private var daysLeft: Int {
        max(0, Int(challenge.endsAt.timeIntervalSinceNow / 86400))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.name)
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    HStack(spacing: 4) {
                        Label(challenge.category.title, systemImage: challenge.category.icon)
                        Text("·")
                        Label(challenge.tone.title, systemImage: "text.bubble")
                    }
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                }
                Spacer()
                if challenge.isActive {
                    Text("Active")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green.opacity(0.9), Color.green.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.compactCornerRadius, style: .continuous))
                }
            }

            HStack {
                Label("\(challenge.participantIDs.count) players", systemImage: "person.2")
                    .foregroundStyle(secondaryText)
                Spacer()
                Text(daysLeft == 0 ? "Ends today" : "\(daysLeft)d left")
                    .foregroundStyle(daysLeft <= 1 ? .orange : secondaryText)
            }
            .font(.caption)
            .padding(.bottom, 2)

            leaderboardSection

            VStack(spacing: 8) {
                TabCommandActionButton(
                    title: "Play Now",
                    systemImage: "play.fill",
                    accent: accent,
                    buttonText: buttonText
                ) {
                    onPlay()
                }
                .accessibilityIdentifier("groupChallenges.card.play")

                HStack(spacing: 8) {
                    TabCommandActionButton(
                        title: isCopied ? "Copied" : "Copy Code",
                        systemImage: isCopied ? "checkmark" : "doc.on.doc",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: isCopied,
                        minHeight: 44
                    ) {
                        onCopyCode()
                    }
                    .accessibilityIdentifier("groupChallenges.card.copyCode")
                    .accessibilityLabel(isCopied ? "Copied challenge code" : "Copy challenge code")
                    .accessibilityValue(isCopied ? "Copied \(challenge.inviteCode)" : challenge.inviteCode)
                    .accessibilityAction { onCopyCode() }

                    TabCommandActionButton(
                        title: "Details",
                        systemImage: "info.circle",
                        accent: accent,
                        buttonText: buttonText,
                        prominent: false,
                        minHeight: 44
                    ) {
                        onDetails()
                    }
                    .accessibilityLabel("Challenge details")
                    .accessibilityIdentifier("groupChallenges.card.details")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.tileCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [cardColor.opacity(0.92), cardColor.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [accent.opacity(0.1), .clear, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.tileCornerRadius, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.tileCornerRadius, style: .continuous)
                .fill(accent.opacity(0.08))
                .frame(height: 1.1),
            alignment: .top
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Leaderboard")
                .font(.caption.bold())
                .foregroundStyle(secondaryText)

            ForEach(Array(challenge.leaderboard.sorted { $0.score > $1.score }.prefix(3).enumerated()), id: \.element.id) { idx, entry in
                HStack(spacing: 6) {
                    Text(["🥇", "🥈", "🥉"][safe: idx] ?? "\(idx + 1).")
                        .font(.caption)
                    Text(entry.userName)
                        .font(.subheadline)
                        .foregroundStyle(primaryText)
                    Spacer()
                    Text("\(entry.score) pts")
                        .font(.subheadline.bold())
                        .foregroundStyle(accent)
                }
            }
        }
    }
}

struct CreateChallengeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onCreate: (GroupChallenge) -> Void
    let hapticsEnabled: Bool

    @State private var name = ""
    @State private var selectedCategory: AdviceCategory = .dating
    @State private var selectedTone: ToneMode = .toxicBestFriend
    @State private var duration: Int = 7
    @State private var inviteCode = String(UUID().uuidString.prefix(6)).uppercased()

    var body: some View {
        NavigationStack {
            Form {
                Section("Challenge Details") {
                    TextField("Challenge Name", text: $name)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(AdviceCategory.concrete) { category in
                            Label(category.title, systemImage: category.icon)
                                .tag(category)
                        }
                    }

                    Picker("Tone", selection: $selectedTone) {
                        ForEach(ToneMode.concrete) { tone in
                            Text(tone.title).tag(tone)
                        }
                    }

                    Picker("Duration", selection: $duration) {
                        Text("3 days").tag(3)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                    }
                }

                Section {
                    Text("Share this code with friends to join:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(inviteCode)
                        .font(.title2.monospaced().bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .navigationTitle("Create Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.playSelection(isEnabled: hapticsEnabled)
                        dismiss()
                    }
                    .accessibilityIdentifier("groupChallenges.create.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        HapticsManager.playSelection(isEnabled: hapticsEnabled)
                        createChallenge()
                    }
                    .disabled(name.isEmpty)
                    .accessibilityIdentifier("groupChallenges.create.submit")
                }
            }
        }
    }

    private func createChallenge() {
        let challenge = GroupChallenge(
            id: UUID(),
            name: name,
            inviteCode: inviteCode,
            category: selectedCategory,
            tone: selectedTone,
            creatorID: "currentUser",
            participantIDs: ["currentUser"],
            startedAt: Date(),
            endsAt: Date().addingTimeInterval(Double(duration) * 86400),
            leaderboard: []
        )
        onCreate(challenge)
        dismiss()
    }
}
