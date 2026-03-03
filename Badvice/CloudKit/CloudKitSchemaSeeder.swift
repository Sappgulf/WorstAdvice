#if DEBUG
import CloudKit
import Foundation

enum CloudKitSchemaSeeder {
    private static let didSeedKey = "didSeedCloudKitSchema.v2.socialPublic"
    private static let containerIdentifier = "iCloud.com.worstadvice.app"

    static func seedIfNeeded(userDefaults: UserDefaults = .standard) async {
        guard !userDefaults.bool(forKey: didSeedKey) else {
            print("[CloudKitSeed] Social schema already seeded on this install.")
            return
        }

        guard let container = makeContainerForSeeding() else {
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

        let records = makeSeedRecords()

        do {
            for record in records {
                let savedRecord = try await container.publicCloudDatabase.save(record)
                print(
                    "[CloudKitSeed] Saved \(savedRecord.recordType) record \(savedRecord.recordID.recordName)."
                )
            }
            userDefaults.set(true, forKey: didSeedKey)
            print("[CloudKitSeed] Seeded public social schema with \(records.count) records.")
        } catch {
            print("[CloudKitSeed] Failed to seed public social schema: \(error.localizedDescription)")
        }
    }

    private static func makeSeedRecords(referenceDate: Date = Date()) -> [CKRecord] {
        let userARecordID = CKRecord.ID(recordName: "debug_schema_seed_user_a_v2")
        let userBRecordID = CKRecord.ID(recordName: "debug_schema_seed_user_b_v2")

        let userA = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.user,
            recordID: userARecordID
        )
        userA[CloudKitSocialSchema.Field.handle] = "seedusera"
        userA[CloudKitSocialSchema.Field.displayName] = "Schema Seed A"
        userA[CloudKitSocialSchema.Field.createdAt] = referenceDate

        let userB = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.user,
            recordID: userBRecordID
        )
        userB[CloudKitSocialSchema.Field.handle] = "seeduserb"
        userB[CloudKitSocialSchema.Field.displayName] = "Schema Seed B"
        userB[CloudKitSocialSchema.Field.createdAt] = referenceDate

        let userAReference = CKRecord.Reference(recordID: userARecordID, action: .none)
        let userBReference = CKRecord.Reference(recordID: userBRecordID, action: .none)

        let friendRequest = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.friendRequest,
            recordID: CKRecord.ID(recordName: "debug_schema_seed_friend_request_v2")
        )
        friendRequest[CloudKitSocialSchema.Field.fromUserRef] = userAReference
        friendRequest[CloudKitSocialSchema.Field.toUserRef] = userBReference
        friendRequest[CloudKitSocialSchema.Field.status] = SocialFriendRequestStatus.pending.rawValue
        friendRequest[CloudKitSocialSchema.Field.createdAt] = referenceDate

        let friendEdge = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.friendEdge,
            recordID: CKRecord.ID(recordName: "debug_schema_seed_friend_edge_v2")
        )
        friendEdge[CloudKitSocialSchema.Field.aUserRef] = userAReference
        friendEdge[CloudKitSocialSchema.Field.bUserRef] = userBReference
        friendEdge[CloudKitSocialSchema.Field.since] = referenceDate

        let post = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.post,
            recordID: CKRecord.ID(recordName: "debug_schema_seed_post_v2")
        )
        post[CloudKitSocialSchema.Field.authorRef] = userAReference
        post[CloudKitSocialSchema.Field.type] = SocialPostType.advice.rawValue
        post[CloudKitSocialSchema.Field.text] = "Schema seed"
        post[CloudKitSocialSchema.Field.visibility] = SocialPostVisibility.friends.rawValue
        post[CloudKitSocialSchema.Field.createdAt] = referenceDate

        let chaosScore = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.chaosScore,
            recordID: CKRecord.ID(recordName: "debug_schema_seed_chaos_score_v2")
        )
        chaosScore[CloudKitSocialSchema.Field.seasonId] = "debug-seed"
        chaosScore[CloudKitSocialSchema.Field.userRef] = userAReference
        chaosScore[CloudKitSocialSchema.Field.score] = NSNumber(value: 13)
        chaosScore[CloudKitSocialSchema.Field.updatedAt] = referenceDate

        let collabDoc = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.collabDoc,
            recordID: CKRecord.ID(recordName: "debug_schema_seed_collab_doc_v2")
        )
        collabDoc[CloudKitSocialSchema.Field.ownerRef] = userAReference
        collabDoc[CloudKitSocialSchema.Field.contributorsRefs] = [userBReference]
        collabDoc[CloudKitSocialSchema.Field.type] = SocialPostType.quote.rawValue
        collabDoc[CloudKitSocialSchema.Field.content] = "Schema seed"
        collabDoc[CloudKitSocialSchema.Field.version] = NSNumber(value: 1)
        collabDoc[CloudKitSocialSchema.Field.createdAt] = referenceDate
        collabDoc[CloudKitSocialSchema.Field.updatedAt] = referenceDate

        let moderationReport = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.moderationReport,
            recordID: CKRecord.ID(recordName: "debug_schema_seed_moderation_report_v2")
        )
        moderationReport[CloudKitSocialSchema.Field.clientReportID] = "debug-schema-seed-v2"
        moderationReport[CloudKitSocialSchema.Field.targetType] = "post"
        moderationReport[CloudKitSocialSchema.Field.targetRecordName] = post.recordID.recordName
        moderationReport[CloudKitSocialSchema.Field.reporterHandle] = "seedusera"
        moderationReport[CloudKitSocialSchema.Field.reason] = "Schema seed"
        moderationReport[CloudKitSocialSchema.Field.createdAt] = referenceDate

        return [userA, userB, friendRequest, friendEdge, post, chaosScore, collabDoc, moderationReport]
    }

    private static func makeContainerForSeeding() -> CKContainer? {
        #if targetEnvironment(simulator)
            print("[CloudKitSeed] Skipping schema seed in Simulator; CloudKit requires a signed app entitlement.")
            return nil
        #else
            return CKContainer(identifier: containerIdentifier)
        #endif
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
