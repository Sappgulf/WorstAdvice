import Foundation

// MARK: - Model

struct Advice: Identifiable, Equatable {
    let id: UUID
    let text: String
    let category: AdviceCategory

    init(id: UUID = UUID(), text: String, category: AdviceCategory) {
        self.id = id
        self.text = text
        self.category = category
    }
}

enum AdviceCategory: String, CaseIterable, Identifiable {
    case health      = "Health 🩺"
    case finance     = "Finance 💸"
    case career      = "Career 💼"
    case relationship = "Relationships 💔"
    case food        = "Food 🍕"
    case tech        = "Tech 🤖"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .health:       return "🩺"
        case .finance:      return "💸"
        case .career:       return "💼"
        case .relationship: return "💔"
        case .food:         return "🍕"
        case .tech:         return "🤖"
        }
    }

    var color: String {
        switch self {
        case .health:       return "red"
        case .finance:      return "green"
        case .career:       return "blue"
        case .relationship: return "pink"
        case .food:         return "orange"
        case .tech:         return "purple"
        }
    }
}

// MARK: - Advice Bank

struct AdviceBank {
    static let all: [Advice] = [
        // Health
        Advice(text: "If it hurts, ignore it. Pain is just weakness leaving the body — or something way worse. Flip a coin.", category: .health),
        Advice(text: "You don't need eight hours of sleep. You need eight hours of scrolling. Same energy.", category: .health),
        Advice(text: "WebMD says you probably have everything. Treat all of them at once just to be safe.", category: .health),
        Advice(text: "Sunscreen is for people who are afraid of the sun. Be brave.", category: .health),
        Advice(text: "Running is bad for your knees. Stay seated permanently. Problem solved.", category: .health),

        // Finance
        Advice(text: "Put everything into a single stock your cousin mentioned at a BBQ. Sure thing.", category: .finance),
        Advice(text: "Why save for retirement? You can just work until you're 97. Keeps you young!", category: .finance),
        Advice(text: "Budget? Nah. Money is just vibes. Spend the vibes.", category: .finance),
        Advice(text: "If your bank balance is low, just stop checking it. Out of sight, out of debt.", category: .finance),
        Advice(text: "Invest in beanie babies. The market correction is coming. Trust the plush.", category: .finance),

        // Career
        Advice(text: "Tell your boss they're wrong in the all-hands meeting. Power move. Respect.", category: .career),
        Advice(text: "Never update your resume. If they want you, they'll find you. Like a treasure hunt.", category: .career),
        Advice(text: "Show up two hours late every day. It signals you're busy and important.", category: .career),
        Advice(text: "CC your entire company on every email. Transparency is a virtue.", category: .career),
        Advice(text: "Reply-all to unsubscribe from company mailing lists. Classic.", category: .career),

        // Relationships
        Advice(text: "Never apologize. It shows weakness. Double down on every argument instead.", category: .relationship),
        Advice(text: "Text your ex at 2am. They were probably just thinking about you anyway.", category: .relationship),
        Advice(text: "Play hard to get by ghosting everyone you like. Mystery is attractive.", category: .relationship),
        Advice(text: "Correct your partner's grammar mid-argument. Really makes your point land.", category: .relationship),
        Advice(text: "Share their deepest secret at the dinner party. They'll appreciate the openness.", category: .relationship),

        // Food
        Advice(text: "The five second rule applies to everything, including soup.", category: .food),
        Advice(text: "Meal prep is for people with too much free time. Just panic-eat whatever's around.", category: .food),
        Advice(text: "Sushi is just a suggestion. All fish can be raw fish if you're brave enough.", category: .food),
        Advice(text: "If it's expired by only a month, give it a smell. The nose knows.", category: .food),
        Advice(text: "Cereal is a soup. Act accordingly by ordering it at restaurants.", category: .food),

        // Tech
        Advice(text: "Use 'password' as your password. Easy to remember. Very secure feeling.", category: .tech),
        Advice(text: "Never update your software. The new version probably has bugs.", category: .tech),
        Advice(text: "Clicking 'skip backup' every time is fine. Nothing ever goes wrong.", category: .tech),
        Advice(text: "Reply to every spam email asking to be removed. That's how it works.", category: .tech),
        Advice(text: "Turn it off and on again is a myth invented by IT to make themselves feel needed.", category: .tech),
    ]

    static func random(excluding current: Advice? = nil) -> Advice {
        var pool = all
        if let current, pool.count > 1 {
            pool.removeAll { $0.id == current.id }
        }
        return pool.randomElement() ?? all[0]
    }

    static func random(for category: AdviceCategory, excluding current: Advice? = nil) -> Advice {
        var pool = all.filter { $0.category == category }
        if pool.isEmpty { return random(excluding: current) }
        if let current, pool.count > 1 {
            pool.removeAll { $0.id == current.id }
        }
        return pool.randomElement() ?? pool[0]
    }
}

// MARK: - View Model

@Observable
final class AdviceViewModel {
    private(set) var currentAdvice: Advice
    private(set) var favoriteIDs: Set<UUID> = []
    var selectedCategory: AdviceCategory? = nil
    private(set) var dealCount: Int = 0

    init() {
        self.currentAdvice = AdviceBank.random()
    }

    var isFavorited: Bool {
        favoriteIDs.contains(currentAdvice.id)
    }

    var favorites: [Advice] {
        AdviceBank.all.filter { favoriteIDs.contains($0.id) }
    }

    func dealNewAdvice() {
        if let category = selectedCategory {
            currentAdvice = AdviceBank.random(for: category, excluding: currentAdvice)
        } else {
            currentAdvice = AdviceBank.random(excluding: currentAdvice)
        }
        dealCount += 1
    }

    func toggleFavorite() {
        if favoriteIDs.contains(currentAdvice.id) {
            favoriteIDs.remove(currentAdvice.id)
        } else {
            favoriteIDs.insert(currentAdvice.id)
        }
    }
}
