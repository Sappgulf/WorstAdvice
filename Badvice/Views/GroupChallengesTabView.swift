import SwiftUI

struct GroupChallengesTabView: View {
    let social: SocialViewModel
    let generateViewModel: GenerateViewModel
    let settings: SettingsViewModel
    let onOpenTab: (AppTab) -> Void
    
    @State private var activeChallenges: [GroupChallenge] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var inviteCodeInput = ""
    @State private var showJoinAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    
                    if isLoading {
                        loadingView
                    } else if activeChallenges.isEmpty {
                        emptyStateView
                    } else {
                        activeChallengesSection
                    }
                }
                .padding()
            }
            .navigationTitle("Group Challenges")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateChallengeSheet(
                    onCreate: { challenge in
                        activeChallenges.append(challenge)
                    }
                )
            }
            .alert("Join Challenge", isPresented: $showJoinAlert) {
                TextField("Invite Code", text: $inviteCodeInput)
                Button("Cancel", role: .cancel) {}
                Button("Join") {
                    joinChallenge()
                }
            } message: {
                Text("Enter the invite code to join a group challenge")
            }
            .task {
                await loadChallenges()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Challenge Your Friends")
                .font(.title2.bold())
            Text("Create or join group challenges to compete for the worst advice")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading challenges...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Active Challenges")
                .font(.headline)
            
            Text("Create a new challenge or join one with an invite code")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button {
                    showCreateSheet = true
                } label: {
                    Label("Create", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    showJoinAlert = true
                } label: {
                    Label("Join", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var activeChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Challenges")
                .font(.headline)
            
            ForEach(activeChallenges) { challenge in
                ChallengeCard(challenge: challenge) {
                    generateViewModel.selectedCategory = challenge.category
                    generateViewModel.selectedTone = challenge.tone
                    onOpenTab(.generate)
                }
            }
        }
    }
    
    private func loadChallenges() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        activeChallenges = [
            GroupChallenge(
                id: UUID(),
                name: "Dating Disaster Week",
                inviteCode: "LOVE123",
                category: .dating,
                tone: .toxicBestFriend,
                creatorID: "user123",
                participantIDs: ["user1", "user2", "user3"],
                startedAt: Date().addingTimeInterval(-86400 * 2),
                endsAt: Date().addingTimeInterval(86400 * 5),
                leaderboard: [
                    ChallengeEntry(id: UUID(), userID: "user1", userName: "Alex", adviceCount: 12, totalLikes: 45),
                    ChallengeEntry(id: UUID(), userID: "user2", userName: "Sam", adviceCount: 8, totalLikes: 32),
                    ChallengeEntry(id: UUID(), userID: "user3", userName: "Jordan", adviceCount: 5, totalLikes: 18)
                ]
            )
        ]
        isLoading = false
    }
    
    private func joinChallenge() {
        // In real implementation, this would join via CloudKit
    }
}

struct ChallengeCard: View {
    let challenge: GroupChallenge
    let onPlay: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.name)
                        .font(.headline)
                    HStack {
                        Label(challenge.category.title, systemImage: challenge.category.icon)
                        Text("•")
                        Label(challenge.tone.title, systemImage: "text.bubble")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if challenge.isActive {
                    Text("Active")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
            
            HStack {
                Label("\(challenge.participantIDs.count) players", systemImage: "person.2")
                Spacer()
                Text("\(challenge.participantIDs.count) days left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            
            leaderboardSection
            
            Button(action: onPlay) {
                Text("Play Now")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Leaderboard")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            ForEach(challenge.leaderboard.prefix(3)) { entry in
                HStack {
                    Text(entry.userName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(entry.score) pts")
                        .font(.subheadline.bold())
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
