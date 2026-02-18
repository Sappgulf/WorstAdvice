import SwiftUI
import SwiftData

// MARK: - Achievements Manager

@Observable
final class AchievementsManager {
    private let context: ModelContext
    
    var achievements: [Achievement] = []
    var newlyUnlocked: [Achievement] = []
    var showUnlockCelebration = false
    
    // Tracking for achievements
    private var usedTones: Set<ToneMode> = []
    private var usedCategories: Set<AdviceCategory> = []
    private var hasUsedShake = false
    private var hasSubmittedSuggestion = false
    
    init(context: ModelContext) {
        self.context = context
        loadAchievements()
    }
    
    private func loadAchievements() {
        // Initialize all achievements if not already present
        let allTypes = AchievementType.allCases
        achievements = allTypes.map { type in
            Achievement(
                type: type,
                unlockedAt: nil,
                progress: 0,
                target: targetFor(type)
            )
        }
    }
    
    private func targetFor(_ type: AchievementType) -> Int {
        switch type {
        case .firstAdvice, .firstSave, .nightOwl, .earlyBird, .shakeItOff, .suggestionAccepted:
            return 1
        case .tenAdvice:
            return 10
        case .hundredAdvice:
            return 100
        case .collector:
            return 10
        case .hoarder:
            return 50
        case .sharer:
            return 5
        case .viral:
            return 25
        case .dailyStreak3:
            return 3
        case .dailyStreak7:
            return 7
        case .dailyStreak14:
            return 14
        case .dailyStreak30:
            return 30
        case .toneExplorer:
            return 11
        case .categoryMaster:
            return 10
        }
    }
    
    // MARK: - Achievement Tracking
    
    func trackAdviceGenerated(tone: ToneMode, category: AdviceCategory, totalCount: Int) {
        // Track unique tones and categories
        usedTones.insert(tone)
        usedCategories.insert(category)
        
        // Update progress for generation achievements
        updateProgress(.firstAdvice, to: min(totalCount, 1))
        updateProgress(.tenAdvice, to: min(totalCount, 10))
        updateProgress(.hundredAdvice, to: min(totalCount, 100))
        
        // Update tone and category achievements
        updateProgress(.toneExplorer, to: usedTones.count)
        updateProgress(.categoryMaster, to: usedCategories.count)
        
        // Check time-based achievements
        checkTimeBasedAchievements()
    }
    
    func trackAdviceSaved(totalSaved: Int) {
        updateProgress(.firstSave, to: min(totalSaved, 1))
        updateProgress(.collector, to: min(totalSaved, 10))
        updateProgress(.hoarder, to: min(totalSaved, 50))
    }
    
    func trackShare(totalShares: Int) {
        updateProgress(.sharer, to: min(totalShares, 5))
        updateProgress(.viral, to: min(totalShares, 25))
    }
    
    func trackStreak(days: Int) {
        updateProgress(.dailyStreak3, to: min(days, 3))
        updateProgress(.dailyStreak7, to: min(days, 7))
        updateProgress(.dailyStreak14, to: min(days, 14))
        updateProgress(.dailyStreak30, to: min(days, 30))
    }
    
    func trackShakeUsed() {
        guard !hasUsedShake else { return }
        hasUsedShake = true
        unlock(.shakeItOff)
    }
    
    func trackSuggestionSubmitted() {
        guard !hasSubmittedSuggestion else { return }
        hasSubmittedSuggestion = true
        unlock(.suggestionAccepted)
    }
    
    private func checkTimeBasedAchievements() {
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour >= 0 && hour < 6 {
            unlock(.nightOwl)
        }
        if hour >= 5 && hour < 8 {
            unlock(.earlyBird)
        }
    }
    
    // MARK: - Progress & Unlocking
    
    private func updateProgress(_ type: AchievementType, to value: Int) {
        guard let index = achievements.firstIndex(where: { $0.type == type }) else { return }
        guard achievements[index].unlockedAt == nil else { return }
        
        achievements[index].progress = value
        
        if value >= achievements[index].target {
            unlock(type)
        }
    }
    
    private func unlock(_ type: AchievementType) {
        guard let index = achievements.firstIndex(where: { $0.type == type }) else { return }
        guard achievements[index].unlockedAt == nil else { return }
        
        achievements[index].unlockedAt = Date()
        achievements[index].progress = achievements[index].target
        
        newlyUnlocked.append(achievements[index])
        showUnlockCelebration = true
    }
    
    func dismissCelebration() {
        showUnlockCelebration = false
        newlyUnlocked.removeAll()
    }
    
    // MARK: - Unlocked Themes
    
    var unlockedThemes: [ThemeMode] {
        var themes: [ThemeMode] = [.badvice, .minimal, .ember, .slate, .evergreen, .fallout] // Base themes
        
        for achievement in achievements where achievement.isUnlocked {
            if let theme = achievement.type.unlocksTheme {
                themes.append(theme)
            }
        }
        
        return themes
    }
    
    var unlockedThemeCount: Int {
        achievements.filter { $0.isUnlocked && $0.type.unlocksTheme != nil }.count
    }
    
    var totalAchievementCount: Int {
        AchievementType.allCases.count
    }
    
    var unlockedAchievementCount: Int {
        achievements.filter(\.isUnlocked).count
    }
    
    var completionPercentage: Double {
        Double(unlockedAchievementCount) / Double(totalAchievementCount)
    }
}

// MARK: - Achievement Celebration View

struct AchievementCelebrationView: View {
    let achievements: [Achievement]
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotation: Double = -10
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .opacity(opacity)
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 24) {
                // Trophy icon with animation
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.yellow, .orange, .red, .yellow],
                                center: .center
                            )
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(rotation))
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                }
                .scaleEffect(scale)
                
                VStack(spacing: 8) {
                    Text("Achievement Unlocked!")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    
                    ForEach(achievements) { achievement in
                        VStack(spacing: 4) {
                            Image(systemName: achievement.type.icon)
                                .font(.system(size: 32))
                                .foregroundStyle(.yellow)
                            
                            Text(achievement.type.title)
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            Text(achievement.type.description)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            if let theme = achievement.type.unlocksTheme {
                                HStack {
                                    Image(systemName: "paintpalette.fill")
                                    Text("Unlocks: \(theme.title)")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.yellow)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("Awesome!")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotation = 350
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 0.5
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Achievements Grid View

struct AchievementsView: View {
    @State var manager: AchievementsManager
    let theme: ThemeMode
    
    @State private var selectedFilter: AchievementFilter = .all
    
    enum AchievementFilter: String, CaseIterable {
        case all = "All"
        case unlocked = "Unlocked"
        case locked = "Locked"
    }
    
    var filteredAchievements: [Achievement] {
        switch selectedFilter {
        case .all:
            return manager.achievements
        case .unlocked:
            return manager.achievements.filter(\.isUnlocked)
        case .locked:
            return manager.achievements.filter { !$0.isUnlocked }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress header
                progressHeader
                
                // Filter picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(AchievementFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Achievements grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                    ForEach(filteredAchievements) { achievement in
                        AchievementCard(achievement: achievement, theme: theme)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Theme.backgroundGradient(for: theme).ignoresSafeArea())
        .navigationTitle("Achievements")
        .overlay {
            if manager.showUnlockCelebration {
                AchievementCelebrationView(achievements: manager.newlyUnlocked) {
                    manager.dismissCelebration()
                }
            }
        }
    }
    
    private var progressHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Theme.secondaryText(for: theme).opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: manager.completionPercentage)
                    .stroke(
                        AngularGradient(
                            colors: [Theme.accent(for: theme), .yellow, Theme.accent(for: theme)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(manager.unlockedAchievementCount)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.primaryText(for: theme))
                    Text("/ \(manager.totalAchievementCount)")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText(for: theme))
                }
            }
            
            Text("\(Int(manager.completionPercentage * 100))% Complete")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: theme))
            
            if manager.unlockedThemeCount > 0 {
                Text("\(manager.unlockedThemeCount) theme(s) unlocked")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent(for: theme))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardColor(for: theme))
        )
        .padding(.horizontal)
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let theme: ThemeMode
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Theme.accent(for: theme).opacity(0.2) : Theme.secondaryText(for: theme).opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.type.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(achievement.isUnlocked ? Theme.accent(for: theme) : Theme.secondaryText(for: theme).opacity(0.5))
            }
            
            // Title and description
            VStack(spacing: 4) {
                Text(achievement.type.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(achievement.isUnlocked ? Theme.primaryText(for: theme) : Theme.secondaryText(for: theme))
                    .multilineTextAlignment(.center)
                
                if achievement.isUnlocked || !achievement.type.isSecret {
                    Text(achievement.type.description)
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText(for: theme).opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                } else {
                    Text("???")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText(for: theme).opacity(0.5))
                }
            }
            
            // Progress bar or unlocked badge
            if achievement.isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.secondaryText(for: theme).opacity(0.1))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.accent(for: theme).opacity(0.6))
                            .frame(width: geo.size.width * achievement.progressPercent, height: 8)
                    }
                }
                .frame(height: 8)
                
                Text("\(achievement.progress)/\(achievement.target)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.secondaryText(for: theme))
            }
        }
        .padding()
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardColor(for: theme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(achievement.isUnlocked ? Theme.accent(for: theme).opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .opacity(achievement.isUnlocked ? 1.0 : 0.7)
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            withAnimation(.spring(response: 0.3)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
