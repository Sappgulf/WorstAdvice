import CoreSpotlight
import Foundation
import MobileCoreServices
import OSLog

private let spotlightLogger = Logger(subsystem: "com.worstadvice.app", category: "spotlight")

// MARK: - Spotlight Search Indexing (#18)

enum SpotlightManager {

    static let domainIdentifier = "com.worstadvice.app.advice"

    // MARK: Index a saved advice record

    static func index(_ record: AdviceRecord) {
        let item = searchableItem(for: record)
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                spotlightLogger.error("Spotlight index failed for \(record.id): \(error.localizedDescription)")
            }
        }
    }

    static func indexBatch(_ records: [AdviceRecord]) {
        guard !records.isEmpty else { return }
        let items = records.map { searchableItem(for: $0) }
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                spotlightLogger.error("Spotlight batch index failed: \(error.localizedDescription)")
            } else {
                spotlightLogger.info("Spotlight indexed \(items.count) items")
            }
        }
    }

    // MARK: Remove

    static func remove(id: UUID) {
        let identifier = spotlightID(for: id)
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier]) { error in
            if let error {
                spotlightLogger.error("Spotlight remove failed for \(id): \(error.localizedDescription)")
            }
        }
    }

    static func removeAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error {
                spotlightLogger.error("Spotlight removeAll failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Handle incoming activity

    /// Call from `onContinueUserActivity` in the app entry point.
    /// Returns the advice UUID if the activity is a Spotlight selection.
    static func adviceID(from userActivity: NSUserActivity) -> UUID? {
        guard userActivity.activityType == CSSearchableItemActionType else { return nil }
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return nil }
        // identifier format: "com.worstadvice.app.advice.<uuid>"
        let prefix = domainIdentifier + "."
        guard identifier.hasPrefix(prefix) else { return nil }
        let uuidString = String(identifier.dropFirst(prefix.count))
        return UUID(uuidString: uuidString)
    }

    // MARK: Private helpers

    private static func spotlightID(for id: UUID) -> String {
        "\(domainIdentifier).\(id.uuidString)"
    }

    private static func searchableItem(for record: AdviceRecord) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = record.adviceLine
        attributeSet.contentDescription = [
            record.category.title,
            record.tone.title,
            record.rationaleLine,
        ].compactMap { $0 }.joined(separator: " · ")
        attributeSet.keywords = [
            record.category.title,
            record.tone.title,
            "badvice",
            "bad advice",
            record.isFavorite ? "favorite" : nil,
        ].compactMap { $0 }
        attributeSet.domainIdentifier = domainIdentifier

        return CSSearchableItem(
            uniqueIdentifier: spotlightID(for: record.id),
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
    }
}

// MARK: - AdviceRecord Spotlight helpers (depends on AdviceRecord from AppState)

extension AdviceRecord {
    func indexInSpotlight() {
        SpotlightManager.index(self)
    }

    func removeFromSpotlight() {
        SpotlightManager.remove(id: id)
    }
}
