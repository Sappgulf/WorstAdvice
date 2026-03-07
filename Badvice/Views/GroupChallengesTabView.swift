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

    @State private var activeChallenges: [GroupChallenge] = []
    @State private var completedChallenges: [GroupChallenge] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var inviteCodeInput = ""
    @State private var showJoinAlert = false
    @State private var selectedChallenge: GroupChallenge?
    @State private var showWinnerReveal = false
    @State private var copiedCode: String?

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient(for: settings.theme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection

                        if isLoading {
                            loadingView
                        } else {
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
                    }
                    .padding()
                }
            }
            .navigationTitle("Group Challenges")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(accent)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateChallengeSheet(onCreate: { challenge in
                    activeChallenges.append(challenge)
                    scheduleNotificationForChallenge(challenge)
                })
            }
            .sheet(item: $selectedChallenge) { challenge in
                ChallengeDetailSheet(
                    challenge: challenge,
                    settings: settings,
                    onPlay: {
                        generateViewModel.selectedCategory = challenge.category
                        generateViewModel.selectedTone = challenge.tone
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
                if let code = copiedCode {
                    VStack {
                        Spacer()
                        Text("Code "\(code)" copied!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(accent)
                            .clipShape(Capsule())
                            .padding(.bottom, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Theme.springSmooth, value: copiedCode)
                }
            }
            .task { await loadChallenges() }
            .refreshable { await loadChallenges() }
        }
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Challenge Your Friends")
                .font(.title2.bold())
                .foregroundStyle(primaryText)
            Text("Create or join group challenges to compete for the worst advice")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
            HStack(spacing: 10) {
                Button {
                    showCreateSheet = true
                } label: {
                    Label("Create", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)

                Button {
                    showJoinAlert = true
                } label: {
                    Label("Join by Code", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(accent)
            }
            .padding(.top, 4)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(accent)
            Text("Loading challenges…")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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
        .padding(.vertical, 40)
    }

    private var activeChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Active", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(accent)

            ForEach(activeChallenges) { challenge in
                ChallengeCard(
                    challenge: challenge,
                    accent: accent,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    cardColor: cardColor,
                    onPlay: {
                        generateViewModel.selectedCategory = challenge.category
                        generateViewModel.selectedTone = challenge.tone
                        onOpenTab(.generate)
                    },
                    onCopyCode: {
                        UIPasteboard.general.string = challenge.inviteCode
                        withAnimation { copiedCode = challenge.inviteCode }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copiedCode = nil }
                        }
                    },
                    onDetails: { selectedChallenge = challenge }
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
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Demo active challenges — in production this queries CloudKit GroupChallenge records.
        activeChallenges = [
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

        // Demo completed challenge with winner reveal
        completedChallenges = [
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

        isLoading = false
    }

    private func joinChallenge() {
        let code = inviteCodeInput.trimmingCharacters(in: .whitespaces).uppercased()
        guard code.count == 6 else { return }
        // In production: query CloudKit for a GroupChallenge record with inviteCode == code,
        // then add the current user to participantIDs and reload.
        inviteCodeInput = ""
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
                            UIPasteboard.general.string = challenge.inviteCode
                        } label: {
                            Text(challenge.inviteCode)
                                .font(.body.monospaced().bold())
                                .foregroundStyle(accent)
                        }
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

            HStack(spacing: 10) {
                Button(action: onPlay) {
                    Label("Play Now", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)

                Button(action: onCopyCode) {
                    Label(challenge.inviteCode, systemImage: "doc.on.doc")
                        .font(.caption.monospaced().weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(accent)

                Button(action: onDetails) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
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
    
    @State private var name = ""
    @State private var selectedCategory: AdviceCategory = .dating
    @State private var selectedTone: ToneMode = .toxicBestFriend
    @State private var duration: Int = 7
    
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
                    
                    Text(String(UUID().uuidString.prefix(6)).uppercased())
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
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createChallenge()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createChallenge() {
        let challenge = GroupChallenge(
            id: UUID(),
            name: name,
            inviteCode: String(UUID().uuidString.prefix(6)).uppercased(),
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
