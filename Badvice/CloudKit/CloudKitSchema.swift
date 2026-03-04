import CloudKit
import Foundation
import OSLog

enum CloudKitSocialConfig {
    static let containerIdentifier = "iCloud.com.worstadvice.app"
    static let schemaSetupDocPath = "docs/cloudkit_schema_setup.md"

    static var environmentName: String {
        #if DEBUG
            return "Development"
        #else
            return "Production"
        #endif
    }
}

enum CloudKitManager {
    static func socialContainer() -> CKContainer {
        CKContainer(identifier: CloudKitSocialConfig.containerIdentifier)
    }

    static func socialDatabase(container: CKContainer = socialContainer()) -> CKDatabase {
        container.publicCloudDatabase
    }

    static let socialDatabaseScope = "Public"
}

#if DEBUG
    enum CloudKitDebugSanityChecker {
        private static let logger = Logger(subsystem: "com.worstadvice.app", category: "cloudkit.sanity")

        static func runFriendsReachabilityCheck() async {
            let container = CloudKitManager.socialContainer()
            let database = CloudKitManager.socialDatabase(container: container)

            do {
                let status = try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<CKAccountStatus, Error>) in
                    container.accountStatus { status, error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }
                        continuation.resume(returning: status)
                    }
                }
                logger.info(
                    "Friends CloudKit sanity accountStatus=\(String(describing: status), privacy: .public) databaseScope=\(CloudKitManager.socialDatabaseScope, privacy: .public)"
                )
            } catch {
                logger.error(
                    "Friends CloudKit sanity account status failed: \(error.localizedDescription, privacy: .public)"
                )
            }

            let query = CKQuery(
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                predicate: NSPredicate(
                    format: "%K == %@",
                    CloudKitSocialSchema.Field.handle,
                    "test"
                )
            )
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = 1
            operation.desiredKeys = [CloudKitSocialSchema.Field.handle]
            operation.recordMatchedBlock = { _, _ in }
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    logger.info(
                        "Friends CloudKit sanity query completed for handle=test scope=\(CloudKitManager.socialDatabaseScope, privacy: .public)"
                    )
                case .failure(let error):
                    logger.error(
                        "Friends CloudKit sanity query failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
            database.add(operation)
        }
    }
#endif

enum CloudKitSocialSchema {
    enum RecordType {
        static let userProfile = "UserProfile"
        static let friendRequest = "FriendRequest"
        static let friendEdge = "FriendEdge"
        static let post = "Post"
        static let chaosScore = "ChaosScore"
        static let collabDoc = "CollabDoc"
        static let moderationReport = "ModerationReport"
    }

    enum Field {
        // UserProfile
        static let handle = "handle"
        static let displayName = "displayName"
        static let createdAt = "createdAt"
        static let ownerUserRecordName = "ownerUserRecordName"
        static let avatarAsset = "avatarAsset"

        // FriendRequest / FriendEdge
        static let fromUser = "fromUser"
        static let toUser = "toUser"
        static let status = "status"

        // Post
        static let authorRef = "authorRef"
        static let type = "type"
        static let text = "text"
        static let visibility = "visibility"

        // ChaosScore
        static let seasonId = "seasonId"
        static let userRef = "userRef"
        static let score = "score"
        static let updatedAt = "updatedAt"

        // CollabDoc
        static let ownerRef = "ownerRef"
        static let contributorsRefs = "contributorsRefs"
        static let content = "content"
        static let version = "version"

        // ModerationReport
        static let clientReportID = "clientReportID"
        static let targetType = "targetType"
        static let targetRecordName = "targetRecordName"
        static let reporterHandle = "reporterHandle"
        static let reason = "reason"
    }

    static let coreFriendsRecordTypes = [
        RecordType.userProfile,
        RecordType.friendRequest,
        RecordType.friendEdge,
    ]

    static let coreFriendsFieldsByRecordType: [(recordType: String, fields: [String])] = [
        (
            RecordType.userProfile,
            [
                Field.handle,
                Field.displayName,
                Field.createdAt,
                Field.ownerUserRecordName,
            ]
        ),
        (
            RecordType.friendRequest,
            [
                Field.fromUser,
                Field.toUser,
                Field.status,
                Field.createdAt,
                Field.updatedAt,
            ]
        ),
        (
            RecordType.friendEdge,
            [
                Field.fromUser,
                Field.toUser,
                Field.createdAt,
            ]
        ),
    ]

    static func userProfileRecordID(forOwnerUserRecordName ownerUserRecordName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "UserProfile_\(ownerUserRecordName)")
    }
}

enum SocialHandleNormalizer {
    private static let allowedScalars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._")

    static func normalize(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutAtPrefix = String(trimmed.drop { $0 == "@" })
        return withoutAtPrefix.lowercased()
    }

    static func isValid(_ handle: String) -> Bool {
        guard (3...16).contains(handle.count) else { return false }
        return handle.unicodeScalars.allSatisfy { allowedScalars.contains($0) }
    }

    static func displayName(_ displayName: String?, fallbackHandle: String) -> String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return fallbackHandle
        }
        return String(trimmed.prefix(40))
    }
}
