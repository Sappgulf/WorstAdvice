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

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        challengeCommandCard

                        if !activeChallenges.isEmpty {
                            activeChallengesSection
                        }
                        if !completedChallenges.isEmpty {
                            completedChallengesSection
                        }
                        if activeChallenges.isEmpty && completedChallenges.isEmpty {
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(accent)
                    }
                    .accessibilityLabel("Create challenge")
                    .accessibilityIdentifier("groupChallenges.toolbarCreate")
                }
            }
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
                    generateViewModel.selectedCategory = challenge.category
                    generateViewModel.selectedTone = challenge.tone
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
                            .clipShape(Capsule())
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
                            .clipShape(Capsule())
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
            Text("Challenge Your Friends")
                .font(.title2.bold())
                .foregroundStyle(primaryText)
            Text("Create local challenge rooms, copy a real invite code, and launch the matching category in Advice.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    showCreateSheet = true
                } label: {
                    Label("Create", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .accessibilityIdentifier("groupChallenges.headerCreate")

                Button {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    showJoinAlert = true
                } label: {
                    Label("Join by Code", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .accessibilityIdentifier("groupChallenges.headerJoin")
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius + 4, style: .continuous)
                .fill(cardColor.opacity(0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius + 4, style: .continuous)
                        .stroke(accent.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var challengeCommandCard: some View {
        TabCommandCard(
            eyebrow: "Challenge Command",
            title: challengeCommandTitle,
            detail: challengeCommandDetail,
            systemImage: "person.3.fill",
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
                    title: "Friends",
                    value: "\(social.friends.count)",
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText
                )
            }
        } actions: {
            HStack(spacing: 10) {
                Button {
                    performChallengePrimaryAction()
                } label: {
                    Label(challengePrimaryActionTitle, systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .foregroundStyle(buttonText)
                .accessibilityIdentifier("groupChallenges.command.primary")

                Button {
                    HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                    showJoinAlert = true
                } label: {
                    Label("Join", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.bordered)
                .tint(accent)
                .accessibilityIdentifier("groupChallenges.command.join")
            }
        }
        .accessibilityIdentifier("groupChallenges.command.card")
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(secondaryText)
            Text("No Active Challenges")
                .font(.headline)
                .foregroundStyle(primaryText)
            Text("Create a challenge or join one with a friend's invite code.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.1), lineWidth: 1)
                )
        )
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
                    onPlay: {
                        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
                        generateViewModel.selectedCategory = challenge.category
                        generateViewModel.selectedTone = challenge.tone
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
            return "Create the first challenge"
        }
        if social.currentUser == nil {
            return "Local challenges are ready"
        }
        if social.friends.isEmpty {
            return "Share a code with your first friend"
        }
        return "Run the next challenge round"
    }

    private var challengeCommandDetail: String {
        if activeChallenges.isEmpty {
            return "Create a challenge, keep the invite code, and play it from Advice with the selected category and tone."
        }
        if social.currentUser == nil {
            return "These are on-device challenge rooms. Set up Friends when you want the wider social loop."
        }
        if social.friends.isEmpty {
            return "You can still create and play locally. Add friends to make codes, rankings, and shared drafts matter."
        }
        return "Open the active challenge, copy its code, or start the matching Advice run."
    }

    private var challengePrimaryActionTitle: String {
        activeChallenges.isEmpty ? "Create Challenge" : "Play Active"
    }

    private func performChallengePrimaryAction() {
        HapticsManager.playSelection(isEnabled: settings.hapticsEnabled)
        guard let challenge = activeChallenges.first else {
            showCreateSheet = true
            return
        }
        generateViewModel.selectedCategory = challenge.category
        generateViewModel.selectedTone = challenge.tone
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
                    .clipShape(Capsule())
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
        .background(cardColor.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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

    var body: some View {
        NavigationStack {
            List {
                Section("Challenge Info") {
                    LabeledContent("Category", value: challenge.category.title)
                    LabeledContent("Tone", value: challenge.tone.title)
                    LabeledContent("Invite Code") {
                        Button {
                            onCopyCode()
                        } label: {
                            Text(challenge.inviteCode)
                                .font(.body.monospaced().bold())
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("groupChallenges.detail.copyCode")
                    }
                    LabeledContent("Ends") {
                        Text(challenge.endsAt, style: .relative)
                            .foregroundStyle(secondaryText)
                    }
                }
                Section("Leaderboard") {
                    ForEach(Array(challenge.leaderboard.sorted { $0.score > $1.score }.enumerated()), id: \.element.id) { rank, entry in
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
                    Button(action: onPlay) {
                        Label("Play Now", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(accent)
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
                        .background(Color.green)
                        .clipShape(Capsule())
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

            leaderboardSection

            VStack(spacing: 8) {
                Button(action: onPlay) {
                    Label("Play Now", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .accessibilityIdentifier("groupChallenges.card.play")

                HStack(spacing: 8) {
                    Button(action: onCopyCode) {
                        Label(isCopied ? "Copied" : "Copy Code", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                    .accessibilityIdentifier("groupChallenges.card.copyCode")
                    .accessibilityLabel(isCopied ? "Copied challenge code" : "Copy challenge code")
                    .accessibilityValue(isCopied ? "Copied \(challenge.inviteCode)" : challenge.inviteCode)
                    .accessibilityAction { onCopyCode() }

                    Button(action: onDetails) {
                        Image(systemName: "info.circle")
                            .font(.headline)
                            .foregroundStyle(accent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Challenge details")
                    .accessibilityIdentifier("groupChallenges.card.details")
                }
            }
        }
        .padding(14)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
