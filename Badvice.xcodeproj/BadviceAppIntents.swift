import AppIntents
import SwiftUI

// MARK: - App Shortcuts for Siri

@available(iOS 16.0, *)
struct BadviceAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GenerateAdviceIntent(),
            phrases: [
                "Give me bad advice in \(.applicationName)",
                "Generate advice in \(.applicationName)",
                "Need some \(.applicationName)",
                "Hit me with some chaos from \(.applicationName)"
            ],
            shortTitle: "Generate Advice",
            systemImageName: "sparkles"
        )
        
        AppShortcut(
            intent: GenerateCategoryAdviceIntent(),
            phrases: [
                "Give me \(\.$category) advice in \(.applicationName)",
                "Generate \(\.$category) advice in \(.applicationName)",
                "Bad \(\.$category) advice from \(.applicationName)"
            ],
            shortTitle: "Category Advice",
            systemImageName: "list.bullet"
        )
        
        AppShortcut(
            intent: ViewFavoritesIntent(),
            phrases: [
                "Show my favorites in \(.applicationName)",
                "View saved advice in \(.applicationName)",
                "My bookmarked advice from \(.applicationName)"
            ],
            shortTitle: "View Favorites",
            systemImageName: "bookmark.fill"
        )
        
        AppShortcut(
            intent: GetDailyQuoteIntent(),
            phrases: [
                "What's today's bad quote",
                "Give me the quote of the day from \(.applicationName)",
                "Daily bad quote from \(.applicationName)"
            ],
            shortTitle: "Daily Quote",
            systemImageName: "quote.bubble"
        )
        
        AppShortcut(
            intent: ShareRandomAdviceIntent(),
            phrases: [
                "Share a random bad advice from \(.applicationName)",
                "Send someone terrible guidance from \(.applicationName)"
            ],
            shortTitle: "Share Advice",
            systemImageName: "square.and.arrow.up"
        )
    }
}

// MARK: - Generate Advice Intent

@available(iOS 16.0, *)
struct GenerateAdviceIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Bad Advice"
    static var description = IntentDescription("Generate a fresh piece of confidently terrible advice")
    
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true
    
    @Parameter(title: "Include Rationale", default: true)
    var includeRationale: Bool
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Generate advice using the engine
        let randomCategory = AdviceCategory.allCases.randomElement()!
        let randomTone = ToneMode.allCases.randomElement()!
        
        let advice = try await generateQuickAdvice(
            category: randomCategory,
            tone: randomTone,
            includeRationale: includeRationale
        )
        
        let dialog = IntentDialog(stringLiteral: advice.adviceLine)
        
        return .result(
            dialog: dialog,
            view: AdviceSnippetView(advice: advice)
        )
    }
    
    private func generateQuickAdvice(category: AdviceCategory, tone: ToneMode, includeRationale: Bool) async throws -> QuickAdvice {
        // Simplified generation for Siri context
        let adviceLines = [
            "If nobody understands the plan, call it leadership.",
            "Confidence is just preparation wearing a disguise.",
            "The best to-do list is six lists competing for attention.",
            "Multitasking is focus wearing a trench coat.",
            "If the timeline slips, rename the milestone."
        ]
        
        let rationales = [
            "Because clarity is overrated when you can leverage ambiguity.",
            "Strategic visibility beats actual competence.",
            "Parallel thinking maximizes cognitive overhead.",
            "Context-switching builds resilience through confusion.",
            "Perception management supersedes delivery cadence."
        ]
        
        let advice = adviceLines.randomElement()!
        let rationale = includeRationale ? rationales.randomElement()! : nil
        
        return QuickAdvice(
            adviceLine: advice,
            rationaleLine: rationale,
            category: category,
            tone: tone
        )
    }
}

// MARK: - Generate Category Advice Intent

@available(iOS 16.0, *)
struct GenerateCategoryAdviceIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Advice by Category"
    static var description = IntentDescription("Generate bad advice for a specific category")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Category")
    var category: AdviceCategory
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let advice = getCategoryAdvice(category: category)
        return .result(dialog: IntentDialog(stringLiteral: advice))
    }
    
    private func getCategoryAdvice(category: AdviceCategory) -> String {
        let adviceByCategory: [AdviceCategory: [String]] = [
            .dating: [
                "Mixed signals are premium communication.",
                "Reply slower to seem premium, not available.",
                "If you are confused, assume it is chemistry scaling."
            ],
            .career: [
                "If nobody understands the plan, call it leadership.",
                "Never answer a question when a framework could answer nothing.",
                "If the project is late, promote the update cadence."
            ],
            .fitness: [
                "Recovery is what people do before mediocrity.",
                "Hydration is nice, but caffeine is decisive.",
                "If your legs work tomorrow, you underperformed today."
            ],
            .money: [
                "A budget is just a rumor your future self can deny.",
                "Impulse spending is just rapid portfolio rebalancing.",
                "Credit limits are aspiration ceilings, not warnings."
            ],
            .tech: [
                "If it compiles once, deployment is emotional support.",
                "Documentation is a confidence leak.",
                "Security reviews are what you do after launch day."
            ],
            .productivity: [
                "The best to-do list is six lists competing for attention.",
                "Multitasking is focus wearing a trench coat.",
                "If everything is urgent, delegation feels optional."
            ],
            .social: [
                "Always overshare first so nobody can interrupt your narrative.",
                "Every awkward silence is a branding opportunity.",
                "Give advice no one asked for, then call it love."
            ],
            .cooking: [
                "If dinner is late, call it a tasting experience.",
                "A burnt edge is just a flavor thesis.",
                "Measure with your heart, troubleshoot with takeout."
            ],
            .travel: [
                "Layovers are just surprise networking opportunities.",
                "If you miss the train, the city wanted you elsewhere.",
                "Jet lag is just immersive timezone networking."
            ],
            .parenting: [
                "Consistency is optional if your confidence is loud enough.",
                "Bedtime negotiations build executive communication skills.",
                "Screen time rules are strongest when frequently renegotiated."
            ]
        ]
        
        let options = adviceByCategory[category] ?? ["Something has gone terribly wrong with this advice generator."]
        return options.randomElement()!
    }
}

// MARK: - View Favorites Intent

@available(iOS 16.0, *)
struct ViewFavoritesIntent: AppIntent {
    static var title: LocalizedStringResource = "View Favorites"
    static var description = IntentDescription("View your saved advice")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // Open app to favorites tab
        return .result()
    }
}

// MARK: - Daily Quote Intent

@available(iOS 16.0, *)
struct GetDailyQuoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Daily Quote"
    static var description = IntentDescription("Get today's bad quote")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let quote = getDailyQuote()
        
        let dialog = IntentDialog("Today's bad quote: \"\(quote.text)\" - \(quote.source)")
        
        return .result(
            dialog: dialog,
            view: QuoteSnippetView(quote: quote)
        )
    }
    
    private func getDailyQuote() -> DailyQuote {
        let quotes = [
            DailyQuote(text: "If nobody understands the plan, call it leadership.", source: "Quarterly Wisdom Deck"),
            DailyQuote(text: "A budget is just a rumor your future self can deny.", source: "Finance Group Chat"),
            DailyQuote(text: "Mixed signals are premium communication.", source: "Unlicensed Relationship Coach"),
            DailyQuote(text: "Multitasking is focus wearing a trench coat.", source: "Calendar Economist")
        ]
        
        let day = Calendar.current.dateComponents([.day], from: Date()).day ?? 0
        return quotes[day % quotes.count]
    }
}

// MARK: - Share Advice Intent

@available(iOS 16.0, *)
struct ShareRandomAdviceIntent: AppIntent {
    static var title: LocalizedStringResource = "Share Random Advice"
    static var description = IntentDescription("Share a random piece of bad advice")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // This would open share sheet in the app
        return .result()
    }
}

// MARK: - Snippet Views

@available(iOS 16.0, *)
struct AdviceSnippetView: View {
    let advice: QuickAdvice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(advice.category.title, systemImage: advice.category.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                
                Spacer()
                
                Text(advice.tone.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(advice.adviceLine)
                .font(.headline)
                .foregroundStyle(.primary)
            
            if let rationale = advice.rationaleLine {
                Divider()
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    
                    Text(rationale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

@available(iOS 16.0, *)
struct QuoteSnippetView: View {
    let quote: DailyQuote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.title)
                .foregroundStyle(.orange.opacity(0.3))
            
            Text(quote.text)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("— \(quote.source)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
            
            Divider()
            
            Text("Badvice")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Data Models

struct QuickAdvice {
    let adviceLine: String
    let rationaleLine: String?
    let category: AdviceCategory
    let tone: ToneMode
}

struct DailyQuote {
    let text: String
    let source: String
}

// MARK: - AdviceCategory AppEnum

@available(iOS 16.0, *)
extension AdviceCategory: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Advice Category")
    }
    
    static var caseDisplayRepresentations: [AdviceCategory: DisplayRepresentation] {
        [
            .dating: DisplayRepresentation(title: "Dating", image: .init(systemName: "heart")),
            .fitness: DisplayRepresentation(title: "Fitness", image: .init(systemName: "dumbbell")),
            .career: DisplayRepresentation(title: "Career", image: .init(systemName: "briefcase")),
            .money: DisplayRepresentation(title: "Money", image: .init(systemName: "dollarsign.circle")),
            .parenting: DisplayRepresentation(title: "Parenting", image: .init(systemName: "figure.2.and.child.holdinghands")),
            .tech: DisplayRepresentation(title: "Tech", image: .init(systemName: "desktopcomputer")),
            .social: DisplayRepresentation(title: "Social", image: .init(systemName: "person.3")),
            .cooking: DisplayRepresentation(title: "Cooking", image: .init(systemName: "fork.knife")),
            .travel: DisplayRepresentation(title: "Travel", image: .init(systemName: "airplane")),
            .productivity: DisplayRepresentation(title: "Productivity", image: .init(systemName: "checklist"))
        ]
    }
}
