import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct DailyQuoteShareView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var quotes: [ShareableQuote] = []
    @State private var selectedQuote: ShareableQuote?
    @State private var showShareSheet = false
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    featuredQuoteCard
                    quotesList
                }
                .padding()
            }
            .navigationTitle("Daily Quotes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let quote = selectedQuote {
                    ShareSheet(items: [quote.text + "\n\n#Badvice"])
                }
            }
            .onAppear {
                loadQuotes()
            }
        }
    }
    
    private var featuredQuoteCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "quote.opening")
                .font(.system(size: 40))
                .foregroundColor(accent)
            
            if let quote = quotes.first {
                Text(quote.text)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(primaryText)
                    .multilineTextAlignment(.center)
                
                Text("- \(quote.author)")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                
                HStack(spacing: 16) {
                    Button {
                        selectedQuote = quote
                        showShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                    
                    Button {
                        // Save quote
                    } label: {
                        Label("Save", systemImage: "heart")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var quotesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("More Quotes")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(quotes.dropFirst()) { quote in
                quoteRow(quote)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func quoteRow(_ quote: ShareableQuote) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(quote.text)
                    .font(.subheadline)
                    .foregroundColor(primaryText)
                    .lineLimit(2)
                Text("- \(quote.author)")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            Spacer()
            
            Button {
                selectedQuote = quote
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(accent)
            }
        }
        .padding()
        .background(secondaryText.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func loadQuotes() {
        quotes = [
            ShareableQuote(id: UUID(), text: "The best advice is often the worst advice.", author: "Unknown"),
            ShareableQuote(id: UUID(), text: "If at first you don't succeed, give up. Clearly nobody cares.", author: "Chaos Expert"),
            ShareableQuote(id: UUID(), text: "Sleep is for the weak. Coffee is for the strong.", author: "Bad Advice Guru"),
            ShareableQuote(id: UUID(), text: "Just do it. Or don't. Either way, it doesn't matter.", author: "Zen Master"),
            ShareableQuote(id: UUID(), text: "The only bad advice is the advice you don't share.", author: "Badvice Team"),
        ]
    }
}

struct ShareableQuote: Identifiable {
    let id: UUID
    let text: String
    let author: String
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct StreakFreezeView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var streakFreezes = 0
    @State private var streakFreezeEnabled = false
    @State private var vacationMode = false
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    streakStatusCard
                    streakFreezeCard
                    vacationModeCard
                    usageTipsCard
                }
                .padding()
            }
            .navigationTitle("Streak Protection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private var streakStatusCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                VStack {
                    Text("\(UserDefaults.standard.integer(forKey: "currentStreak"))")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(primaryText)
                    Text("day streak")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }
            
            Text("Keep your streak alive!")
                .font(.headline)
                .foregroundColor(primaryText)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var streakFreezeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "snowflake")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Streak Freeze")
                    .font(.headline)
                    .foregroundColor(primaryText)
                Spacer()
                Text("\(streakFreezes) available")
                    .font(.caption)
                    .foregroundColor(accent)
            }
            
            Text("Use a streak freeze to protect your streak when you miss a day. Perfect for busy days or emergencies!")
                .font(.subheadline)
                .foregroundColor(secondaryText)
            
            Toggle("Auto-apply Streak Freeze", isOn: $streakFreezeEnabled)
                .tint(accent)
            
            Button {
                // Buy streak freeze
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Get More Streak Freezes")
                }
                .font(.subheadline)
                .foregroundColor(accent)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var vacationModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Vacation Mode")
                    .font(.headline)
                    .foregroundColor(primaryText)
            }
            
            Text("Going on vacation? Enable vacation mode to pause your streak without losing progress. Perfect for trips!")
                .font(.subheadline)
                .foregroundColor(secondaryText)
            
            Toggle("Enable Vacation Mode", isOn: $vacationMode)
                .tint(accent)
            
            if vacationMode {
                HStack {
                    Text("Duration:")
                        .foregroundColor(secondaryText)
                    Picker("Days", selection: .constant(7)) {
                        Text("3 days").tag(3)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                    }
                    .pickerStyle(.menu)
                }
                
                Button {
                    enableVacationMode()
                } label: {
                    Text("Activate Vacation Mode")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var usageTipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips")
                .font(.headline)
                .foregroundColor(primaryText)
            
            tipRow(icon: "calendar.badge.plus", text: "Generate advice daily to build your streak")
            tipRow(icon: "snowflake", text: "Use streak freezes wisely - they're limited!")
            tipRow(icon: "airplane", text: "Enable vacation mode before trips")
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(accent)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(secondaryText)
        }
    }
    
    private func loadData() {
        streakFreezes = UserDefaults.standard.integer(forKey: "streakFreezes")
    }
    
    private func enableVacationMode() {
        // Enable vacation mode
    }
}

struct FriendBattlesView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var battles: [FriendBattle] = []
    @State private var showCreateBattle = false
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    createBattleCard
                    activeBattlesCard
                    battleHistoryCard
                }
                .padding()
            }
            .navigationTitle("Friend Battles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateBattle = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadBattles()
            }
        }
    }
    
    private var createBattleCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 50))
                .foregroundColor(accent)
            
            Text("Challenge Your Friends!")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Text("Battle friends to see who can generate the worst advice. Vote on each other's and crown the Chaos Champion!")
                .font(.subheadline)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
            
            Button {
                showCreateBattle = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Start Battle")
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
    
    private var activeBattlesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Battles")
                    .font(.headline)
                    .foregroundColor(primaryText)
                Spacer()
                Text("\(battles.filter { $0.status == .active }.count)")
                    .foregroundColor(accent)
            }
            
            if battles.isEmpty {
                Text("No active battles")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(battles.filter { $0.status == .active }) { battle in
                    battleRow(battle)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func battleRow(_ battle: FriendBattle) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(battle.opponentName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryText)
                    Text(battle.category.title)
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("You: \(battle.userScore)")
                        .font(.caption)
                        .foregroundColor(accent)
                    Text("Them: \(battle.opponentScore)")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }
            
            Button {
                // Continue battle
            } label: {
                Text(battle.turn == .user ? "Your Turn" : "Their Turn")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(battle.turn == .user ? accent : secondaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(secondaryText.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var battleHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Battle History")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(battles.filter { $0.status == .completed }.prefix(5)) { battle in
                HStack {
                    Image(systemName: battle.userScore > battle.opponentScore ? "trophy.fill" : "xmark.circle")
                        .foregroundColor(battle.userScore > battle.opponentScore ? .yellow : .red)
                    
                    Text("vs \(battle.opponentName)")
                        .font(.subheadline)
                        .foregroundColor(primaryText)
                    
                    Spacer()
                    
                    Text("\(battle.userScore) - \(battle.opponentScore)")
                        .font(.subheadline)
                        .foregroundColor(secondaryText)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func loadBattles() {
        battles = [
            FriendBattle(id: UUID(), opponentName: "Alex", category: .dating, userScore: 3, opponentScore: 2, status: .active, turn: .user),
            FriendBattle(id: UUID(), opponentName: "Sam", category: .career, userScore: 5, opponentScore: 4, status: .active, turn: .opponent),
            FriendBattle(id: UUID(), opponentName: "Jordan", category: .fitness, userScore: 2, opponentScore: 5, status: .completed, turn: .user),
        ]
    }
}

struct FriendBattle: Identifiable {
    let id: UUID
    let opponentName: String
    let category: AdviceCategory
    var userScore: Int
    var opponentScore: Int
    var status: BattleStatus
    var turn: BattleTurn
    
    enum BattleStatus {
        case active
        case completed
    }
    
    enum BattleTurn {
        case user
        case opponent
    }
}

struct HelpCenterView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var faqs: [FAQ] = []
    @State private var categories: [HelpCategory] = []
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    searchBar
                    quickHelpSection
                    categoriesSection
                    faqSection
                    contactSection
                }
                .padding()
            }
            .navigationTitle("Help Center")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(secondaryText)
            TextField("Search help...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var quickHelpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Help")
                .font(.headline)
                .foregroundColor(primaryText)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickHelpButton(icon: "sparkles", title: "Generate", action: {})
                quickHelpButton(icon: "heart.fill", title: "Favorites", action: {})
                quickHelpButton(icon: "square.and.arrow.up", title: "Share", action: {})
                quickHelpButton(icon: "flame.fill", title: "Streak", action: {})
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func quickHelpButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(accent)
                Text(title)
                    .font(.caption)
                    .foregroundColor(primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Topic")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(categories) { category in
                Button {
                    // Navigate to category
                } label: {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(accent)
                            .frame(width: 30)
                        Text(category.name)
                            .font(.subheadline)
                            .foregroundColor(primaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(secondaryText)
                    }
                    .padding()
                    .background(secondaryText.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FAQ")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(faqs) { faq in
                DisclosureGroup {
                    Text(faq.answer)
                        .font(.subheadline)
                        .foregroundColor(secondaryText)
                } label: {
                    Text(faq.question)
                        .font(.subheadline)
                        .foregroundColor(primaryText)
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Still Need Help?")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Button {
                // Contact support
            } label: {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Contact Support")
                }
                .font(.subheadline)
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
    
    private func loadData() {
        categories = [
            HelpCategory(id: UUID(), name: "Getting Started", icon: "play.circle.fill"),
            HelpCategory(id: UUID(), name: "Account & Profile", icon: "person.circle.fill"),
            HelpCategory(id: UUID(), name: "Generating Advice", icon: "sparkles"),
            HelpCategory(id: UUID(), name: "Social Features", icon: "person.2.fill"),
            HelpCategory(id: UUID(), name: "Streaks & Rewards", icon: "flame.fill"),
        ]
        
        faqs = [
            FAQ(id: UUID(), question: "How do I generate advice?", answer: "Tap the sparkles tab and select your category and tone, then tap generate!"),
            FAQ(id: UUID(), question: "How do streaks work?", answer: "Generate at least one piece of advice each day to maintain your streak. Missing a day resets your streak to zero."),
            FAQ(id: UUID(), question: "Can I use the app offline?", answer: "Yes! Most features work offline. Some social features require an internet connection."),
            FAQ(id: UUID(), question: "How do I share advice?", answer: "Tap the share button on any advice card to share via social media, messages, or copy to clipboard."),
        ]
    }
}

struct HelpCategory: Identifiable {
    let id: UUID
    let name: String
    let icon: String
}

struct FAQ: Identifiable {
    let id: UUID
    let question: String
    let answer: String
}

struct TutorialView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    @State private var tutorialSteps: [TutorialStep] = []
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                tutorialContent
                
                Spacer()
                
                pageIndicator
                
                navigationButtons
            }
            .padding()
            .background(cardColor.ignoresSafeArea())
            .onAppear {
                loadTutorial()
            }
        }
    }
    
    private var tutorialContent: some View {
        VStack(spacing: 16) {
            Image(systemName: tutorialSteps[safe: currentStep]?.icon ?? "questionmark.circle")
                .font(.system(size: 80))
                .foregroundColor(accent)
            
            Text(tutorialSteps[safe: currentStep]?.title ?? "")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryText)
                .multilineTextAlignment(.center)
            
            Text(tutorialSteps[safe: currentStep]?.description ?? "")
                .font(.body)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<tutorialSteps.count, id: \.self) { index in
                Circle()
                    .fill(currentStep == index ? accent : secondaryText.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .font(.headline)
                .foregroundColor(secondaryText)
            }
            
            Spacer()
            
            Button(currentStep < tutorialSteps.count - 1 ? "Next" : "Get Started") {
                if currentStep < tutorialSteps.count - 1 {
                    withAnimation {
                        currentStep += 1
                    }
                } else {
                    completeTutorial()
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(accent)
            .clipShape(Capsule())
        }
    }
    
    private func loadTutorial() {
        tutorialSteps = [
            TutorialStep(icon: "sparkles", title: "Welcome to Badvice", description: "Generate the worst advice on any topic! Select a category and tone, then let chaos commence."),
            TutorialStep(icon: "flame.fill", title: "Build Your Streak", description: "Generate advice daily to maintain your streak. The longer your streak, the more rewards you unlock!"),
            TutorialStep(icon: "person.2.fill", title: "Challenge Friends", description: "Battle friends to see who can generate the worst advice. Vote on each other's submissions!"),
            TutorialStep(icon: "trophy.fill", title: "Earn Achievements", description: "Unlock badges and titles as you generate more advice. Complete challenges for exclusive rewards!"),
            TutorialStep(icon: "square.and.arrow.up", title: "Share the Chaos", description: "Share your terrible advice on social media. The worse, the better!"),
        ]
    }
    
    private func completeTutorial() {
        UserDefaults.standard.set(true, forKey: "completedTutorial")
        dismiss()
    }
}

struct TutorialStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
