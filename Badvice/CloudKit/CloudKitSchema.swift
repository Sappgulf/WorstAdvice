import CloudKit
import Foundation

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
                Field.avatarAsset,
            ]
        ),
        (
            RecordType.friendRequest,
            [
                Field.fromUser,
                Field.toUser,
                Field.status,
                Field.createdAt,
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

    static func userProfileRecordID(forHandle handle: String) -> CKRecord.ID {
        CKRecord.ID(recordName: SocialHandleNormalizer.normalize(handle))
    }
}

enum SocialHandleNormalizer {
    private static let allowedScalars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._")

    static func normalize(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutAtPrefix = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let lowercase = withoutAtPrefix.lowercased()
        let filteredScalars = lowercase.unicodeScalars.filter { allowedScalars.contains($0) }
        let filtered = String(String.UnicodeScalarView(filteredScalars))
        return String(filtered.prefix(16))
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
