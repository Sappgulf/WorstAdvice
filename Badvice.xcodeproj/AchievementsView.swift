import SwiftUI

struct AchievementsView: View {
    @Bindable var settings: SettingsViewModel
    @State private var selectedFilter: AchievementFilter = .all
    @State private var itemsAppeared = false
    
    enum AchievementFilter: String, CaseIterable, Identifiable {
        case all, unlocked, locked
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .all: return "All"
            case .unlocked: return "Unlocked"
            case .locked: return "Locked"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats header
                    achievementStats
                    
                    // Filter picker
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(AchievementFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Achievement grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(Array(filteredAchievements.enumerated()), id: \.element.id) { index, achievement in
                            AchievementCardView(
                                achievement: achievement,
                                theme: settings.theme
                            )
                            .opacity(itemsAppeared ? 1 : 0)
                            .scaleEffect(itemsAppeared ? 1 : 0.8)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.7)
                                .delay(Double(index) * 0.05),
                                value: itemsAppeared
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(ThemeBackgroundView(mode: settings.theme).ignoresSafeArea())
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                withAnimation {
                    itemsAppeared = true
                }
            }
        }
    }
    
    private var achievementStats: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent(for: settings.theme).opacity(0.15))
                    .frame(width: 100, height: 100)
                
                VStack(spacing: 4) {
                    Text("\(unlockedCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent(for: settings.theme))
                    
                    Text("Unlocked")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.secondaryText(for: settings.theme))
                }
            }
            
            HStack(spacing: 20) {
                StatBadge(
                    value: "\(unlockedCount)/\(totalCount)",
                    label: "Progress",
                    icon: "checkmark.circle.fill",
                    theme: settings.theme
                )
                
                StatBadge(
                    value: "\(Int(completionPercent))%",
                    label: "Complete",
                    icon: "chart.pie.fill",
                    theme: settings.theme
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.cardColor(for: settings.theme))
        )
        .padding(.horizontal)
    }
    
    private var filteredAchievements: [Achievement] {
        let all = mockAchievements // In real app, fetch from settings.achievements
        
        switch selectedFilter {
        case .all:
            return all
        case .unlocked:
            return all.filter { $0.isUnlocked }
        case .locked:
            return all.filter { !$0.isUnlocked }
        }
    }
    
    private var unlockedCount: Int {
        mockAchievements.filter { $0.isUnlocked }.count
    }
    
    private var totalCount: Int {
        mockAchievements.count
    }
    
    private var completionPercent: Double {
        guard totalCount > 0 else { return 0 }
        return Double(unlockedCount) / Double(totalCount) * 100
    }
    
    // Mock data - replace with real achievements from ViewModel
    private var mockAchievements: [Achievement] {
        [
            Achievement(type: .firstAdvice, unlockedAt: Date(), progress: 1, target: 1),
            Achievement(type: .tenAdvice, unlockedAt: Date(), progress: 10, target: 10),
            Achievement(type: .hundredAdvice, unlockedAt: nil, progress: 45, target: 100),
            Achievement(type: .firstSave, unlockedAt: Date(), progress: 1, target: 1),
            Achievement(type: .collector, unlockedAt: nil, progress: 7, target: 10),
            Achievement(type: .hoarder, unlockedAt: nil, progress: 7, target: 50),
            Achievement(type: .sharer, unlockedAt: nil, progress: 2, target: 5),
            Achievement(type: .viral, unlockedAt: nil, progress: 2, target: 25),
            Achievement(type: .dailyStreak3, unlockedAt: Date(), progress: 3, target: 3),
            Achievement(type: .dailyStreak7, unlockedAt: nil, progress: 3, target: 7),
            Achievement(type: .dailyStreak14, unlockedAt: nil, progress: 3, target: 14),
            Achievement(type: .dailyStreak30, unlockedAt: nil, progress: 3, target: 30),
            Achievement(type: .toneExplorer, unlockedAt: nil, progress: 5, target: 11),
            Achievement(type: .categoryMaster, unlockedAt: nil, progress: 8, target: 10),
            Achievement(type: .nightOwl, unlockedAt: nil, progress: 0, target: 1),
            Achievement(type: .earlyBird, unlockedAt: nil, progress: 0, target: 1),
            Achievement(type: .shakeItOff, unlockedAt: Date(), progress: 1, target: 1),
            Achievement(type: .suggestionAccepted, unlockedAt: nil, progress: 0, target: 1),
        ]
    }
}

// MARK: - Achievement Card

private struct AchievementCardView: View {
    let achievement: Achievement
    let theme: ThemeMode
    
    @State private var showDetails = false
    
    var body: some View {
        Button {
            HapticsManager.playSelection(isEnabled: true)
            showDetails = true
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked ? Theme.accent(for: theme).opacity(0.2) : Theme.secondaryText(for: theme).opacity(0.1))
                        .frame(width: 70, height: 70)
                    
                    if achievement.isUnlocked {
                        Image(systemName: achievement.type.icon)
                            .font(.system(size: 30))
                            .foregroundStyle(Theme.accent(for: theme))
                    } else {
                        // Progress ring for locked achievements
                        ZStack {
                            Circle()
                                .stroke(Theme.secondaryText(for: theme).opacity(0.2), lineWidth: 4)
                                .frame(width: 60, height: 60)
                            
                            Circle()
                                .trim(from: 0, to: achievement.progressPercent)
                                .stroke(Theme.accent(for: theme), lineWidth: 4)
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))
                            
                            Image(systemName: "lock.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Theme.secondaryText(for: theme).opacity(0.5))
                        }
                    }
                }
                
                VStack(spacing: 4) {
                    Text(achievement.type.isSecret && !achievement.isUnlocked ? "???" : achievement.type.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.primaryText(for: theme))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if !achievement.isUnlocked {
                        Text("\(achievement.progress)/\(achievement.target)")
                            .font(.caption2)
                            .foregroundStyle(Theme.secondaryText(for: theme))
                    } else if let unlockedAt = achievement.unlockedAt {
                        Text(unlockedAt, style: .date)
                            .font(.caption2)
                            .foregroundStyle(Theme.accent(for: theme))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardColor(for: theme))
                    .shadow(
                        color: achievement.isUnlocked ? Theme.accent(for: theme).opacity(0.2) : .clear,
                        radius: achievement.isUnlocked ? 10 : 0
                    )
            )
        }
        .sheet(isPresented: $showDetails) {
            AchievementDetailSheet(achievement: achievement, theme: theme)
        }
    }
}

// MARK: - Achievement Detail Sheet

private struct AchievementDetailSheet: View {
    let achievement: Achievement
    let theme: ThemeMode
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Large icon
                    ZStack {
                        Circle()
                            .fill(achievement.isUnlocked ? Theme.accent(for: theme).opacity(0.2) : Theme.secondaryText(for: theme).opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: achievement.type.icon)
                            .font(.system(size: 50))
                            .foregroundStyle(achievement.isUnlocked ? Theme.accent(for: theme) : Theme.secondaryText(for: theme).opacity(0.5))
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 8) {
                        Text(achievement.type.isSecret && !achievement.isUnlocked ? "Secret Achievement" : achievement.type.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.primaryText(for: theme))
                        
                        Text(achievement.type.isSecret && !achievement.isUnlocked ? "Complete the requirements to reveal" : achievement.type.description)
                            .font(.body)
                            .foregroundStyle(Theme.secondaryText(for: theme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    if !achievement.isUnlocked {
                        VStack(spacing: 12) {
                            Text("Progress")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.secondaryText(for: theme))
                            
                            ProgressView(value: achievement.progressPercent, total: 1.0)
                                .tint(Theme.accent(for: theme))
                                .scaleEffect(x: 1, y: 2)
                            
                            Text("\(achievement.progress) / \(achievement.target)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.primaryText(for: theme))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.cardColor(for: theme))
                        )
                        .padding(.horizontal)
                    } else if let unlockedAt = achievement.unlockedAt {
                        VStack(spacing: 8) {
                            Text("Unlocked")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent(for: theme))
                            
                            Text(unlockedAt, style: .date)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.primaryText(for: theme))
                            
                            Text(unlockedAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText(for: theme))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.accent(for: theme).opacity(0.1))
                        )
                        .padding(.horizontal)
                    }
                    
                    // Theme unlock info
                    if let unlockedTheme = achievement.type.unlocksTheme, achievement.isUnlocked {
                        VStack(spacing: 8) {
                            Image(systemName: "paintpalette.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.accent(for: theme))
                            
                            Text("Theme Unlocked!")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText(for: theme))
                            
                            Text(UnlockableTheme(rawValue: unlockedTheme.rawValue)?.displayName ?? unlockedTheme.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText(for: theme))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.accent(for: theme).opacity(0.15))
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(ThemeBackgroundView(mode: theme).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let theme: ThemeMode
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.accent(for: theme))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.primaryText(for: theme))
                
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText(for: theme))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.accent(for: theme).opacity(0.1))
        )
    }
}

#Preview {
    AchievementsView(settings: SettingsViewModel(repository: AdviceRepository(context: PreviewHelper.previewContext)))
}
