import UIKit

enum QuickActionsManager {
    enum ActionType: String {
        case generateAdvice = "com.badvice.generate"
        case viewFavorites = "com.badvice.favorites"
        case dailyQuote = "com.badvice.dailyquote"
        case randomCategory = "com.badvice.random"
    }
    
    static func setupQuickActions() {
        let generateAction = UIApplicationShortcutItem(
            type: ActionType.generateAdvice.rawValue,
            localizedTitle: "Generate Advice",
            localizedSubtitle: "Get fresh bad advice",
            icon: UIApplicationShortcutIcon(systemImageName: "sparkles"),
            userInfo: nil
        )
        
        let favoritesAction = UIApplicationShortcutItem(
            type: ActionType.viewFavorites.rawValue,
            localizedTitle: "View Favorites",
            localizedSubtitle: "See saved advice",
            icon: UIApplicationShortcutIcon(systemImageName: "bookmark.fill"),
            userInfo: nil
        )
        
        let dailyQuoteAction = UIApplicationShortcutItem(
            type: ActionType.dailyQuote.rawValue,
            localizedTitle: "Quote of the Day",
            localizedSubtitle: "Today's bad quote",
            icon: UIApplicationShortcutIcon(systemImageName: "quote.bubble"),
            userInfo: nil
        )
        
        let randomAction = UIApplicationShortcutItem(
            type: ActionType.randomCategory.rawValue,
            localizedTitle: "Surprise Me",
            localizedSubtitle: "Random category advice",
            icon: UIApplicationShortcutIcon(systemImageName: "dice"),
            userInfo: nil
        )
        
        UIApplication.shared.shortcutItems = [
            generateAction,
            favoritesAction,
            dailyQuoteAction,
            randomAction
        ]
    }
    
    static func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> QuickActionResult? {
        guard let actionType = ActionType(rawValue: shortcutItem.type) else {
            return nil
        }
        
        switch actionType {
        case .generateAdvice:
            return .generate
        case .viewFavorites:
            return .showFavorites
        case .dailyQuote:
            return .showDailyQuote
        case .randomCategory:
            return .generateRandom
        }
    }
    
    enum QuickActionResult {
        case generate
        case showFavorites
        case showDailyQuote
        case generateRandom
    }
}
