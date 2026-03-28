import SwiftUI

// MARK: - Friend Activity Feed

struct FriendActivityFeedView: View {
    let activities: [FriendActivity]
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Friend Activity")
                    .font(.title2.weight(.bold))
                Spacer()
                Button(action: { isLoading = true }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding(.horizontal)
            
            if activities.isEmpty {
                EmptyStateView(.noFriends)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(activities) { activity in
                            FriendActivityRow(activity: activity)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .refreshable {
            // Refresh logic here
        }
    }
}

struct FriendActivityRow: View {
    let activity: FriendActivity
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(activity.actionColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: activity.actionIcon)
                    .foregroundStyle(activity.actionColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.userName)
                    .font(.subheadline.weight(.semibold))
                +
                Text(" \(activity.actionText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(activity.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            if let advicePreview = activity.advicePreview {
                Text(advicePreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 80)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
}

struct FriendActivity: Identifiable {
    let id: UUID
    let userName: String
    let userAvatar: String?
    let action: ActivityAction
    let advicePreview: String?
    let timestamp: Date
    
    var actionIcon: String {
        switch action {
        case .generated: return "wand.and.stars"
        case .saved: return "bookmark.fill"
        case .shared: return "square.and.arrow.up.fill"
        case .achieved: return "trophy.fill"
        case .streak: return "flame.fill"
        }
    }
    
    var actionColor: Color {
        switch action {
        case .generated: return .blue
        case .saved: return .green
        case .shared: return .orange
        case .achieved: return .purple
        case .streak: return .red
        }
    }
    
    var actionText: String {
        switch action {
        case .generated: return "generated new advice"
        case .saved: return "saved advice to favorites"
        case .shared: return "shared advice with friends"
        case .achieved: return "unlocked an achievement"
        case .streak: return "hit a new streak"
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

enum ActivityAction {
    case generated
    case saved
    case shared
    case achieved
    case streak
}

// MARK: - Leaderboard View

struct LeaderboardView: View {
    let entries: [LeaderboardEntry]
    let currentUserRank: Int
    @State private var selectedPeriod: LeaderboardPeriod = .weekly
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Period", selection: $selectedPeriod) {
                Text("Daily").tag(LeaderboardPeriod.daily)
                Text("Weekly").tag(LeaderboardPeriod.weekly)
                Text("All Time").tag(LeaderboardPeriod.allTime)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if let currentUser = entries.first(where: { $0.isCurrentUser }) {
                CurrentUserRankCard(entry: currentUser, rank: currentUserRank)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        LeaderboardRow(entry: entry, rank: index + 1)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Leaderboard")
    }
}

struct CurrentUserRankCard: View {
    let entry: LeaderboardEntry
    let rank: Int
    
    var body: some View {
        HStack(spacing: 16) {
            Text("#\(rank)")
                .font(.title2.weight(.bold))
                .foregroundStyle(rankColor)
                .frame(width: 50)
            
            Image(systemName: "person.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("You")
                    .font(.headline)
                Text("\(entry.score) points")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if rank <= 3 {
                Image(systemName: rankIcon)
                    .font(.title)
                    .foregroundStyle(rankColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "trophy.fill"
        case 2: return "medal.fill"
        case 3: return "rosette.fill"
        default: return ""
        }
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(rank <= 3 ? rankColor : .secondary)
                .frame(width: 40)
            
            Image(systemName: "person.fill")
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color.gray.opacity(0.2))
                .clipShape(Circle())
            
            Text(entry.userName)
                .font(.subheadline.weight(.medium))
            
            Spacer()
            
            Text("\(entry.score)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.accentColor)
            
            Text("pts")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(rank <= 3 ? rankColor.opacity(0.1) : Color(.systemBackground))
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .clear
        }
    }
}

struct LeaderboardEntry: Identifiable {
    let id: UUID
    let userName: String
    let userAvatar: String?
    let score: Int
    let adviceCount: Int
    let isCurrentUser: Bool
}

enum LeaderboardPeriod {
    case daily, weekly, allTime
}

// MARK: - Onboarding Tutorial View

struct OnboardingTutorialView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var showTip = false
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "wand.and.stars",
            title: "Welcome to Badvice",
            description: "Get terrible advice for every situation in life. The worse, the better."
        ),
        OnboardingPage(
            icon: "slider.horizontal.3",
            title: "Customize Your Chaos",
            description: "Choose from different tones and categories to get exactly the wrong advice you need."
        ),
        OnboardingPage(
            icon: "bookmark",
            title: "Save Your Favorites",
            description: "Build a collection of the worst gems you can't live without."
        ),
        OnboardingPage(
            icon: "trophy",
            title: "Earn Achievements",
            description: "Complete challenges, maintain streaks, and unlock special themes."
        ),
        OnboardingPage(
            icon: "iphone.gen3.radiowaves.left.and.right",
            title: "Shake to Generate",
            description: "Shake your phone for instant terrible advice. Try it!"
        )
    ]
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 20)
                
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        isPresented = false
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(.accentColor)
            
            Text(page.title)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            
            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Weekly Goals Card

struct WeeklyGoalsCard: View {
    let goals: [WeeklyGoal]
    @State private var isExpanded = false
    
    var completedCount: Int {
        goals.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "target")
                        .font(.title2)
                        .foregroundStyle(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Goals")
                            .font(.headline)
                        Text("\(completedCount)/\(goals.count) completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                
                ForEach(goals) { goal in
                    WeeklyGoalRow(goal: goal)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
    }
}

struct WeeklyGoalRow: View {
    let goal: WeeklyGoal
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: goal.icon)
                .font(.title3)
                .foregroundStyle(goal.isCompleted ? .green : .accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.subheadline.weight(.medium))
                
                ProgressView(value: goal.progress)
                    .tint(goal.isCompleted ? .green : .accentColor)
            }
            
            Spacer()
            
            if goal.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("\(goal.currentValue)/\(goal.targetValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Daily Challenge Card

struct DailyChallengeCard: View {
    let challenge: DailyChallenge
    let isCompleted: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green.opacity(0.2) : Color.accentColor.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundStyle(.accentColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Challenge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(challenge.title)
                        .font(.headline)
                    
                    Text(challenge.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("+\(challenge.bonusPoints)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.accentColor)
                    
                    Text("XP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isCompleted ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isCompleted ? Color.green.opacity(0.3) : Color.accentColor.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - XP Progress Bar

struct XPProgressBar: View {
    let progress: XPProgress
    let showLabel: Bool
    
    init(progress: XPProgress, showLabel: Bool = true) {
        self.progress = progress
        self.showLabel = showLabel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showLabel {
                HStack {
                    Text("Level \(progress.level)")
                        .font(.subheadline.weight(.bold))
                    
                    Spacer()
                    
                    Text("\(progress.currentXP) / \(progress.xpForNextLevel) XP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [progress.currentLevel.color, progress.currentLevel.color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress.xpProgress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}
