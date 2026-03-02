import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct GameModesView: View {
    @Bindable var generateViewModel: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMode: GameModeTab = .timedChallenge
    @State private var activeChallenge: TimedChallenge?
    @State private var challengeTimeRemaining: TimeInterval = 0
    @State private var challengeScore: Int = 0
    @State private var challengeRound: Int = 0
    @State private var isChallengeActive = false
    @State private var survivalMode: SurvivalMode?
    @State private var showSurvivalGameOver = false
    
    enum GameModeTab: String, CaseIterable {
        case timedChallenge = "Timed"
        case categoryMastery = "Categories"
        case toneMastery = "Tones"
        case survival = "Survival"
        
        var icon: String {
            switch self {
            case .timedChallenge: return "timer"
            case .categoryMastery: return "chart.bar.fill"
            case .toneMastery: return "wand.and.stars"
            case .survival: return "heart.fill"
            }
        }
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                TabView(selection: $selectedMode) {
                    timedChallengeTab
                        .tag(GameModeTab.timedChallenge)
                    
                    categoryMasteryTab
                        .tag(GameModeTab.categoryMastery)
                    
                    toneMasteryTab
                        .tag(GameModeTab.toneMastery)
                    
                    survivalTab
                        .tag(GameModeTab.survival)
                }
            }
            .navigationTitle("Game Modes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $isChallengeActive) {
                activeChallengeView
            }
            .sheet(isPresented: $showSurvivalGameOver) {
                survivalGameOverView
            }
        }
    }
    
    @ViewBuilder
    private var modePicker: some View {
        HStack(spacing: 12) {
            ForEach(GameModeTab.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.title3)
                        Text(mode.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedMode == mode ? .white : secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedMode == mode ? accent : cardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var timedChallengeTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(TimedChallenge.presets, id: \.id) { challenge in
                    challengeCard(challenge)
                }
            }
            .padding()
        }
    }
    
    private func challengeCard(_ challenge: TimedChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.name)
                        .font(.headline)
                        .foregroundColor(primaryText)
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundColor(secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(Int(challenge.timeLimit))s")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(accent)
                    Text("\(challenge.totalRounds) rounds")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }
            
            HStack {
                Label(challenge.category.title, systemImage: challenge.category.icon)
                    .font(.caption)
                    .foregroundColor(secondaryText)
                Spacer()
                Label(challenge.tone.title, systemImage: "text.bubble")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            Button {
                startTimedChallenge(challenge)
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Challenge")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var categoryMasteryTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(AdviceCategory.concrete, id: \.self) { category in
                    categoryMasteryCard(category)
                }
            }
            .padding()
        }
    }
    
    private func categoryMasteryCard(_ category: AdviceCategory) -> some View {
        let mastery = generateViewModel.categoryMastery[category] ?? CategoryMastery(
            category: category,
            generationCount: 0,
            shareCount: 0,
            favoriteCount: 0,
            masteryLevel: .novice
        )
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(accent)
                    .frame(width: 40, height: 40)
                    .background(accent.opacity(0.2))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.headline)
                        .foregroundColor(primaryText)
                    Text(mastery.masteryLevel.title)
                        .font(.caption)
                        .foregroundColor(accent)
                }
                
                Spacer()
                
                Text("Lv.\(mastery.masteryLevel.rawValue + 1)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(primaryText)
            }
            
            ProgressView(value: Double(mastery.generationCount), total: Double(mastery.masteryLevel.requiredGenerations))
                .tint(accent)
            
            HStack {
                statItem(icon: "sparkles", value: mastery.generationCount, label: "Generated")
                Spacer()
                statItem(icon: "square.and.arrow.up", value: mastery.shareCount, label: "Shared")
                Spacer()
                statItem(icon: "heart.fill", value: mastery.favoriteCount, label: "Saved")
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func statItem(icon: String, value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .foregroundColor(accent)
            Text("\(value)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(primaryText)
            Text(label)
                .font(.caption2)
                .foregroundColor(secondaryText)
        }
    }
    
    private var toneMasteryTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(ToneMode.concrete, id: \.self) { tone in
                    toneMasteryCard(tone)
                }
            }
            .padding()
        }
    }
    
    private func toneMasteryCard(_ tone: ToneMode) -> some View {
        let mastery = generateViewModel.toneMastery[tone] ?? ToneMastery(
            tone: tone,
            usageCount: 0,
            masteryBadges: []
        )
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tone.title)
                        .font(.headline)
                        .foregroundColor(primaryText)
                    Text("\(mastery.usageCount) uses")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
                
                Spacer()
                
                if !mastery.masteryBadges.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(mastery.masteryBadges.prefix(3), id: \.name) { badge in
                            Image(systemName: badge.icon)
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            
            if mastery.masteryBadges.isEmpty {
                Text("Use this tone to earn badges!")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            } else {
                ForEach(mastery.masteryBadges, id: \.name) { badge in
                    HStack {
                        Image(systemName: badge.icon)
                            .foregroundColor(.yellow)
                        Text(badge.name)
                            .font(.caption)
                            .foregroundColor(primaryText)
                        Spacer()
                        Text(badge.description)
                            .font(.caption2)
                            .foregroundColor(secondaryText)
                    }
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var survivalTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let survival = survivalMode {
                    survivalProgressCard(survival)
                } else {
                    startSurvivalCard
                }
            }
            .padding()
        }
    }
    
    private var startSurvivalCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Survival Mode")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryText)
            
            Text("How long can you survive generating terrible advice? Each bad vote ends your run!")
                .font(.subheadline)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
            
            Button {
                startSurvivalMode()
            } label: {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("Start Survival")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func survivalProgressCard(_ survival: SurvivalMode) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("🔥 Streak: \(survival.currentStreak)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(accent)
                Spacer()
                Text("Score: \(survival.totalScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(primaryText)
            }
            
            ForEach(survival.rounds) { round in
                HStack {
                    Image(systemName: round.survived ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(round.survived ? .green : .red)
                    Text(round.advice.prefix(40) + (round.advice.count > 40 ? "..." : ""))
                        .font(.caption)
                        .foregroundColor(primaryText)
                    Spacer()
                    Text("\(round.score)")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }
            
            if survival.isAlive {
                Button {
                    generateViewModel.generateAdvice()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Next Round")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var activeChallengeView: some View {
        VStack(spacing: 24) {
            Text("Time Remaining")
                .font(.headline)
                .foregroundColor(secondaryText)
            
            Text("\(Int(challengeTimeRemaining))s")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(challengeTimeRemaining < 10 ? .red : accent)
            
            Text("Round \(challengeRound)/\(activeChallenge?.totalRounds ?? 0)")
                .font(.title3)
                .foregroundColor(primaryText)
            
            Text("Score: \(challengeScore)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(accent)
            
            Spacer()
            
            Button {
                generateViewModel.generateAdvice()
                challengeRound += 1
                challengeScore += Int.random(in: 10...100)
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate!")
                }
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            Button("End Challenge") {
                endTimedChallenge()
            }
            .foregroundColor(.red)
        }
        .padding()
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if challengeTimeRemaining > 0 && isChallengeActive {
                challengeTimeRemaining -= 1
            } else if isChallengeActive {
                endTimedChallenge()
            }
        }
    }
    
    private var survivalGameOverView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Game Over")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(primaryText)
            
            if let survival = survivalMode {
                Text("You survived \(survival.currentStreak) rounds!")
                    .font(.headline)
                    .foregroundColor(secondaryText)
                
                Text("Final Score: \(survival.totalScore)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(accent)
            }
            
            Button("Play Again") {
                startSurvivalMode()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Button("Close") {
                showSurvivalGameOver = false
            }
            .foregroundColor(secondaryText)
        }
        .padding()
    }
    
    private func startTimedChallenge(_ challenge: TimedChallenge) {
        activeChallenge = challenge
        challengeTimeRemaining = challenge.timeLimit
        challengeScore = 0
        challengeRound = 0
        isChallengeActive = true
    }
    
    private func endTimedChallenge() {
        isChallengeActive = false
        activeChallenge = nil
    }
    
    private func startSurvivalMode() {
        survivalMode = SurvivalMode(
            id: UUID(),
            category: .random,
            startedAt: Date(),
            rounds: [],
            currentStreak: 0,
            isAlive: true
        )
        showSurvivalGameOver = false
    }
}
