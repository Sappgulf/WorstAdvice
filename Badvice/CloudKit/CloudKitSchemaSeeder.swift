#if DEBUG
import CloudKit
import Foundation

enum CloudKitSchemaSeeder {
    private static let didSeedKey = "didSeedCloudKitSchema"

    static func seedIfNeeded(
        userDefaults: UserDefaults = .standard,
        container: CKContainer = .default()
    ) async {
        guard !userDefaults.bool(forKey: didSeedKey) else {
            print("[CloudKitSeed] Schema already seeded on this install.")
            return
        }

        do {
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                print("[CloudKitSeed] iCloud account unavailable: \(describe(accountStatus)).")
                return
            }
        } catch {
            print("[CloudKitSeed] Failed to check iCloud account status: \(error.localizedDescription)")
            return
        }

        let record = CKRecord(recordType: "Advice")
        record["text"] = "Schema seed"
        record["category"] = "Test"
        record["createdAt"] = Date()

        do {
            let savedRecord = try await container.publicCloudDatabase.save(record)
            userDefaults.set(true, forKey: didSeedKey)
            print("[CloudKitSeed] Saved schema seed record \(savedRecord.recordID.recordName).")
        } catch {
            print("[CloudKitSeed] Failed to save schema seed record: \(error.localizedDescription)")
        }
    }

    private static func describe(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "available"
        case .noAccount:
            return "noAccount"
        case .restricted:
            return "restricted"
        case .couldNotDetermine:
            return "couldNotDetermine"
        case .temporarilyUnavailable:
            return "temporarilyUnavailable"
        @unknown default:
            return "unknown"
        }
    }
}
#endif
