import Foundation
import UIKit

// MARK: - Handoff & Continuity Manager

class HandoffManager: NSObject {
    static let shared = HandoffManager()
    
    private override init() {
        super.init()
    }
    
    // MARK: - User Activity Types
    
    enum ActivityType: String {
        case viewingAdvice = "com.badvice.viewingAdvice"
        case generatingAdvice = "com.badvice.generatingAdvice"
        case browsingFavorites = "com.badvice.browsingFavorites"
        case viewingStats = "com.badvice.viewingStats"
        
        var title: String {
            switch self {
            case .viewingAdvice: return "Viewing Advice"
            case .generatingAdvice: return "Generating Advice"
            case .browsingFavorites: return "Browsing Favorites"
            case .viewingStats: return "Viewing Statistics"
            }
        }
    }
    
    // MARK: - Create User Activities
    
    func createViewingActivity(for record: AdviceRecord) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.viewingAdvice.rawValue)
        
        activity.title = ActivityType.viewingAdvice.title
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        
        // Add user info for restoration
        activity.addUserInfoEntries(from: [
            "adviceId": record.id.uuidString,
            "category": record.category.rawValue,
            "tone": record.tone.rawValue,
            "adviceLine": record.adviceLine
        ])
        
        // Add keywords for Spotlight
        let keywords: Set<String> = [
            record.category.title.lowercased(),
            record.tone.title.lowercased(),
            "advice",
            "badvice"
        ]
        activity.keywords = keywords
        
        // Set suggested invocation phrase for Siri
        activity.suggestedInvocationPhrase = "Show my advice"
        
        return activity
    }
    
    func createGeneratingActivity(category: AdviceCategory, tone: ToneMode) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.generatingAdvice.rawValue)
        
        activity.title = "Generating \(category.title) Advice"
        activity.isEligibleForHandoff = true
        activity.isEligibleForPrediction = true
        
        activity.addUserInfoEntries(from: [
            "category": category.rawValue,
            "tone": tone.rawValue
        ])
        
        activity.keywords = Set([
            category.title.lowercased(),
            "generate",
            "advice"
        ])
        
        return activity
    }
    
    func createBrowsingFavoritesActivity() -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.browsingFavorites.rawValue)
        
        activity.title = ActivityType.browsingFavorites.title
        activity.isEligibleForHandoff = true
        activity.isEligibleForPrediction = true
        
        activity.suggestedInvocationPhrase = "Show my favorites"
        
        return activity
    }
    
    func createViewingStatsActivity() -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.viewingStats.rawValue)
        
        activity.title = ActivityType.viewingStats.title
        activity.isEligibleForHandoff = true
        
        return activity
    }
    
    // MARK: - Restore from Activity
    
    func restoreState(from activity: NSUserActivity) -> RestorationResult? {
        guard let activityType = ActivityType(rawValue: activity.activityType) else {
            return nil
        }
        
        switch activityType {
        case .viewingAdvice:
            guard let userInfo = activity.userInfo,
                  let adviceId = userInfo["adviceId"] as? String,
                  let uuid = UUID(uuidString: adviceId),
                  let categoryRaw = userInfo["category"] as? String,
                  let category = AdviceCategory(rawValue: categoryRaw) else {
                return nil
            }
            return .viewAdvice(id: uuid, category: category)
            
        case .generatingAdvice:
            guard let userInfo = activity.userInfo,
                  let categoryRaw = userInfo["category"] as? String,
                  let category = AdviceCategory(rawValue: categoryRaw),
                  let toneRaw = userInfo["tone"] as? String,
                  let tone = ToneMode(rawValue: toneRaw) else {
                return nil
            }
            return .generateAdvice(category: category, tone: tone)
            
        case .browsingFavorites:
            return .showFavorites
            
        case .viewingStats:
            return .showStats
        }
    }
    
    enum RestorationResult {
        case viewAdvice(id: UUID, category: AdviceCategory)
        case generateAdvice(category: AdviceCategory, tone: ToneMode)
        case showFavorites
        case showStats
    }
}

// MARK: - Universal Clipboard Support

class UniversalClipboardManager {
    static let shared = UniversalClipboardManager()
    
    private init() {}
    
    func copyAdviceUniversally(_ record: AdviceRecord) {
        // Create a rich pasteboard item
        let pasteboard = UIPasteboard.general
        
        // Plain text version
        let plainText = record.adviceLine
        
        // HTML version for rich formatting
        let htmlText = """
        <div style="font-family: -apple-system; padding: 20px; background: #f5f5f5; border-radius: 12px;">
            <h3 style="color: #E07A5F; margin-bottom: 10px;">\(record.category.title) - \(record.tone.title)</h3>
            <p style="font-size: 18px; font-weight: 600; color: #1C1C1E; margin: 15px 0;">\(record.adviceLine)</p>
            \(record.rationaleLine.map { "<p style=\"font-size: 14px; color: #666; font-style: italic;\">\($0)</p>" } ?? "")
            <p style="font-size: 12px; color: #999; margin-top: 15px;">— Badvice</p>
        </div>
        """
        
        // JSON version for structured data
        let jsonData: [String: Any] = [
            "app": "Badvice",
            "version": "1.0",
            "advice": [
                "id": record.id.uuidString,
                "category": record.category.rawValue,
                "tone": record.tone.rawValue,
                "adviceLine": record.adviceLine,
                "rationaleLine": record.rationaleLine as Any,
                "createdAt": ISO8601DateFormatter().string(from: record.createdAt)
            ]
        ]
        
        // Set multiple representations
        var items: [[String: Any]] = []
        
        // Plain text
        items.append([UIPasteboard.typeAutomatic: plainText])
        
        // HTML
        if let htmlData = htmlText.data(using: .utf8) {
            items.append(["public.html": htmlData])
        }
        
        // JSON
        if let jsonText = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted) {
            items.append(["public.json": jsonText])
        }
        
        pasteboard.setItems(items, options: [.expirationDate: Date().addingTimeInterval(300)])
        
        // Haptic feedback
        HapticsManager.playSelection(isEnabled: true)
    }
    
    func pasteAdviceFromClipboard() -> AdviceRecord? {
        let pasteboard = UIPasteboard.general
        
        // Try to get JSON data
        if let jsonData = pasteboard.data(forPasteboardType: "public.json"),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let adviceDict = json["advice"] as? [String: Any],
           let categoryRaw = adviceDict["category"] as? String,
           let category = AdviceCategory(rawValue: categoryRaw),
           let toneRaw = adviceDict["tone"] as? String,
           let tone = ToneMode(rawValue: toneRaw),
           let adviceLine = adviceDict["adviceLine"] as? String {
            
            let rationaleLine = adviceDict["rationaleLine"] as? String
            
            return AdviceRecord(
                createdAt: Date(),
                category: category,
                tone: tone,
                adviceLine: adviceLine,
                rationaleLine: rationaleLine
            )
        }
        
        return nil
    }
}

// MARK: - Drag & Drop Support

import UniformTypeIdentifiers

extension AdviceRecord {
    var dragItem: UIDragItem {
        let itemProvider = NSItemProvider()
        
        // Add plain text
        itemProvider.registerDataRepresentation(
            forTypeIdentifier: UTType.plainText.identifier,
            visibility: .all
        ) { completion in
            let data = self.adviceLine.data(using: .utf8)
            completion(data, nil)
            return nil
        }
        
        // Add JSON
        let jsonData: [String: Any] = [
            "id": self.id.uuidString,
            "category": self.category.rawValue,
            "tone": self.tone.rawValue,
            "adviceLine": self.adviceLine,
            "rationaleLine": self.rationaleLine as Any
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: jsonData) {
            itemProvider.registerDataRepresentation(
                forTypeIdentifier: UTType.json.identifier,
                visibility: .all
            ) { completion in
                completion(data, nil)
                return nil
            }
        }
        
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = self
        
        return dragItem
    }
}

// MARK: - AirDrop Quick Share

class AirDropManager {
    static let shared = AirDropManager()
    
    private init() {}
    
    func shareViaAirDrop(advice: AdviceRecord, from viewController: UIViewController) {
        let shareText = """
        \(advice.adviceLine)
        
        Category: \(advice.category.title) | Tone: \(advice.tone.title)
        \(advice.rationaleLine.map { "\n\($0)" } ?? "")
        
        — Shared from Badvice
        """
        
        // Create share card image
        let shareCard = ShareCardRenderer.render(content: ShareCardContent(
            category: advice.category,
            tone: advice.tone,
            adviceLine: advice.adviceLine,
            rationaleLine: advice.rationaleLine,
            includeDisclaimer: true,
            template: .gradient,
            aspectRatio: .square
        ))
        
        let items: [Any] = [shareText, shareCard]
        
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Prioritize AirDrop
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks
        ]
        
        // iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityVC, animated: true)
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

extension View {
    func setupHandoff(for record: AdviceRecord) -> some View {
        self.userActivity(HandoffManager.ActivityType.viewingAdvice.rawValue) { activity in
            let handoffActivity = HandoffManager.shared.createViewingActivity(for: record)
            activity.title = handoffActivity.title
            activity.userInfo = handoffActivity.userInfo
            activity.keywords = handoffActivity.keywords
            activity.isEligibleForHandoff = true
            activity.isEligibleForSearch = true
        }
    }
    
    func onDrag(advice: AdviceRecord) -> some View {
        self.onDrag {
            NSItemProvider(object: advice.adviceLine as NSString)
        }
    }
}
