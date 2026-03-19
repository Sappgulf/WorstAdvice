import CloudKit
import Foundation
import OSLog

extension Notification.Name {
    static let cloudKitSchemaSeederDidSeedDevelopmentSchema = Notification.Name(
        "CloudKitSchemaSeeder.didSeedDevelopmentSchema"
    )
}

enum CloudKitSchemaSeedStatus {
    case alreadySeeded
    case skippedSimulator
    case unavailableAccount(String)
    case seeded(recordCount: Int)
    case failed(String)

    var toastMessage: String {
        switch self {
        case .alreadySeeded:
            return "CloudKit development schema is already bootstrapped on this install."
        case .skippedSimulator:
            return "CloudKit bootstrap is skipped in the simulator."
        case .unavailableAccount(let status):
            return "CloudKit unavailable: \(status)."
        case .seeded(let recordCount):
            return "CloudKit development schema bootstrapped with \(recordCount) records."
        case .failed(let message):
            return message
        }
    }

    var isError: Bool {
        switch self {
        case .unavailableAccount, .failed:
            return true
        case .alreadySeeded, .skippedSimulator, .seeded:
            return false
        }
    }
}

enum CloudKitSchemaSeeder {
    private static let logger = Logger(subsystem: "com.worstadvice.app", category: "CloudKitSeed")

    private enum SeedValues {
        static let userAHandle = "seedusera"
        static let userBHandle = "seeduserb"
        static let friendRequestRecordName = "debug_schema_seed_friend_request_v3"
        static let friendEdgeRecordName = "debug_schema_seed_friend_edge_v3"
        static let postRecordName = "debug_schema_seed_post_v3"
        static let chaosScoreRecordName = "debug_schema_seed_chaos_score_v3"
        static let collabDocRecordName = "debug_schema_seed_collab_doc_v3"
        static let moderationReportRecordName = "debug_schema_seed_moderation_report_v3"
        static let seasonID = "debug-seed-v3"
        static let moderationClientReportID = "debug-schema-seed-v3"
    }

    private static let didSeedKey = "didSeedCloudKitSchema.v3.socialBootstrap"
    static func seedIfNeeded(userDefaults: UserDefaults = .standard) async -> CloudKitSchemaSeedStatus {
        guard !userDefaults.bool(forKey: didSeedKey) else {
            logger.info("Social schema already seeded on this install.")
            return .alreadySeeded
        }

        return await seed(
            container: makeContainerForSeeding(),
            userDefaults: userDefaults
        )
    }

    static func forceReseed(userDefaults: UserDefaults = .standard) async -> CloudKitSchemaSeedStatus {
        userDefaults.removeObject(forKey: didSeedKey)
        return await seed(
            container: makeContainerForSeeding(),
            userDefaults: userDefaults
        )
    }

    private static func seed(
        container: CKContainer?,
        userDefaults: UserDefaults
    ) async -> CloudKitSchemaSeedStatus {
        guard let container else {
            return .skippedSimulator
        }

        do {
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                logger.warning("iCloud account unavailable: \(describe(accountStatus), privacy: .public)")
                return .unavailableAccount(describe(accountStatus))
            }
        } catch {
            logger.error("Failed to check iCloud account status: \(error.localizedDescription, privacy: .public)")
            return .failed("CloudKit account check failed.")
        }

        let records = makeSeedRecords()

        do {
            for record in records {
                let savedRecord = try await container.publicCloudDatabase.save(record)
                logger.info("Saved \(savedRecord.recordType, privacy: .public) record \(savedRecord.recordID.recordName, privacy: .public).")
            }
            try await primeSchemaQueries(in: container.publicCloudDatabase)
            userDefaults.set(true, forKey: didSeedKey)
            logger.info("Seeded public social schema with \(records.count) records.")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .cloudKitSchemaSeederDidSeedDevelopmentSchema,
                    object: nil
                )
            }
            return .seeded(recordCount: records.count)
        } catch {
            logger.error("Failed to seed public social schema: \(error.localizedDescription, privacy: .public)")
            return .failed("CloudKit schema seed failed. Check the CloudKit console logs.")
        }
    }

    private static func makeSeedRecords(referenceDate: Date = Date()) -> [CKRecord] {
        let userAOwnerRecordName = "debug-schema-seed-owner-a"
        let userBOwnerRecordName = "debug-schema-seed-owner-b"
        let userARecordID = CloudKitSocialSchema.userProfileRecordID(
            forOwnerUserRecordName: userAOwnerRecordName
        )
        let userBRecordID = CloudKitSocialSchema.userProfileRecordID(
            forOwnerUserRecordName: userBOwnerRecordName
        )

        let userA = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.userProfile,
            recordID: userARecordID
        )
        userA[CloudKitSocialSchema.Field.handle] = SeedValues.userAHandle
        userA[CloudKitSocialSchema.Field.displayName] = "Schema Seed A"
        userA[CloudKitSocialSchema.Field.createdAt] = referenceDate
        userA[CloudKitSocialSchema.Field.ownerUserRecordName] = userAOwnerRecordName

        let userB = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.userProfile,
            recordID: userBRecordID
        )
        userB[CloudKitSocialSchema.Field.handle] = SeedValues.userBHandle
        userB[CloudKitSocialSchema.Field.displayName] = "Schema Seed B"
        userB[CloudKitSocialSchema.Field.createdAt] = referenceDate
        userB[CloudKitSocialSchema.Field.ownerUserRecordName] = userBOwnerRecordName

        let userAReference = CKRecord.Reference(recordID: userARecordID, action: .none)
        let userBReference = CKRecord.Reference(recordID: userBRecordID, action: .none)

        let friendRequest = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.friendRequest,
            recordID: CKRecord.ID(recordName: SeedValues.friendRequestRecordName)
        )
        friendRequest[CloudKitSocialSchema.Field.fromUser] = userAReference
        friendRequest[CloudKitSocialSchema.Field.toUser] = userBReference
        friendRequest[CloudKitSocialSchema.Field.status] = SocialFriendRequestStatus.pending.rawValue
        friendRequest[CloudKitSocialSchema.Field.createdAt] = referenceDate
        friendRequest[CloudKitSocialSchema.Field.updatedAt] = referenceDate

        let friendEdge = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.friendEdge,
            recordID: CKRecord.ID(recordName: SeedValues.friendEdgeRecordName)
        )
        friendEdge[CloudKitSocialSchema.Field.fromUser] = userAReference
        friendEdge[CloudKitSocialSchema.Field.toUser] = userBReference
        friendEdge[CloudKitSocialSchema.Field.createdAt] = referenceDate

        let post = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.post,
            recordID: CKRecord.ID(recordName: SeedValues.postRecordName)
        )
        post[CloudKitSocialSchema.Field.authorRef] = userAReference
        post[CloudKitSocialSchema.Field.type] = SocialPostType.advice.rawValue
        post[CloudKitSocialSchema.Field.text] = "Schema seed"
        post[CloudKitSocialSchema.Field.visibility] = SocialPostVisibility.friends.rawValue
        post[CloudKitSocialSchema.Field.createdAt] = referenceDate

        let chaosScore = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.chaosScore,
            recordID: CKRecord.ID(recordName: SeedValues.chaosScoreRecordName)
        )
        chaosScore[CloudKitSocialSchema.Field.seasonId] = SeedValues.seasonID
        chaosScore[CloudKitSocialSchema.Field.userRef] = userAReference
        chaosScore[CloudKitSocialSchema.Field.score] = NSNumber(value: 13)
        chaosScore[CloudKitSocialSchema.Field.updatedAt] = referenceDate

        let collabDoc = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.collabDoc,
            recordID: CKRecord.ID(recordName: SeedValues.collabDocRecordName)
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
            recordID: CKRecord.ID(recordName: SeedValues.moderationReportRecordName)
        )
        moderationReport[CloudKitSocialSchema.Field.clientReportID] =
            SeedValues.moderationClientReportID
        moderationReport[CloudKitSocialSchema.Field.targetType] = "post"
        moderationReport[CloudKitSocialSchema.Field.targetRecordName] = post.recordID.recordName
        moderationReport[CloudKitSocialSchema.Field.reporterHandle] = SeedValues.userAHandle
        moderationReport[CloudKitSocialSchema.Field.reason] = "Schema seed"
        moderationReport[CloudKitSocialSchema.Field.createdAt] = referenceDate

        return [userA, userB, friendRequest, friendEdge, post, chaosScore, collabDoc, moderationReport]
    }

    private static func primeSchemaQueries(in database: CKDatabase) async throws {
        let userAReference = CKRecord.Reference(
            recordID: CloudKitSocialSchema.userProfileRecordID(
                forOwnerUserRecordName: "debug-schema-seed-owner-a"
            ),
            action: .none
        )
        let userBReference = CKRecord.Reference(
            recordID: CloudKitSocialSchema.userProfileRecordID(
                forOwnerUserRecordName: "debug-schema-seed-owner-b"
            ),
            action: .none
        )

        let userQuery = CKQuery(
            recordType: CloudKitSocialSchema.RecordType.userProfile,
            predicate: NSPredicate(
                format: "%K == %@",
                CloudKitSocialSchema.Field.handle,
                SeedValues.userAHandle
            )
        )

        let friendRequestQuery = CKQuery(
            recordType: CloudKitSocialSchema.RecordType.friendRequest,
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(
                    format: "%K == %@",
                    CloudKitSocialSchema.Field.toUser,
                    userBReference
                ),
                NSPredicate(
                    format: "%K == %@",
                    CloudKitSocialSchema.Field.status,
                    SocialFriendRequestStatus.pending.rawValue
                ),
            ])
        )
        friendRequestQuery.sortDescriptors = [
            NSSortDescriptor(key: CloudKitSocialSchema.Field.createdAt, ascending: false)
        ]

        let friendEdgeQuery = CKQuery(
            recordType: CloudKitSocialSchema.RecordType.friendEdge,
            predicate: NSPredicate(
                format: "%K == %@",
                CloudKitSocialSchema.Field.fromUser,
                userAReference
            )
        )
        friendEdgeQuery.sortDescriptors = [
            NSSortDescriptor(key: CloudKitSocialSchema.Field.createdAt, ascending: false)
        ]

        let postQuery = CKQuery(
            recordType: CloudKitSocialSchema.RecordType.post,
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(
                    format: "%K == %@",
                    CloudKitSocialSchema.Field.authorRef,
                    userAReference
                ),
                NSPredicate(
                    format: "%K == %@",
                    CloudKitSocialSchema.Field.visibility,
                    SocialPostVisibility.friends.rawValue
                ),
            ])
        )
        postQuery.sortDescriptors = [
            NSSortDescriptor(key: CloudKitSocialSchema.Field.createdAt, ascending: false)
        ]

        let chaosScoreQuery = CKQuery(
            recordType: CloudKitSocialSchema.RecordType.chaosScore,
            predicate: NSPredicate(
                format: "%K == %@",
                CloudKitSocialSchema.Field.seasonId,
                SeedValues.seasonID
            )
        )
        chaosScoreQuery.sortDescriptors = [
            NSSortDescriptor(key: CloudKitSocialSchema.Field.score, ascending: false),
            NSSortDescriptor(key: CloudKitSocialSchema.Field.updatedAt, ascending: true),
        ]

        let collabOwnerQuery = CKQuery(
            recordType: CloudKitSocialSchema.RecordType.collabDoc,
            predicate: NSPredicate(
                format: "%K == %@",
                CloudKitSocialSchema.Field.ownerRef,
                userAReference
            )
        )
        collabOwnerQuery.sortDescriptors = [
            NSSortDescriptor(key: CloudKitSocialSchema.Field.updatedAt, ascending: false)
        ]

        let collabContributorQuery = CKQuery(
            recordType: CloudKitSocialSchema.RecordType.collabDoc,
            predicate: NSPredicate(
                format: "ANY %K == %@",
                CloudKitSocialSchema.Field.contributorsRefs,
                userBReference
            )
        )
        collabContributorQuery.sortDescriptors = [
            NSSortDescriptor(key: CloudKitSocialSchema.Field.updatedAt, ascending: false)
        ]

        let moderationQuery = CKQuery(
            recordType: CloudKitSocialSchema.RecordType.moderationReport,
            predicate: NSPredicate(
                format: "%K == %@",
                CloudKitSocialSchema.Field.clientReportID,
                SeedValues.moderationClientReportID
            )
        )

        for (name, query) in [
            ("user-handle", userQuery),
            ("friend-request", friendRequestQuery),
            ("friend-edge", friendEdgeQuery),
            ("post-feed", postQuery),
            ("chaos-score", chaosScoreQuery),
            ("collab-owner", collabOwnerQuery),
            ("collab-contributor", collabContributorQuery),
            ("moderation-report", moderationQuery),
        ] {
            try await run(query: query, in: database)
            logger.info("Primed development schema query \(name, privacy: .public).")
        }
    }

    private static func run(query: CKQuery, in database: CKDatabase) async throws {
        let _: CKQueryOperation.Cursor? = try await withCheckedThrowingContinuation {
            continuation in
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = 1
            operation.recordMatchedBlock = { _, _ in }
            operation.queryResultBlock = { result in
                continuation.resume(with: result)
            }
            database.add(operation)
        }
    }

    private static func makeContainerForSeeding() -> CKContainer? {
        #if targetEnvironment(simulator)
            logger.info("Skipping schema seed in Simulator; CloudKit requires a signed app entitlement.")
            return nil
        #else
            return CloudKitManager.socialContainer()
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
