import SwiftData
import Foundation

enum PreviewHelper {
    @MainActor
    static var previewContext: ModelContext {
        let config = ModelConfiguration(
            "Preview",
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        let container = try! ModelContainer(
            for: AdviceRecord.self,
            AdviceFingerprint.self,
            UserAdviceSuggestion.self,
            UserQuoteSuggestion.self,
            QuoteVoteRecord.self,
            AppSettingsEntity.self,
            configurations: config
        )
        return ModelContext(container)
    }
}
