import SwiftUI

struct AISuggestionsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var suggestions: [AISuggestion] = []
    @State private var isEnabled = true
    
    struct AISuggestion: Identifiable {
        let id = UUID()
        let category: AdviceCategory
        let tone: ToneMode
        let reason: String
        let confidence: Double
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Enable AI Suggestions", isOn: $isEnabled)
                } footer: {
                    Text("Get smart recommendations based on your usage patterns")
                }
                
                if isEnabled {
                    Section("Suggested For You") {
                        ForEach(suggestions) { suggestion in
                            suggestionRow(suggestion)
                        }
                    }
                    
                    Section("Why These?") {
                        Text("Suggestions are based on time of day, your history, and trending categories.")
                            .font(.subheadline)
                            .foregroundColor(secondaryText)
                    }
                }
            }
            .navigationTitle("AI Suggestions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadSuggestions()
            }
        }
    }
    
    private func suggestionRow(_ suggestion: AISuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: suggestion.category.icon)
                    .foregroundColor(accent)
                Text(suggestion.category.title)
                    .font(.headline)
                    .foregroundColor(primaryText)
                
                Spacer()
                
                Text("\(Int(suggestion.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(accent)
            }
            
            HStack {
                Image(systemName: "text.bubble")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                Text(suggestion.tone.title)
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            Text(suggestion.reason)
                .font(.caption)
                .foregroundColor(secondaryText)
            
            Button("Generate") {
                // Generate with suggestion
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(accent)
        }
        .padding(.vertical, 4)
    }
    
    private func loadSuggestions() {
        let hour = Calendar.current.component(.hour, from: Date())
        
        suggestions = [
            AISuggestion(
                category: hour < 12 ? .career : (hour < 18 ? .dating : .social),
                tone: .toxicBestFriend,
                reason: hour < 12 ? "Morning productivity boost" : "Evening social vibes",
                confidence: 0.87
            ),
            AISuggestion(
                category: .fitness,
                tone: .boomer,
                reason: "Trending this week",
                confidence: 0.72
            ),
            AISuggestion(
                category: .tech,
                tone: .conspiracyTheorist,
                reason: "Based on your tech interest",
                confidence: 0.65
            ),
        ]
    }
}

struct PersonalizedFeedView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var feedItems: [FeedItem] = []
    
    struct FeedItem: Identifiable {
        let id = UUID()
        let advice: String
        let author: String
        let votes: Int
        let category: AdviceCategory
        let timestamp: Date
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(feedItems) { item in
                        feedCard(item)
                    }
                }
                .padding()
            }
            .navigationTitle("For You")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadFeed()
            }
        }
    }
    
    private func feedCard(_ item: FeedItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.category.icon)
                    .foregroundColor(accent)
                Text(item.category.title)
                    .font(.caption)
                    .foregroundColor(secondaryText)
                
                Spacer()
                
                Text(item.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(secondaryText)
            }
            
            Text(item.advice)
                .font(.subheadline)
                .foregroundColor(primaryText)
                .lineLimit(3)
            
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(secondaryText)
                Text(item.author)
                    .font(.caption)
                    .foregroundColor(secondaryText)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                    Text("\(item.votes)")
                }
                .font(.caption)
                .foregroundColor(accent)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func loadFeed() {
        feedItems = [
            FeedItem(advice: "Just don't show up to work. Problem solved.", author: "ChaosKing", votes: 234, category: .career, timestamp: Date().addingTimeInterval(-3600)),
            FeedItem(advice: "Tell your ex you found their replacement on Amazon.", author: "BadAdvicePro", votes: 189, category: .dating, timestamp: Date().addingTimeInterval(-7200)),
            FeedItem(advice: "Run away from your problems. Literally.", author: "TrollMaster", votes: 156, category: .fitness, timestamp: Date().addingTimeInterval(-10800)),
        ]
    }
}

struct SpinTheWheelView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var rotation: Double = 0
    @State private var selectedCategory: AdviceCategory?
    @State private var selectedTone: ToneMode?
    @State private var isSpinning = false
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                wheelView
                
                if let category = selectedCategory {
                    resultCard(category)
                }
                
                Spacer()
                
                Button {
                    spin()
                } label: {
                    Text(isSpinning ? "Spinning..." : "SPIN!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSpinning ? Color.gray : accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isSpinning)
            }
            .padding()
            .navigationTitle("Spin the Wheel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var wheelView: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                        center: .center
                    )
                )
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(rotation))
            
            Circle()
                .strokeBorder(primaryText.opacity(0.3), lineWidth: 4)
                .frame(width: 250, height: 250)
            
            VStack {
                Text("SPIN")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            
            Image(systemName: "arrowtriangle.up.fill")
                .font(.title2)
                .foregroundColor(.white)
                .offset(y: -140)
        }
    }
    
    private func resultCard(_ category: AdviceCategory) -> some View {
        VStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 50))
                .foregroundColor(accent)
            
            Text(category.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryText)
            
            Button {
                // Generate with this category
            } label: {
                Text("Generate Now")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(accent)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func spin() {
        isSpinning = true
        let rounds = Double.random(in: 5...10)
        let angle = Double.random(in: 0...360)
        
        withAnimation(.easeOut(duration: 4)) {
            rotation = rounds * 360 + angle
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            let categories = AdviceCategory.concrete
            let index = Int(angle) % categories.count
            selectedCategory = categories[index]
            isSpinning = false
        }
    }
}

struct PredictionGameView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var predictions: [Prediction] = []
    @State private var currentRound = 0
    @State private var score = 0
    
    struct Prediction: Identifiable {
        let id = UUID()
        let advice: String
        let predictedVotes: Int
        let actualVotes: Int?
        let category: AdviceCategory
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    scoreCard
                    predictionsList
                }
                .padding()
            }
            .navigationTitle("Prediction Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadPredictions()
            }
        }
    }
    
    private var scoreCard: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your Score")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                Text("\(score)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(accent)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Round")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                Text("\(currentRound + 1)/\(predictions.count)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(primaryText)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var predictionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(predictions) { prediction in
                predictionCard(prediction)
            }
        }
    }
    
    private func predictionCard(_ prediction: Prediction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: prediction.category.icon)
                    .foregroundColor(accent)
                Text(prediction.category.title)
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            Text(prediction.advice)
                .font(.subheadline)
                .foregroundColor(primaryText)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Predicted")
                        .font(.caption2)
                        .foregroundColor(secondaryText)
                    Text("\(prediction.predictedVotes)")
                        .font(.headline)
                        .foregroundColor(accent)
                }
                
                Spacer()
                
                if let actual = prediction.actualVotes {
                    VStack(alignment: .trailing) {
                        Text("Actual")
                            .font(.caption2)
                            .foregroundColor(secondaryText)
                        Text("\(actual)")
                            .font(.headline)
                            .foregroundColor(actual <= prediction.predictedVotes + 10 ? .green : .red)
                    }
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func loadPredictions() {
        predictions = [
            Prediction(advice: "Just quit everything and become a hermit.", predictedVotes: 150, actualVotes: nil, category: .career),
            Prediction(advice: "Tell your boss they're fired.", predictedVotes: 200, actualVotes: nil, category: .dating),
            Prediction(advice: "Eat only pizza for every meal.", predictedVotes: 180, actualVotes: nil, category: .fitness),
        ]
    }
}

struct RemixSystemView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var remixes: [RemixAdvice] = []
    @State private var selectedAdvice: RemixAdvice?
    
    struct RemixAdvice: Identifiable {
        let id = UUID()
        let originalAdvice: String
        let remixText: String
        let author: String
        let remixCount: Int
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(remixes) { remix in
                        remixCard(remix)
                    }
                }
                .padding()
            }
            .navigationTitle("Remixes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadRemixes()
            }
        }
    }
    
    private func remixCard(_ remix: RemixAdvice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(accent)
                Text("Remixed by \(remix.author)")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                Spacer()
                Text("\(remix.remixCount) remixes")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Original:")
                    .font(.caption2)
                    .foregroundColor(secondaryText)
                Text(remix.originalAdvice)
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                    .italic()
            }
            .padding()
            .background(secondaryText.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Remix:")
                    .font(.caption2)
                    .foregroundColor(accent)
                Text(remix.remixText)
                    .font(.subheadline)
                    .foregroundColor(primaryText)
            }
            
            HStack {
                Button {
                    // Remix this
                } label: {
                    Label("Remix", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                
                Button {
                    // View remixes
                } label: {
                    Label("View All", systemImage: "eye")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func loadRemixes() {
        remixes = [
            RemixAdvice(
                originalAdvice: "Just don't try.",
                remixText: "Don't try... until tomorrow. Procrastination is key!",
                author: "ChaosKing",
                remixCount: 12
            ),
            RemixAdvice(
                originalAdvice: "Tell your friends the truth.",
                remixText: "Tell your friends the brutal truth, but smile while doing it.",
                author: "BadAdvicePro",
                remixCount: 8
            ),
        ]
    }
}

struct VotingArenaView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var matches: [ArenaMatch] = []
    @State private var bracket: [BracketItem] = []
    
    struct ArenaMatch: Identifiable {
        let id = UUID()
        let advice1: String
        let advice2: String
        let votes1: Int
        let votes2: Int
        let winner: Int?
    }
    
    struct BracketItem: Identifiable {
        let id = UUID()
        let advice: String
        let seed: Int
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    bracketSection
                    matchesSection
                }
                .padding()
            }
            .navigationTitle("Voting Arena")
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
    
    private var bracketSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Championship Bracket")
                .font(.headline)
                .foregroundColor(primaryText)
            
            if bracket.isEmpty {
                Text("No active bracket")
                    .foregroundColor(secondaryText)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(bracket.prefix(4)) { item in
                        bracketRow(item)
                    }
                }
            }
            
            Button("Start New Bracket") {
                // Start new bracket
            }
            .font(.subheadline)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func bracketRow(_ item: BracketItem) -> some View {
        HStack {
            Text("#\(item.seed)")
                .font(.caption)
                .foregroundColor(secondaryText)
                .frame(width: 30)
            
            Text(item.advice)
                .font(.subheadline)
                .foregroundColor(primaryText)
                .lineLimit(2)
        }
        .padding()
        .background(secondaryText.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var matchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Matches")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(matches) { match in
                matchCard(match)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func matchCard(_ match: ArenaMatch) -> some View {
        VStack(spacing: 12) {
            Text(match.advice1)
                .font(.subheadline)
                .foregroundColor(primaryText)
                .multilineTextAlignment(.center)
            
            Text("VS")
                .font(.caption)
                .foregroundColor(secondaryText)
            
            Text(match.advice2)
                .font(.subheadline)
                .foregroundColor(primaryText)
                .multilineTextAlignment(.center)
            
            HStack {
                Button {
                    // Vote for 1
                } label: {
                    Text("\(match.votes1)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
                
                Button {
                    // Vote for 2
                } label: {
                    Text("\(match.votes2)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
    }
    
    private func loadData() {
        bracket = [
            BracketItem(advice: "Just don't show up", seed: 1),
            BracketItem(advice: "Fake it till you make it", seed: 2),
            BracketItem(advice: "Follow your dreams", seed: 3),
            BracketItem(advice: "Take the easy way", seed: 4),
        ]
        
        matches = [
            ArenaMatch(advice1: "Tell them no", advice2: "Say yes to everything", votes1: 45, votes2: 32, winner: nil),
        ]
    }
}

struct UserCollectionsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var collections: [Collection] = []
    
    struct Collection: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let itemCount: Int
        let isPublic: Bool
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(collections) { collection in
                        collectionCard(collection)
                    }
                }
                .padding()
            }
            .navigationTitle("Collections")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // Create collection
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadCollections()
            }
        }
    }
    
    private func collectionCard(_ collection: Collection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(collection.name)
                        .font(.headline)
                        .foregroundColor(primaryText)
                    Text(collection.description)
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
                
                Spacer()
                
                if collection.isPublic {
                    Image(systemName: "globe")
                        .foregroundColor(accent)
                }
            }
            
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(secondaryText)
                Text("\(collection.itemCount) items")
                    .font(.caption)
                    .foregroundColor(secondaryText)
                
                Spacer()
                
                Button("View") {}
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func loadCollections() {
        collections = [
            Collection(name: "Worst Career Advice", description: "The terrible career advice collection", itemCount: 23, isPublic: true),
            Collection(name: "Dating Disasters", description: "Hilariously bad dating tips", itemCount: 15, isPublic: true),
            Collection(name: "My Favorites", description: "My personal favorites", itemCount: 42, isPublic: false),
        ]
    }
}

struct StreakMultiplierView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStreak = 7
    @State private var multiplier: Double = 1.0
    @State private var pointsToday = 150
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    multiplierCard
                    progressCard
                    rewardsCard
                }
                .padding()
            }
            .navigationTitle("Streak Multiplier")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                calculateMultiplier()
            }
        }
    }
    
    private var multiplierCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(secondaryText.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: multiplier / 3)
                    .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(Int(multiplier * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(primaryText)
                    Text("Multiplier")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }
            
            Text("Current Streak: \(currentStreak) days")
                .font(.headline)
                .foregroundColor(primaryText)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Points")
                .font(.headline)
                .foregroundColor(primaryText)
            
            HStack {
                Text("\(pointsToday)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(accent)
                Text("base points")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                
                Spacer()
                
                Text("= \(Int(pointsToday * multiplier)) with multiplier")
                    .font(.subheadline)
                    .foregroundColor(accent)
            }
            
            ProgressView(value: Double(currentStreak) / 30)
                .tint(accent)
            
            Text("\(30 - currentStreak) days until 3x multiplier!")
                .font(.caption)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var rewardsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Multiplier Tiers")
                .font(.headline)
                .foregroundColor(primaryText)
            
            tierRow(tier: "1x", streak: "1-6 days", color: .gray)
            tierRow(tier: "1.5x", streak: "7-13 days", color: .blue)
            tierRow(tier: "2x", streak: "14-29 days", color: .purple)
            tierRow(tier: "3x", streak: "30+ days", color: .yellow)
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func tierRow(tier: String, streak: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(tier)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(primaryText)
            
            Spacer()
            
            Text(streak)
                .font(.caption)
                .foregroundColor(secondaryText)
        }
    }
    
    private func calculateMultiplier() {
        if currentStreak >= 30 {
            multiplier = 3.0
        } else if currentStreak >= 14 {
            multiplier = 2.0
        } else if currentStreak >= 7 {
            multiplier = 1.5
        } else {
            multiplier = 1.0
        }
    }
}

struct LuckCharmsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var charms: [LuckCharm] = []
    @State private var activeCharm: LuckCharm?
    
    struct LuckCharm: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let icon: String
        let effect: Double
        let owned: Bool
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    activeCharmSection
                    charmsListSection
                }
                .padding()
            }
            .navigationTitle("Luck Charms")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadCharms()
            }
        }
    }
    
    private var activeCharmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Charm")
                .font(.headline)
                .foregroundColor(primaryText)
            
            if let charm = activeCharm {
                HStack {
                    Image(systemName: charm.icon)
                        .font(.title)
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading) {
                        Text(charm.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(primaryText)
                        Text("\(Int(charm.effect * 100))% chaos boost")
                            .font(.caption)
                            .foregroundColor(accent)
                    }
                    
                    Spacer()
                    
                    Button("Deactivate") {
                        activeCharm = nil
                    }
                    .font(.caption)
                }
                .padding()
                .background(accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("No active charm")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var charmsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Charms")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach(charms) { charm in
                charmCard(charm)
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func charmCard(_ charm: LuckCharm) -> some View {
        HStack {
            Image(systemName: charm.icon)
                .font(.title2)
                .foregroundColor(charm.owned ? .yellow : .gray)
                .frame(width: 50, height: 50)
                .background(charm.owned ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(charm.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryText)
                Text(charm.description)
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
            
            Spacer()
            
            if charm.owned {
                Button {
                    activeCharm = charm
                } label: {
                    Text(activeCharm?.id == charm.id ? "Active" : "Use")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(activeCharm?.id == charm.id ? accent : .gray)
            } else {
                Button("Buy") {}
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
        }
    }
    
    private func loadCharms() {
        charms = [
            LuckCharm(name: "Four Leaf Clover", description: "+25% chaos chance", icon: "leaf.fill", effect: 0.25, owned: true),
            LuckCharm(name: "Lucky Dice", description: "+50% chaos chance", icon: "dice.fill", effect: 0.50, owned: false),
            LuckCharm(name: "Horseshoe", description: "+75% chaos chance", icon: "horseshoe.fill", effect: 0.75, owned: false),
            LuckCharm(name: "Rabbit Foot", description: "+100% chaos chance", icon: "pawprint.fill", effect: 1.0, owned: false),
        ]
        activeCharm = charms.first
    }
}

struct AchievementSoundsView: View {
    @Bindable var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var achievements: [AchievementSound] = []
    
    struct AchievementSound: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let soundName: String
        var enabled: Bool
    }
    
    private var accent: Color { Theme.accent(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    previewSection
                    soundsList
                }
                .padding()
            }
            .navigationTitle("Achievement Sounds")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadSounds()
            }
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .foregroundColor(primaryText)
            
            Button {
                playPreview()
            } label: {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("Play Sample Sound")
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
    
    private var soundsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievement Sounds")
                .font(.headline)
                .foregroundColor(primaryText)
            
            ForEach($achievements) { $achievement in
                Toggle(isOn: $achievement.enabled) {
                    HStack {
                        Image(systemName: achievement.icon)
                            .foregroundColor(accent)
                            .frame(width: 30)
                        Text(achievement.name)
                            .font(.subheadline)
                            .foregroundColor(primaryText)
                    }
                }
            }
        }
        .padding()
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func loadSounds() {
        achievements = [
            AchievementSound(name: "First Advice", icon: "1.circle", soundName: "first_advice", enabled: true),
            AchievementSound(name: "Streak Milestone", icon: "flame.fill", soundName: "streak_milestone", enabled: true),
            AchievementSound(name: "Achievement Unlocked", icon: "trophy.fill", soundName: "achievement", enabled: true),
            AchievementSound(name: "Level Up", icon: "arrow.up.circle.fill", soundName: "level_up", enabled: true),
            AchievementSound(name: "Badge Earned", icon: "star.fill", soundName: "badge", enabled: false),
        ]
    }
    
    private func playPreview() {
        // Play preview sound
    }
}
