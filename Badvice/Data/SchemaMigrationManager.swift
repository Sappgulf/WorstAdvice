import Foundation
import SwiftData

enum SchemaMigrationVersion: String, CaseIterable {
    case v1_initial = "BadviceSchemaV1"
    case v2_socialSchema = "BadviceSchemaV2"
    case v3_contentPacks = "BadviceSchemaV3"
    
    var versionNumber: Int {
        switch self {
        case .v1_initial: return 1
        case .v2_socialSchema: return 2
        case .v3_contentPacks: return 3
        }
    }
}

struct SchemaMigrationManager {
    private static let currentVersionKey = "Badvice.currentSchemaVersion"
    
    static var currentVersion: SchemaMigrationVersion {
        guard let stored = UserDefaults.standard.string(forKey: currentVersionKey),
              let version = SchemaMigrationVersion(rawValue: stored) else {
            return .v1_initial
        }
        return version
    }
    
    static func setVersion(_ version: SchemaMigrationVersion) {
        UserDefaults.standard.set(version.rawValue, forKey: currentVersionKey)
    }
    
    static func performMigrationsIfNeeded(modelContainer: ModelContainer) async throws {
        let current = currentVersion
        
        if current.versionNumber < SchemaMigrationVersion.v2_socialSchema.versionNumber {
            try await migrateToV2(modelContainer: modelContainer)
        }
        
        if current.versionNumber < SchemaMigrationVersion.v3_contentPacks.versionNumber {
            try await migrateToV3(modelContainer: modelContainer)
        }
    }
    
    private static func migrateToV2(modelContainer: ModelContainer) async throws {
        setVersion(.v2_socialSchema)
    }
    
    private static func migrateToV3(modelContainer: ModelContainer) async throws {
        setVersion(.v3_contentPacks)
    }
}
