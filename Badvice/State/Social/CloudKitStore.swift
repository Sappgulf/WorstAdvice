import CloudKit
import Foundation
import OSLog

private let cloudKitLogger = Logger(subsystem: "com.worstadvice.app", category: "cloudkit.friends")

actor CloudKitStore: SocialBackend {
    private enum FriendRequestDirection {
        case incoming
        case outgoing
    }

    private let container: CKContainer
    private let publicDB: CKDatabase
    private let userDefaults: UserDefaults

    private let currentUserRecordNameKey = "social.currentUserRecordName.v1"
    private let friendRequestRateLimitKey = "social.rate.friendRequest"
    private let postRateLimitKey = "social.rate.post"

    private var cachedCurrentUser: SocialUser?
    private var cachedFriendIDs: (ids: [CKRecord.ID], fetchedAt: Date)?
    private var cachedFeed: (posts: [SocialPost], fetchedAt: Date)?

    private let friendCacheTTL: TimeInterval = 120
    private let feedCacheTTL: TimeInterval = 45

    init(
        container: CKContainer? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        let resolvedContainer = container ?? CloudKitManager.socialContainer()
        self.container = resolvedContainer
        self.publicDB = CloudKitManager.socialDatabase(container: resolvedContainer)
        self.userDefaults = userDefaults
        let resolvedContainerIdentifier =
            resolvedContainer.containerIdentifier ?? CloudKitSocialConfig.containerIdentifier
        cloudKitLogger.info(
            "CloudKit container identifier used: \(resolvedContainerIdentifier, privacy: .public). Expected capability: \(CloudKitSocialConfig.containerIdentifier, privacy: .public)."
        )
        cloudKitLogger.info(
            "CloudKit social backend configured with \(Self.databaseDescription(for: self.publicDB), privacy: .public)."
        )
    }

    func backendDisplayName() async -> String {
        "CloudKit"
    }

    func setStoredCurrentUserRecordName(_ recordName: String?) async {
        cachedCurrentUser = nil
        invalidateFriendCaches()
        if let recordName, !recordName.isEmpty {
            userDefaults.set(recordName, forKey: currentUserRecordNameKey)
        } else {
            userDefaults.removeObject(forKey: currentUserRecordNameKey)
        }
    }

    func availabilityState() async -> SocialAvailabilityState {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-force-social-unavailable") {
            return makeAvailabilityState(
                accountStatus: nil,
                lastError: SocialCloudKitErrorDiagnostic(
                    operation: "ui-test",
                    domain: CKError.errorDomain,
                    code: "unavailable",
                    localizedDescription: "Social features are unavailable in this test run.",
                    recordType: nil,
                    recordNames: [],
                    normalizedHandle: nil,
                    predicateSummary: nil,
                    fieldNames: [],
                    sortKeys: [],
                    containerIdentifier: currentContainerIdentifier(),
                    databaseScope: CloudKitManager.socialDatabaseScope,
                    environmentName: CloudKitSocialConfig.environmentName,
                    isRetryable: false,
                    partialFailureDetails: [],
                    debugUserInfo: nil
                )
            )
        }
        do {
            let status = try await accountStatus()
            cloudKitLogger.info(
                "CloudKit account status result: \(Self.accountStatusDescription(status), privacy: .public)"
            )
            return makeAvailabilityState(accountStatus: status)
        } catch {
            Self.logCloudKitError(error, context: "account status lookup")
            return makeAvailabilityState(
                accountStatus: .couldNotDetermine,
                lastError: SocialCloudKitErrorDiagnostic.make(
                    from: error,
                    context: makeOperationContext(operation: "accountStatus"),
                    isRetryable: false
                )
            )
        }
    }

    func fetchCurrentUserIfStored() async throws -> SocialUser? {
        if let cachedCurrentUser {
            return cachedCurrentUser
        }
        if let recordName = userDefaults.string(forKey: currentUserRecordNameKey),
            !recordName.isEmpty
        {
            let recordID = CKRecord.ID(recordName: recordName)
            do {
                guard let record = try await fetchRecord(
                    recordID: recordID,
                    desiredKeys: CloudKitSocialSchema.Projection.userProfile,
                    allowsMissingRecord: true,
                    operation: "loadStoredCurrentUserProfile",
                    recordType: CloudKitSocialSchema.RecordType.userProfile,
                    fieldNames: CloudKitSocialSchema.Projection.userProfile
                ) else {
                    userDefaults.removeObject(forKey: currentUserRecordNameKey)
                    cachedCurrentUser = nil
                    return try await findCurrentUserByOwnerRecordName()
                }
                let user = try socialUser(from: record)
                cachedCurrentUser = user
                return user
            } catch {
                userDefaults.removeObject(forKey: currentUserRecordNameKey)
                cachedCurrentUser = nil
                return try await findCurrentUserByOwnerRecordName()
            }
        }
        return try await findCurrentUserByOwnerRecordName()
    }

    func getOrCreateCurrentUser(handle: String, displayName: String?) async throws -> SocialUser {
        let normalizedHandle = normalizeHandle(handle)
        guard Self.isValidHandle(normalizedHandle) else {
            throw SocialError.invalidHandle
        }

        debugLogProfileSetup(
            "start normalizedHandle=\(normalizedHandle) recordType=\(CloudKitSocialSchema.RecordType.userProfile)"
        )
        let ownerUserRecordName = try await fetchCurrentICloudUserRecordName()
        debugLogProfileSetup(
            "resolved ownerUserRecordName=\(ownerUserRecordName) normalizedHandle=\(normalizedHandle)"
        )
        if let existingCurrentUser = try await findCurrentUserByOwnerRecordName() {
            await setStoredCurrentUserRecordName(existingCurrentUser.recordID.recordName)
            cachedCurrentUser = existingCurrentUser
            debugLogProfileSetup(
                "found existing current profile recordID=\(existingCurrentUser.recordID.recordName) normalizedHandle=\(normalizedHandle)"
            )
            return existingCurrentUser
        }

        let handleAvailabilityPredicate = NSPredicate(
            format: "%K == %@",
            CloudKitSocialSchema.Field.handle,
            normalizedHandle
        )
        debugLogProfileSetup(
            "checking handle availability normalizedHandle=\(normalizedHandle) predicate=\(handleAvailabilityPredicate.predicateFormat)"
        )
        let existingHandleMatches = try await queryUserProfilesByHandle(
            normalizedHandle,
            resultsLimit: 2,
            operation: "checkHandleAvailability",
            desiredKeys: CloudKitSocialSchema.Projection.userProfile
        )
        if let existingHandleRecord = existingHandleMatches.first {
            let existingHandleOwner =
                existingHandleRecord[CloudKitSocialSchema.Field.ownerUserRecordName] as? String
            if existingHandleOwner == ownerUserRecordName {
                let user = try socialUser(from: existingHandleRecord)
                await setStoredCurrentUserRecordName(user.recordID.recordName)
                cachedCurrentUser = user
                debugLogProfileSetup(
                    "reused profile matched by handle recordID=\(user.recordID.recordName) normalizedHandle=\(normalizedHandle)"
                )
                return user
            }
            debugLogProfileSetup(
                "handle unavailable normalizedHandle=\(normalizedHandle) conflictingRecordID=\(existingHandleRecord.recordID.recordName)"
            )
            throw SocialError.handleTaken
        }

        let record = CKRecord(recordType: CloudKitSocialSchema.RecordType.userProfile)
        record[CloudKitSocialSchema.Field.handle] = normalizedHandle
        record[CloudKitSocialSchema.Field.displayName] =
            normalizedDisplayName(displayName, handle: normalizedHandle)
        record[CloudKitSocialSchema.Field.createdAt] = Date()
        record[CloudKitSocialSchema.Field.ownerUserRecordName] = ownerUserRecordName
        let savedFieldNames = record.allKeys().sorted()
        debugLogProfileSetup(
            "saving profile normalizedHandle=\(normalizedHandle) recordType=\(record.recordType) fields=\(savedFieldNames.joined(separator: ",")) recordID=\(record.recordID.recordName)"
        )
        let saved: CKRecord
        do {
            saved = try await save(record: record, savePolicy: .allKeys)
            debugLogProfileSetup(
                "save succeeded normalizedHandle=\(normalizedHandle) recordID=\(saved.recordID.recordName) fields=\(saved.allKeys().sorted().joined(separator: ","))"
            )
        } catch {
            debugLogProfileSetupError(
                stage: "saveProfile",
                error: error,
                normalizedHandle: normalizedHandle,
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                recordID: record.recordID,
                fieldNames: savedFieldNames
            )
            throw error
        }

        await setStoredCurrentUserRecordName(saved.recordID.recordName)

        let user = await resolveCreatedCurrentUser(
            fromSavedRecord: saved,
            normalizedHandle: normalizedHandle,
            ownerUserRecordName: ownerUserRecordName
        )
        cachedCurrentUser = user
        userDefaults.set(user.recordID.recordName, forKey: currentUserRecordNameKey)
        debugLogProfileSetup(
            "profile setup completed normalizedHandle=\(normalizedHandle) recordID=\(user.recordID.recordName)"
        )
        return user
    }

    func isHandleTaken(_ handle: String) async throws -> Bool {
        let normalizedHandle = normalizeHandle(handle)
        guard Self.isValidHandle(normalizedHandle) else { return true }

        let matchingRecords = try await queryUserProfilesByHandle(
            normalizedHandle,
            resultsLimit: 4,
            operation: "checkHandleAvailability",
            desiredKeys: CloudKitSocialSchema.Projection.userProfile
        )
        guard let current = try await fetchCurrentUserIfStored() else {
            return !matchingRecords.isEmpty
        }
        return matchingRecords.contains(where: { $0.recordID != current.recordID })
    }

    func findUserByHandle(_ handle: String) async throws -> SocialUser? {
        let normalizedHandle = normalizeHandle(handle)
        guard Self.isValidHandle(normalizedHandle) else { return nil }
        let first = try await queryUserProfilesByHandle(
            normalizedHandle,
            resultsLimit: 1,
            operation: "findUserByHandle",
            desiredKeys: CloudKitSocialSchema.Projection.userProfile
        ).first
        guard let first else { return nil }
        return try socialUser(from: first)
    }

    func sendFriendRequest(toUser target: SocialUser) async throws -> SocialFriendRequest {
        let current = try await requireCurrentUser()
        guard current.recordID != target.recordID else {
            throw SocialError.cannotFriendYourself
        }

        if try await fetchRecord(recordID: friendEdgeRecordID(a: current.recordID, b: target.recordID)) != nil
        {
            throw SocialError.duplicateRequest
        }

        guard consumeRateBudget(
            key: "\(friendRequestRateLimitKey).\(current.recordID.recordName)",
            maxCount: 5,
            interval: 60
        ) else {
            throw SocialError.rateLimited("Too many friend requests. Try again in a minute.")
        }

        let currentRef = CKRecord.Reference(recordID: current.recordID, action: .none)
        let targetRef = CKRecord.Reference(recordID: target.recordID, action: .none)
        let blockingStatuses = Set([
            SocialFriendRequestStatus.pending,
            .accepted,
            .blocked,
        ])
        let allRequests = try await allFriendRequestRecords()
        let existingOutgoing = allRequests.filter { record in
            guard
                let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
                let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference,
                let statusRaw = record[CloudKitSocialSchema.Field.status] as? String,
                let status = SocialFriendRequestStatus(rawValue: statusRaw)
            else {
                return false
            }
            return fromRef.recordID == currentRef.recordID
                && toRef.recordID == targetRef.recordID
                && blockingStatuses.contains(status)
        }
        guard existingOutgoing.isEmpty else {
            throw SocialError.duplicateRequest
        }
        let existingIncoming = allRequests.filter { record in
            guard
                let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
                let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference,
                let statusRaw = record[CloudKitSocialSchema.Field.status] as? String,
                let status = SocialFriendRequestStatus(rawValue: statusRaw)
            else {
                return false
            }
            return fromRef.recordID == targetRef.recordID
                && toRef.recordID == currentRef.recordID
                && blockingStatuses.contains(status)
        }
        if existingIncoming.contains(where: {
            ($0[CloudKitSocialSchema.Field.status] as? String) == SocialFriendRequestStatus.blocked.rawValue
        }) {
            throw SocialError.permissionDenied
        }
        guard existingIncoming.isEmpty else {
            throw SocialError.duplicateRequest
        }

        let record = CKRecord(recordType: CloudKitSocialSchema.RecordType.friendRequest)
        let now = Date()
        record[CloudKitSocialSchema.Field.fromUser] = currentRef
        record[CloudKitSocialSchema.Field.toUser] = targetRef
        record[CloudKitSocialSchema.Field.status] = SocialFriendRequestStatus.pending.rawValue
        record[CloudKitSocialSchema.Field.createdAt] = now
        record[CloudKitSocialSchema.Field.updatedAt] = now

        let saved = try await save(record: record, savePolicy: .allKeys)
        return SocialFriendRequest(
            recordID: saved.recordID,
            fromUserID: current.recordID,
            toUserID: target.recordID,
            status: .pending,
            createdAt: saved[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date(),
            fromUser: current,
            toUser: target
        )
    }

    func fetchIncomingFriendRequests() async throws -> [SocialFriendRequest] {
        let current = try await requireCurrentUser()
        let records = try await relevantFriendRequests(
            for: current,
            direction: .incoming,
            statuses: [.pending]
        )
        return try await friendRequests(from: records)
    }

    func fetchOutgoingFriendRequests() async throws -> [SocialFriendRequest] {
        let current = try await requireCurrentUser()
        let records = try await relevantFriendRequests(
            for: current,
            direction: .outgoing,
            statuses: [.pending]
        )
        return try await friendRequests(from: records)
    }

    func acceptFriendRequest(_ request: SocialFriendRequest) async throws {
        let current = try await requireCurrentUser()
        guard let record = try await fetchRecord(recordID: request.recordID),
            let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
            let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference
        else {
            throw SocialError.invalidRecord
        }
        guard toRef.recordID == current.recordID else {
            throw SocialError.permissionDenied
        }

        record[CloudKitSocialSchema.Field.status] = SocialFriendRequestStatus.accepted.rawValue
        record[CloudKitSocialSchema.Field.updatedAt] = Date()
        _ = try await save(record: record)

        let now = Date()
        try await upsertFriendEdge(a: fromRef.recordID, b: toRef.recordID, since: now)
        try await upsertFriendEdge(a: toRef.recordID, b: fromRef.recordID, since: now)
        invalidateFriendCaches()
    }

    func declineFriendRequest(_ request: SocialFriendRequest) async throws {
        let current = try await requireCurrentUser()
        guard let record = try await fetchRecord(recordID: request.recordID),
            let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference
        else {
            throw SocialError.invalidRecord
        }
        guard toRef.recordID == current.recordID else {
            throw SocialError.permissionDenied
        }
        record[CloudKitSocialSchema.Field.status] = SocialFriendRequestStatus.rejected.rawValue
        record[CloudKitSocialSchema.Field.updatedAt] = Date()
        _ = try await save(record: record)
    }

    func blockUser(_ user: SocialUser) async throws {
        let current = try await requireCurrentUser()
        guard current.recordID != user.recordID else { return }

        let currentRef = CKRecord.Reference(recordID: current.recordID, action: .none)
        let targetRef = CKRecord.Reference(recordID: user.recordID, action: .none)
        let existing = try await relevantFriendRequests(
            for: current,
            direction: .outgoing,
            statuses: nil
        ).filter { record in
            guard
                let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
                let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference
            else {
                return false
            }
            return fromRef.recordID == currentRef.recordID && toRef.recordID == targetRef.recordID
        }

        let record: CKRecord
        if let first = existing.first {
            record = first
        } else {
            record = CKRecord(recordType: CloudKitSocialSchema.RecordType.friendRequest)
            record[CloudKitSocialSchema.Field.fromUser] = currentRef
            record[CloudKitSocialSchema.Field.toUser] = targetRef
            record[CloudKitSocialSchema.Field.createdAt] = Date()
        }
        record[CloudKitSocialSchema.Field.status] = SocialFriendRequestStatus.blocked.rawValue
        record[CloudKitSocialSchema.Field.updatedAt] = Date()
        _ = try await save(record: record, savePolicy: .allKeys)

        try await deleteRecords(recordIDs: [
            friendEdgeRecordID(a: current.recordID, b: user.recordID),
            friendEdgeRecordID(a: user.recordID, b: current.recordID),
        ])
        invalidateFriendCaches()
    }

    func fetchBlockedUsers() async throws -> [SocialUser] {
        let current = try await requireCurrentUser()
        let records = try await relevantFriendRequests(
            for: current,
            direction: .outgoing,
            statuses: [.blocked]
        )
        let targetIDs = records.compactMap {
            ($0[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference)?.recordID
        }
        let usersByID = try await usersByID(for: targetIDs)
        return targetIDs.compactMap { usersByID[$0] }
    }

    func fetchFriends() async throws -> [SocialUser] {
        let friendIDs = try await fetchFriendRecordIDs()
        let usersByID = try await usersByID(for: friendIDs)
        return friendIDs.compactMap { usersByID[$0] }.sorted {
            $0.handle.localizedCaseInsensitiveCompare($1.handle) == .orderedAscending
        }
    }

    func createPost(type: SocialPostType, text: String) async throws -> SocialPost {
        let current = try await requireCurrentUser()
        guard consumeRateBudget(
            key: "\(postRateLimitKey).\(current.recordID.recordName)",
            maxCount: 6,
            interval: 60
        ) else {
            throw SocialError.rateLimited("Posting is temporarily limited. Try again in a minute.")
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.invalidRecord }
        let record = CKRecord(recordType: CloudKitSocialSchema.RecordType.post)
        record[CloudKitSocialSchema.Field.authorRef] = CKRecord.Reference(
            recordID: current.recordID,
            action: .none
        )
        record[CloudKitSocialSchema.Field.type] = type.rawValue
        record[CloudKitSocialSchema.Field.text] = String(trimmed.prefix(480))
        record[CloudKitSocialSchema.Field.visibility] = SocialPostVisibility.friends.rawValue
        record[CloudKitSocialSchema.Field.createdAt] = Date()

        let saved = try await save(record: record, savePolicy: .allKeys)
        cachedFeed = nil
        return SocialPost(
            recordID: saved.recordID,
            authorUserID: current.recordID,
            author: current,
            type: type,
            text: saved[CloudKitSocialSchema.Field.text] as? String ?? trimmed,
            visibility: .friends,
            createdAt: saved[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date()
        )
    }

    func submitModerationReport(_ report: SocialModerationReport) async throws {
        let recordID = CKRecord.ID(recordName: "modreport_\(report.id)")
        let record = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.moderationReport,
            recordID: recordID
        )
        record[CloudKitSocialSchema.Field.clientReportID] = report.id
        record[CloudKitSocialSchema.Field.targetType] = report.targetType.rawValue
        record[CloudKitSocialSchema.Field.targetRecordName] = report.targetRecordName
        record[CloudKitSocialSchema.Field.reporterHandle] = report.reporterHandle
        record[CloudKitSocialSchema.Field.reason] = report.reason
        record[CloudKitSocialSchema.Field.createdAt] = report.createdAt
        _ = try await save(record: record, savePolicy: .allKeys)
    }

    func fetchFriendsFeed() async throws -> [SocialPost] {
        if let cachedFeed, Date().timeIntervalSince(cachedFeed.fetchedAt) <= feedCacheTTL {
            return cachedFeed.posts
        }
        let friendIDs = try await fetchFriendRecordIDs()
        guard !friendIDs.isEmpty else {
            cachedFeed = ([], Date())
            return []
        }

        let references = friendIDs.map { CKRecord.Reference(recordID: $0, action: .none) }
        let predicate = NSPredicate(
            format: "%K IN %@ AND %K == %@",
            CloudKitSocialSchema.Field.authorRef,
            references,
            CloudKitSocialSchema.Field.visibility,
            SocialPostVisibility.friends.rawValue
        )
        let records = try await queryRecords(
            recordType: CloudKitSocialSchema.RecordType.post,
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: CloudKitSocialSchema.Field.createdAt, ascending: false)],
            resultsLimit: 100
        )
        let authorIDs = records.compactMap {
            ($0[CloudKitSocialSchema.Field.authorRef] as? CKRecord.Reference)?.recordID
        }
        let usersByID = try await usersByID(for: authorIDs)
        let posts = records.compactMap { record in
            socialPost(from: record, usersByID: usersByID)
        }
        .sorted { $0.createdAt > $1.createdAt }
        cachedFeed = (posts, Date())
        return posts
    }

    func submitChaosScore(seasonId: String, score: Int64) async throws {
        let current = try await requireCurrentUser()
        let normalizedSeason = seasonId.trimmingCharacters(in: .whitespacesAndNewlines)
        let recordID = chaosScoreRecordID(seasonId: normalizedSeason, userID: current.recordID)

        let existing = try await fetchRecord(recordID: recordID)
        let record =
            existing
            ?? CKRecord(
                recordType: CloudKitSocialSchema.RecordType.chaosScore,
                recordID: recordID
            )

        let existingScoreRaw = record[CloudKitSocialSchema.Field.score]
        let existingScore = int64Value(existingScoreRaw)
        record[CloudKitSocialSchema.Field.seasonId] = normalizedSeason
        record[CloudKitSocialSchema.Field.userRef] = CKRecord.Reference(
            recordID: current.recordID,
            action: .none
        )
        record[CloudKitSocialSchema.Field.score] = max(existingScore, score)
        record[CloudKitSocialSchema.Field.updatedAt] = Date()
        _ = try await save(record: record, savePolicy: .allKeys)
    }

    func fetchLeaderboard(seasonId: String, limit: Int) async throws -> [SocialChaosScore] {
        let normalizedSeason = seasonId.trimmingCharacters(in: .whitespacesAndNewlines)
        let predicate = NSPredicate(
            format: "%K == %@",
            CloudKitSocialSchema.Field.seasonId,
            normalizedSeason
        )
        let records = try await queryRecords(
            recordType: CloudKitSocialSchema.RecordType.chaosScore,
            predicate: predicate,
            sortDescriptors: [
                NSSortDescriptor(key: CloudKitSocialSchema.Field.score, ascending: false),
                NSSortDescriptor(key: CloudKitSocialSchema.Field.updatedAt, ascending: true),
            ],
            resultsLimit: max(1, min(limit, 100))
        )
        let userIDs = records.compactMap {
            ($0[CloudKitSocialSchema.Field.userRef] as? CKRecord.Reference)?.recordID
        }
        let usersByID = try await usersByID(for: userIDs)
        return records.compactMap { socialChaosScore(from: $0, usersByID: usersByID) }
    }

    func createOrUpdateCollabDoc(
        docID: String?,
        type: SocialPostType,
        content: String,
        contributorIDs: [CKRecord.ID],
        expectedVersion: Int64?
    ) async throws -> SocialCollabDoc {
        let current = try await requireCurrentUser()
        let now = Date()
        let trimmed = String(content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4_000))
        guard !trimmed.isEmpty else { throw SocialError.invalidRecord }

        let recordID = docID.map { CKRecord.ID(recordName: $0) }
        let existing: CKRecord?
        if let recordID {
            existing = try await fetchRecord(recordID: recordID)
        } else {
            existing = nil
        }

        let record: CKRecord
        if let existing {
            record = existing
            let ownerID = (existing[CloudKitSocialSchema.Field.ownerRef] as? CKRecord.Reference)?
                .recordID
            let contributorRefs =
                existing[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? []
            let contributorIDs = Set(contributorRefs.map { $0.recordID })
            guard ownerID == current.recordID || contributorIDs.contains(current.recordID) else {
                throw SocialError.permissionDenied
            }

            let currentVersion = int64Value(existing[CloudKitSocialSchema.Field.version])
            if let expectedVersion, currentVersion > expectedVersion {
                throw SocialError.versionConflict(current: currentVersion)
            }
            record[CloudKitSocialSchema.Field.version] = currentVersion + 1
        } else {
            record =
                if let recordID {
                    CKRecord(recordType: CloudKitSocialSchema.RecordType.collabDoc, recordID: recordID)
                } else {
                    CKRecord(recordType: CloudKitSocialSchema.RecordType.collabDoc)
                }
            record[CloudKitSocialSchema.Field.ownerRef] = CKRecord.Reference(
                recordID: current.recordID,
                action: .none
            )
            record[CloudKitSocialSchema.Field.version] = Int64(1)
            record[CloudKitSocialSchema.Field.createdAt] = now
        }

        let normalizedContributors = Array(
            Set(contributorIDs.filter { $0 != current.recordID })
        )
        record[CloudKitSocialSchema.Field.contributorsRefs] = normalizedContributors.map {
            CKRecord.Reference(recordID: $0, action: .none)
        }
        record[CloudKitSocialSchema.Field.type] = type.rawValue
        record[CloudKitSocialSchema.Field.content] = trimmed
        record[CloudKitSocialSchema.Field.updatedAt] = now

        let saved = try await save(record: record, savePolicy: .allKeys)
        let ownerID =
            (saved[CloudKitSocialSchema.Field.ownerRef] as? CKRecord.Reference)?.recordID
            ?? current.recordID
        let contributorIDsSaved =
            (saved[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? [])
            .map(\.recordID)
        let usersByID = try await usersByID(for: [ownerID] + contributorIDsSaved)
        guard let doc = socialCollabDoc(from: saved, usersByID: usersByID) else {
            throw SocialError.invalidRecord
        }
        return doc
    }

    func fetchMyCollabDocs() async throws -> [SocialCollabDoc] {
        let current = try await requireCurrentUser()
        let currentRef = CKRecord.Reference(recordID: current.recordID, action: .none)

        let ownerPredicate = NSPredicate(
            format: "%K == %@",
            CloudKitSocialSchema.Field.ownerRef,
            currentRef
        )
        let contributorPredicate = NSPredicate(
            format: "ANY %K == %@",
            CloudKitSocialSchema.Field.contributorsRefs,
            currentRef
        )

        let owned = try await queryRecords(
            recordType: CloudKitSocialSchema.RecordType.collabDoc,
            predicate: ownerPredicate,
            sortDescriptors: [NSSortDescriptor(key: CloudKitSocialSchema.Field.updatedAt, ascending: false)],
            resultsLimit: 100
        )
        let contributed: [CKRecord]
        do {
            contributed = try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.collabDoc,
                predicate: contributorPredicate,
                sortDescriptors: [NSSortDescriptor(key: CloudKitSocialSchema.Field.updatedAt, ascending: false)],
                resultsLimit: 100
            )
        } catch {
            // Fallback when list-reference query support is unavailable in schema/indexes.
            let fallback = try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.collabDoc,
                predicate: NSPredicate(value: true),
                sortDescriptors: [NSSortDescriptor(key: CloudKitSocialSchema.Field.updatedAt, ascending: false)],
                resultsLimit: 200
            )
            contributed = fallback.filter { record in
                let refs =
                    (record[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? [])
                return refs.contains { $0.recordID == current.recordID }
            }
        }

        var merged: [CKRecord.ID: CKRecord] = [:]
        for record in owned + contributed {
            merged[record.recordID] = record
        }

        let records = Array(merged.values)
        let ownerIDs = records.compactMap {
            ($0[CloudKitSocialSchema.Field.ownerRef] as? CKRecord.Reference)?.recordID
        }
        let contributorIDs = records.flatMap {
            ($0[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? [])
                .map(\.recordID)
        }
        let usersByID = try await usersByID(for: ownerIDs + contributorIDs)
        return records.compactMap { socialCollabDoc(from: $0, usersByID: usersByID) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchCollabDoc(id: String) async throws -> SocialCollabDoc? {
        let recordID = CKRecord.ID(recordName: id)
        guard let record = try await fetchRecord(recordID: recordID) else { return nil }
        let ownerID = (record[CloudKitSocialSchema.Field.ownerRef] as? CKRecord.Reference)?.recordID
        let contributorIDs =
            (record[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? [])
            .map(\.recordID)
        let usersByID = try await usersByID(for: [ownerID].compactMap { $0 } + contributorIDs)
        return socialCollabDoc(from: record, usersByID: usersByID)
    }

    static func isValidHandle(_ handle: String) -> Bool {
        SocialHandleNormalizer.isValid(handle)
    }

    private func requireCurrentUser() async throws -> SocialUser {
        guard let current = try await fetchCurrentUserIfStored() else {
            throw SocialError.missingProfile
        }
        return current
    }

    private func normalizeHandle(_ handle: String) -> String {
        SocialHandleNormalizer.normalize(handle)
    }

    private func normalizedDisplayName(_ displayName: String?, handle: String) -> String {
        SocialHandleNormalizer.displayName(displayName, fallbackHandle: handle)
    }

    private func resolveCreatedCurrentUser(
        fromSavedRecord saved: CKRecord,
        normalizedHandle: String,
        ownerUserRecordName: String
    ) async -> SocialUser {
        let ownerPredicate = NSPredicate(
            format: "%K == %@",
            CloudKitSocialSchema.Field.ownerUserRecordName,
            ownerUserRecordName
        )
        do {
            debugLogProfileSetup(
                "reloading current profile by ownerUserRecordName normalizedHandle=\(normalizedHandle) predicate=\(ownerPredicate.predicateFormat)"
            )
            if let reloadedCurrentUser = try await findCurrentUserByOwnerRecordName() {
                debugLogProfileSetup(
                    "reload by ownerUserRecordName succeeded normalizedHandle=\(normalizedHandle) recordID=\(reloadedCurrentUser.recordID.recordName)"
                )
                return reloadedCurrentUser
            }
            debugLogProfileSetup(
                "reload by ownerUserRecordName returned no record normalizedHandle=\(normalizedHandle)"
            )
        } catch {
            debugLogProfileSetupError(
                stage: "reloadCurrentUserByOwnerRecordName",
                error: error,
                normalizedHandle: normalizedHandle,
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                recordID: saved.recordID,
                predicate: ownerPredicate,
                fieldNames: CloudKitSocialSchema.Projection.userProfile
            )
        }

        do {
            debugLogProfileSetup(
                "reloading current profile by recordID normalizedHandle=\(normalizedHandle) recordID=\(saved.recordID.recordName)"
            )
            if let reloadedSavedRecord = try await fetchRecord(
                recordID: saved.recordID,
                desiredKeys: CloudKitSocialSchema.Projection.userProfile,
                allowsMissingRecord: true,
                operation: "reloadCreatedCurrentUserProfile",
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                normalizedHandle: normalizedHandle,
                fieldNames: CloudKitSocialSchema.Projection.userProfile
            ) {
                debugLogProfileSetup(
                    "reload by recordID succeeded normalizedHandle=\(normalizedHandle) recordID=\(reloadedSavedRecord.recordID.recordName)"
                )
                return (try? socialUser(from: reloadedSavedRecord))
                    ?? fallbackCurrentUser(fromSavedRecord: saved, normalizedHandle: normalizedHandle)
            }
            debugLogProfileSetup(
                "reload by recordID returned no record normalizedHandle=\(normalizedHandle) recordID=\(saved.recordID.recordName)"
            )
        } catch {
            debugLogProfileSetupError(
                stage: "reloadCurrentUserByRecordID",
                error: error,
                normalizedHandle: normalizedHandle,
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                recordID: saved.recordID,
                fieldNames: CloudKitSocialSchema.Projection.userProfile
            )
        }

        return fallbackCurrentUser(fromSavedRecord: saved, normalizedHandle: normalizedHandle)
    }

    private func fallbackCurrentUser(fromSavedRecord saved: CKRecord, normalizedHandle: String) -> SocialUser {
        debugLogProfileSetup(
            "falling back to saved record after successful save normalizedHandle=\(normalizedHandle) recordID=\(saved.recordID.recordName)"
        )
        return (try? socialUser(from: saved))
            ?? SocialUser(
                recordID: saved.recordID,
                handle: normalizedHandle,
                displayName: normalizedDisplayName(
                    saved[CloudKitSocialSchema.Field.displayName] as? String,
                    handle: normalizedHandle
                ),
                createdAt: saved[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date()
            )
    }

    private func queryUserProfilesByHandle(
        _ normalizedHandle: String,
        resultsLimit: Int,
        operation: String,
        desiredKeys: [String]
    ) async throws -> [CKRecord] {
        do {
            return try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                predicate: NSPredicate(
                    format: "%K == %@",
                    CloudKitSocialSchema.Field.handle,
                    normalizedHandle
                ),
                resultsLimit: resultsLimit,
                desiredKeys: desiredKeys,
                operation: operation
            )
        } catch {
            guard shouldFallbackToFullUserScan(error) else { throw error }
            let records = try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                predicate: NSPredicate(value: true),
                resultsLimit: CKQueryOperation.maximumResults,
                desiredKeys: desiredKeys,
                operation: "\(operation)FallbackScan"
            )
            return records.filter {
                normalizeHandle(($0[CloudKitSocialSchema.Field.handle] as? String) ?? "") == normalizedHandle
            }
        }
    }

    private func allFriendRequestRecords() async throws -> [CKRecord] {
        try await queryRecords(
            recordType: CloudKitSocialSchema.RecordType.friendRequest,
            predicate: NSPredicate(value: true),
            resultsLimit: 200,
            desiredKeys: CloudKitSocialSchema.Projection.friendRequest,
            operation: "listFriendRequests"
        )
    }

    private func relevantFriendRequests(
        for current: SocialUser,
        direction: FriendRequestDirection,
        statuses: Set<SocialFriendRequestStatus>?
    ) async throws -> [CKRecord] {
        let currentRecordID = current.recordID
        return try await allFriendRequestRecords().filter { record in
            guard
                let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
                let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference,
                let statusRaw = record[CloudKitSocialSchema.Field.status] as? String,
                let status = SocialFriendRequestStatus(rawValue: statusRaw)
            else {
                return false
            }
            let matchesDirection: Bool
            switch direction {
            case .incoming:
                matchesDirection = toRef.recordID == currentRecordID
            case .outgoing:
                matchesDirection = fromRef.recordID == currentRecordID
            }
            guard matchesDirection else { return false }
            if let statuses {
                return statuses.contains(status)
            }
            return true
        }
    }

    private func consumeRateBudget(
        key: String,
        maxCount: Int,
        interval: TimeInterval
    ) -> Bool {
        let now = Date().timeIntervalSince1970
        var timestamps = (userDefaults.array(forKey: key) as? [Double]) ?? []
        timestamps = timestamps.filter { now - $0 < interval }
        guard timestamps.count < maxCount else {
            userDefaults.set(timestamps, forKey: key)
            return false
        }
        timestamps.append(now)
        userDefaults.set(timestamps, forKey: key)
        return true
    }

    private func usersByID(for recordIDs: [CKRecord.ID]) async throws -> [CKRecord.ID: SocialUser] {
        let uniqueIDs = Array(Set(recordIDs))
        guard !uniqueIDs.isEmpty else { return [:] }
        let records = try await fetchRecords(
            recordIDs: uniqueIDs,
            desiredKeys: CloudKitSocialSchema.Projection.userProfile,
            allowsMissingRecords: true
        )
        var map: [CKRecord.ID: SocialUser] = [:]
        for record in records {
            if let user = try? socialUser(from: record) {
                map[user.recordID] = user
            }
        }
        return map
    }

    private func friendRequests(from records: [CKRecord]) async throws -> [SocialFriendRequest] {
        let userIDs = records.flatMap { record -> [CKRecord.ID] in
            let fromID =
                (record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference)?.recordID
            let toID =
                (record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference)?.recordID
            return [fromID, toID].compactMap { $0 }
        }
        let usersByID = try await usersByID(for: userIDs)
        return records.compactMap { socialFriendRequest(from: $0, usersByID: usersByID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func socialUser(from record: CKRecord) throws -> SocialUser {
        guard record.recordType == CloudKitSocialSchema.RecordType.userProfile else {
            throw SocialError.invalidRecord
        }
        let handle = normalizeHandle(
            (record[CloudKitSocialSchema.Field.handle] as? String) ?? record.recordID.recordName
        )
        guard !handle.isEmpty else { throw SocialError.invalidRecord }
        let displayName =
            (record[CloudKitSocialSchema.Field.displayName] as? String)?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? handle
        let createdAt = record[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date()
        return SocialUser(
            recordID: record.recordID,
            handle: handle,
            displayName: displayName.isEmpty ? handle : displayName,
            createdAt: createdAt
        )
    }

    private func socialFriendRequest(
        from record: CKRecord,
        usersByID: [CKRecord.ID: SocialUser]
    ) -> SocialFriendRequest? {
        guard
            let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
            let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference
        else {
            return nil
        }
        guard
            let statusRaw = record[CloudKitSocialSchema.Field.status] as? String,
            let status = SocialFriendRequestStatus(rawValue: statusRaw)
        else {
            return nil
        }
        return SocialFriendRequest(
            recordID: record.recordID,
            fromUserID: fromRef.recordID,
            toUserID: toRef.recordID,
            status: status,
            createdAt: record[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date(),
            fromUser: usersByID[fromRef.recordID],
            toUser: usersByID[toRef.recordID]
        )
    }

    private func socialPost(
        from record: CKRecord,
        usersByID: [CKRecord.ID: SocialUser]
    ) -> SocialPost? {
        guard
            let authorRef = record[CloudKitSocialSchema.Field.authorRef] as? CKRecord.Reference,
            let typeRaw = record[CloudKitSocialSchema.Field.type] as? String,
            let type = SocialPostType(rawValue: typeRaw),
            let text = record[CloudKitSocialSchema.Field.text] as? String,
            let visibilityRaw = record[CloudKitSocialSchema.Field.visibility] as? String,
            let visibility = SocialPostVisibility(rawValue: visibilityRaw)
        else {
            return nil
        }
        return SocialPost(
            recordID: record.recordID,
            authorUserID: authorRef.recordID,
            author: usersByID[authorRef.recordID],
            type: type,
            text: text,
            visibility: visibility,
            createdAt: record[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date()
        )
    }

    private func socialChaosScore(
        from record: CKRecord,
        usersByID: [CKRecord.ID: SocialUser]
    ) -> SocialChaosScore? {
        guard
            let seasonID = record[CloudKitSocialSchema.Field.seasonId] as? String,
            let userRef = record[CloudKitSocialSchema.Field.userRef] as? CKRecord.Reference
        else {
            return nil
        }
        return SocialChaosScore(
            recordID: record.recordID,
            seasonId: seasonID,
            userID: userRef.recordID,
            user: usersByID[userRef.recordID],
            score: int64Value(record[CloudKitSocialSchema.Field.score]),
            updatedAt: record[CloudKitSocialSchema.Field.updatedAt] as? Date ?? Date()
        )
    }

    private func socialCollabDoc(
        from record: CKRecord,
        usersByID: [CKRecord.ID: SocialUser]
    ) -> SocialCollabDoc? {
        guard
            let ownerRef = record[CloudKitSocialSchema.Field.ownerRef] as? CKRecord.Reference,
            let typeRaw = record[CloudKitSocialSchema.Field.type] as? String,
            let type = SocialPostType(rawValue: typeRaw),
            let content = record[CloudKitSocialSchema.Field.content] as? String
        else {
            return nil
        }
        let contributorRefs =
            (record[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? [])
        let contributorIDs = contributorRefs.map(\.recordID)
        return SocialCollabDoc(
            recordID: record.recordID,
            ownerID: ownerRef.recordID,
            owner: usersByID[ownerRef.recordID],
            contributorIDs: contributorIDs,
            contributors: contributorIDs.compactMap { usersByID[$0] },
            type: type,
            content: content,
            version: int64Value(record[CloudKitSocialSchema.Field.version]),
            updatedAt: record[CloudKitSocialSchema.Field.updatedAt] as? Date ?? Date()
        )
    }

    private func fetchFriendRecordIDs() async throws -> [CKRecord.ID] {
        if let cachedFriendIDs, Date().timeIntervalSince(cachedFriendIDs.fetchedAt) <= friendCacheTTL {
            return cachedFriendIDs.ids
        }
        let current = try await requireCurrentUser()
        let currentRef = CKRecord.Reference(recordID: current.recordID, action: .none)
        let edges = try await queryRecords(
            recordType: CloudKitSocialSchema.RecordType.friendEdge,
            predicate: NSPredicate(value: true),
            resultsLimit: 500,
            desiredKeys: CloudKitSocialSchema.Projection.friendEdge,
            operation: "listFriendEdges"
        ).filter { record in
            guard let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference else {
                return false
            }
            return fromRef.recordID == currentRef.recordID
        }
        let ids = edges.compactMap {
            ($0[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference)?.recordID
        }
        cachedFriendIDs = (ids, Date())
        return ids
    }

    private func upsertFriendEdge(a: CKRecord.ID, b: CKRecord.ID, since: Date) async throws {
        let recordID = friendEdgeRecordID(a: a, b: b)
        let record = CKRecord(recordType: CloudKitSocialSchema.RecordType.friendEdge, recordID: recordID)
        record[CloudKitSocialSchema.Field.fromUser] = CKRecord.Reference(recordID: a, action: .none)
        record[CloudKitSocialSchema.Field.toUser] = CKRecord.Reference(recordID: b, action: .none)
        record[CloudKitSocialSchema.Field.createdAt] = since
        _ = try await save(record: record, savePolicy: .allKeys)
    }

    private func friendEdgeRecordID(a: CKRecord.ID, b: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "friendedge_\(a.recordName)__\(b.recordName)")
    }

    private func chaosScoreRecordID(seasonId: String, userID: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "chaosscore_\(seasonId)_\(userID.recordName)")
    }

    private func invalidateFriendCaches() {
        cachedFriendIDs = nil
        cachedFeed = nil
    }

    private func int64Value(_ value: Any?) -> Int64 {
        if let value = value as? Int64 { return value }
        if let value = value as? NSNumber { return value.int64Value }
        return 0
    }

    private func shouldFallbackToFullUserScan(_ error: Error) -> Bool {
        guard let ckError = Self.cloudKitError(from: error) else { return false }
        guard
            ckError.code == .invalidArguments
                || ckError.code == .constraintViolation
                || ckError.code == .serverRejectedRequest
        else {
            return false
        }
        let details = ckError.localizedDescription.lowercased()
        return isSchemaIndexingError(details)
    }

    private func makeAvailabilityState(
        accountStatus: CKAccountStatus?,
        lastError: SocialCloudKitErrorDiagnostic? = nil
    ) -> SocialAvailabilityState {
        SocialAvailabilityState(
            isAvailable: accountStatus == .available,
            diagnostics: SocialCloudKitDiagnostics(
                accountStatus: accountStatus,
                containerIdentifier: currentContainerIdentifier(),
                databaseScope: CloudKitManager.socialDatabaseScope,
                environmentName: CloudKitSocialConfig.environmentName,
                lastError: lastError
            )
        )
    }

    private func currentContainerIdentifier() -> String {
        container.containerIdentifier ?? CloudKitSocialConfig.containerIdentifier
    }

    private func makeOperationContext(
        operation: String,
        recordType: String? = nil,
        recordNames: [String] = [],
        normalizedHandle: String? = nil,
        predicate: NSPredicate? = nil,
        fieldNames: [String] = [],
        sortDescriptors: [NSSortDescriptor] = []
    ) -> SocialCloudKitOperationContext {
        SocialCloudKitOperationContext(
            operation: operation,
            recordType: recordType,
            recordNames: recordNames,
            normalizedHandle: normalizedHandle,
            predicateSummary: predicate?.predicateFormat,
            fieldNames: fieldNames,
            sortKeys: sortDescriptors.compactMap(\.key),
            containerIdentifier: currentContainerIdentifier(),
            databaseScope: CloudKitManager.socialDatabaseScope,
            environmentName: CloudKitSocialConfig.environmentName
        )
    }

    private static func wrapCloudKitError(_ error: Error, context: SocialCloudKitOperationContext) -> Error {
        if let wrapped = error as? SocialCloudOperationError {
            return wrapped
        }
        guard let ckError = error as? CKError else { return error }
        return SocialCloudOperationError(
            underlyingError: ckError,
            diagnostic: SocialCloudKitErrorDiagnostic.make(
                from: ckError,
                context: context,
                isRetryable: Self.isRetryableCloudKitError(ckError)
            )
        )
    }

    private func fetchCurrentICloudUserRecordName() async throws -> String {
        cloudKitLogger.info("CloudKit call start: fetchUserRecordID")
        do {
            let recordName = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<String, Error>) in
                container.fetchUserRecordID { recordID, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let recordID else {
                        continuation.resume(throwing: CKError(.notAuthenticated))
                        return
                    }
                    continuation.resume(returning: recordID.recordName)
                }
            }
            cloudKitLogger.info("CloudKit call success: fetchUserRecordID")
            return recordName
        } catch {
            Self.logCloudKitError(error, context: "fetchUserRecordID")
            throw error
        }
    }

    private func findCurrentUserByOwnerRecordName() async throws -> SocialUser? {
        let ownerUserRecordName: String
        do {
            ownerUserRecordName = try await fetchCurrentICloudUserRecordName()
        } catch {
            return nil
        }

        let records: [CKRecord]
        do {
            records = try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                predicate: NSPredicate(
                    format: "%K == %@",
                    CloudKitSocialSchema.Field.ownerUserRecordName,
                    ownerUserRecordName
                ),
                resultsLimit: 1,
                desiredKeys: CloudKitSocialSchema.Projection.userProfile,
                operation: "findCurrentUserByOwnerRecordName"
            )
        } catch {
            guard shouldFallbackToFullUserScan(error) else { throw error }
            let fallback = try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                predicate: NSPredicate(value: true),
                resultsLimit: CKQueryOperation.maximumResults,
                desiredKeys: CloudKitSocialSchema.Projection.userProfile
            )
            records = fallback.filter {
                ($0[CloudKitSocialSchema.Field.ownerUserRecordName] as? String) == ownerUserRecordName
            }
        }

        guard let record = records.first else { return nil }
        let user = try socialUser(from: record)
        cachedCurrentUser = user
        userDefaults.set(user.recordID.recordName, forKey: currentUserRecordNameKey)
        return user
    }

    private func isSchemaIndexingError(_ details: String) -> Bool {
        details.contains("queryable")
            || details.contains("index")
            || details.contains("field")
    }

    private func accountStatus() async throws -> CKAccountStatus {
        cloudKitLogger.info("CloudKit call start: accountStatus")
        do {
            let status = try await container.accountStatus()
            cloudKitLogger.info(
                "CloudKit call success: accountStatus = \(Self.accountStatusDescription(status), privacy: .public)"
            )
            return status
        } catch {
            Self.logCloudKitError(error, context: "accountStatus")
            throw error
        }
    }

    private func queryRecords(
        recordType: String,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor] = [],
        resultsLimit: Int = CKQueryOperation.maximumResults,
        desiredKeys: [String]? = nil,
        operation: String = "queryRecords"
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        let context = makeOperationContext(
            operation: operation,
            recordType: recordType,
            predicate: predicate,
            fieldNames: desiredKeys ?? [],
            sortDescriptors: sortDescriptors
        )

        do {
            cloudKitLogger.info(
                "CloudKit call start: \(operation, privacy: .public) type=\(recordType, privacy: .public) limit=\(resultsLimit)"
            )
            repeat {
                let (records, nextCursor) = try await runQuery(
                    query: cursor == nil ? query : nil,
                    cursor: cursor,
                    desiredKeys: desiredKeys,
                    resultsLimit: resultsLimit
                )
                allRecords.append(contentsOf: records)
                cursor = nextCursor
                if resultsLimit != CKQueryOperation.maximumResults,
                    allRecords.count >= resultsLimit
                {
                    return Array(allRecords.prefix(resultsLimit))
                }
            } while cursor != nil

            cloudKitLogger.info(
                "CloudKit call success: \(operation, privacy: .public) type=\(recordType, privacy: .public) count=\(allRecords.count)"
            )
            return allRecords
        } catch {
            let wrapped = Self.wrapCloudKitError(error, context: context)
            Self.logCloudKitError(wrapped, context: "\(operation)[\(recordType)]")
            throw wrapped
        }
    }

    private func runQuery(
        query: CKQuery?,
        cursor: CKQueryOperation.Cursor?,
        desiredKeys: [String]?,
        resultsLimit: Int
    ) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else if let query {
                operation = CKQueryOperation(query: query)
            } else {
                continuation.resume(throwing: SocialError.invalidRecord)
                return
            }
            operation.desiredKeys = desiredKeys
            operation.resultsLimit = resultsLimit
            var records: [CKRecord] = []
            var firstError: Error?
            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    if firstError == nil {
                        firstError = error
                    }
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let firstError {
                        continuation.resume(throwing: firstError)
                        return
                    }
                    continuation.resume(returning: (records, cursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                    return
                }
            }
            publicDB.add(operation)
        }
    }

    private func fetchRecord(
        recordID: CKRecord.ID,
        desiredKeys: [String]? = nil,
        allowsMissingRecord: Bool = false,
        operation: String = "fetchRecord",
        recordType: String? = nil,
        normalizedHandle: String? = nil,
        fieldNames: [String]? = nil
    ) async throws -> CKRecord? {
        let records = try await fetchRecords(
            recordIDs: [recordID],
            desiredKeys: desiredKeys,
            allowsMissingRecords: allowsMissingRecord,
            operation: operation,
            recordType: recordType,
            normalizedHandle: normalizedHandle,
            fieldNames: fieldNames ?? desiredKeys ?? []
        )
        return records.first
    }

    private func fetchRecords(
        recordIDs: [CKRecord.ID],
        desiredKeys: [String]? = nil,
        allowsMissingRecords: Bool = false,
        operation: String = "fetchRecords",
        recordType: String? = nil,
        normalizedHandle: String? = nil,
        fieldNames: [String] = []
    ) async throws -> [CKRecord] {
        guard !recordIDs.isEmpty else { return [] }
        let context = makeOperationContext(
            operation: operation,
            recordType: recordType,
            recordNames: recordIDs.map(\.recordName),
            normalizedHandle: normalizedHandle,
            fieldNames: fieldNames
        )
        cloudKitLogger.info(
            "CloudKit call start: \(operation, privacy: .public) count=\(recordIDs.count)"
        )
        do {
            let records = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<[CKRecord], Error>) in
                let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
                operation.desiredKeys = desiredKeys
                var recordsByID: [CKRecord.ID: CKRecord] = [:]
                var firstError: Error?
                operation.perRecordResultBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        recordsByID[recordID] = record
                    case .failure(let error):
                        if allowsMissingRecords,
                            let ckError = error as? CKError,
                            ckError.code == .unknownItem
                        {
                            return
                        }
                        if firstError == nil {
                            firstError = error
                        }
                    }
                }
                operation.fetchRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        if let firstError {
                            continuation.resume(throwing: firstError)
                            return
                        }
                        let ordered = recordIDs.compactMap { recordsByID[$0] }
                        continuation.resume(returning: ordered)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                publicDB.add(operation)
            }
            cloudKitLogger.info(
                "CloudKit call success: \(operation, privacy: .public) count=\(records.count)"
            )
            return records
        } catch {
            let wrapped = Self.wrapCloudKitError(error, context: context)
            Self.logCloudKitError(wrapped, context: operation)
            throw wrapped
        }
    }

    private func save(record: CKRecord, savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .changedKeys)
        async throws -> CKRecord
    {
        let records = try await save(records: [record], savePolicy: savePolicy)
        guard let first = records.first else {
            throw SocialError.invalidRecord
        }
        return first
    }

    private func save(
        records: [CKRecord],
        savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .changedKeys
    ) async throws -> [CKRecord] {
        guard !records.isEmpty else { return [] }
        let recordTypes = Array(Set(records.map(\.recordType))).sorted()
        let recordNames = records.map(\.recordID.recordName)
        let referencedFieldNames = Array(
            Set(records.flatMap { $0.allKeys() })
        ).sorted()
        let context = makeOperationContext(
            operation: "saveRecords",
            recordType: recordTypes.joined(separator: ","),
            recordNames: recordNames,
            fieldNames: referencedFieldNames
        )
        let perRecordContexts = Dictionary(uniqueKeysWithValues: records.map { record in
            (
                record.recordID,
                makeOperationContext(
                    operation: "saveRecord",
                    recordType: record.recordType,
                    recordNames: [record.recordID.recordName],
                    fieldNames: record.allKeys().sorted()
                )
            )
        })
        cloudKitLogger.info(
            "CloudKit call start: saveRecords count=\(records.count) database=\(Self.databaseDescription(for: self.publicDB), privacy: .public)"
        )
        do {
            let savedRecords = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<[CKRecord], Error>) in
                let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
                operation.isAtomic = false
                operation.savePolicy = savePolicy
                var savedByID: [CKRecord.ID: CKRecord] = [:]
                var firstError: Error?
                operation.perRecordSaveBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        savedByID[recordID] = record
                    case .failure(let error):
                        let wrapped = Self.wrapCloudKitError(
                            error,
                            context: perRecordContexts[recordID] ?? context
                        )
                        Self.logCloudKitError(wrapped, context: "saving record \(recordID.recordName)")
                        if firstError == nil {
                            firstError = wrapped
                        }
                    }
                }
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        if let firstError {
                            continuation.resume(throwing: firstError)
                            return
                        }
                        let ordered = records.compactMap { savedByID[$0.recordID] ?? $0 }
                        continuation.resume(returning: ordered)
                    case .failure(let error):
                        let wrapped = Self.wrapCloudKitError(error, context: context)
                        Self.logCloudKitError(wrapped, context: "finishing record save batch")
                        continuation.resume(throwing: wrapped)
                    }
                }
                publicDB.add(operation)
            }
            cloudKitLogger.info("CloudKit call success: saveRecords count=\(savedRecords.count)")
            return savedRecords
        } catch {
            let wrapped = Self.wrapCloudKitError(error, context: context)
            Self.logCloudKitError(wrapped, context: "saveRecords")
            throw wrapped
        }
    }

    private func deleteRecords(recordIDs: [CKRecord.ID]) async throws {
        guard !recordIDs.isEmpty else { return }
        let context = makeOperationContext(
            operation: "deleteRecords",
            recordNames: recordIDs.map(\.recordName)
        )
        cloudKitLogger.info("CloudKit call start: deleteRecords count=\(recordIDs.count)")
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
                operation.isAtomic = false
                var firstBlockingError: Error?
                operation.perRecordDeleteBlock = { _, result in
                    guard case .failure(let error) = result else { return }
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        return
                    }
                    if firstBlockingError == nil {
                        firstBlockingError = error
                    }
                }
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        if let firstBlockingError {
                            continuation.resume(throwing: firstBlockingError)
                        } else {
                            continuation.resume()
                        }
                    case .failure(let error):
                        if let ckError = error as? CKError, ckError.code == .unknownItem {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: Self.wrapCloudKitError(error, context: context))
                        }
                    }
                }
                publicDB.add(operation)
            }
            cloudKitLogger.info("CloudKit call success: deleteRecords count=\(recordIDs.count)")
        } catch {
            let wrapped = Self.wrapCloudKitError(error, context: context)
            Self.logCloudKitError(wrapped, context: "deleteRecords")
            throw wrapped
        }
    }

    private static func accountStatusDescription(_ status: CKAccountStatus) -> String {
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
            return "unknown(\(status.rawValue))"
        }
    }

    private static func databaseDescription(for database: CKDatabase) -> String {
        switch database.databaseScope {
        case .public:
            return "publicCloudDatabase"
        case .private:
            return "privateCloudDatabase"
        case .shared:
            return "sharedCloudDatabase"
        @unknown default:
            return "unknownDatabaseScope"
        }
    }

    private static func errorDescription(_ error: Error) -> String {
        if let ckError = cloudKitError(from: error) {
            return "CKError(\(ckError.code.rawValue)): \(ckError.localizedDescription)"
        }
        return error.localizedDescription
    }

    private func debugLogProfileSetup(_ message: String) {
        #if DEBUG
            cloudKitLogger.debug("Profile setup: \(message, privacy: .public)")
        #endif
    }

    private func debugLogProfileSetupError(
        stage: String,
        error: Error,
        normalizedHandle: String,
        recordType: String,
        recordID: CKRecord.ID? = nil,
        predicate: NSPredicate? = nil,
        fieldNames: [String] = []
    ) {
        #if DEBUG
            let wrapped = Self.wrapCloudKitError(
                error,
                context: makeOperationContext(
                    operation: stage,
                    recordType: recordType,
                    recordNames: recordID.map { [$0.recordName] } ?? [],
                    normalizedHandle: normalizedHandle,
                    predicate: predicate,
                    fieldNames: fieldNames
                )
            )
            if let operationError = wrapped as? SocialCloudOperationError,
                let diagnostic = operationError.diagnostic
            {
                cloudKitLogger.debug(
                    "Profile setup failed stage=\(stage, privacy: .public) code=\(diagnostic.code, privacy: .public) recordType=\(diagnostic.recordType ?? "n/a", privacy: .public) recordNames=\(diagnostic.recordNames.joined(separator: ","), privacy: .public) normalizedHandle=\(diagnostic.normalizedHandle ?? "n/a", privacy: .public) predicate=\(diagnostic.predicateSummary ?? "n/a", privacy: .public) fields=\(diagnostic.fieldNames.joined(separator: ","), privacy: .public) description=\(diagnostic.localizedDescription, privacy: .public)"
                )
                if !diagnostic.partialFailureDetails.isEmpty {
                    cloudKitLogger.debug(
                        "Profile setup partial failures stage=\(stage, privacy: .public): \(diagnostic.partialFailureDetails, privacy: .public)"
                    )
                }
            } else {
                cloudKitLogger.debug(
                    "Profile setup failed stage=\(stage, privacy: .public) normalizedHandle=\(normalizedHandle, privacy: .public) description=\(error.localizedDescription, privacy: .public)"
                )
            }
        #endif
    }

    private static func logCloudKitError(_ error: Error, context: String) {
        if let operationError = error as? SocialCloudOperationError,
            let diagnostic = operationError.diagnostic
        {
            cloudKitLogger.error(
                "CloudKit \(context, privacy: .public) failed op=\(diagnostic.operation, privacy: .public) code=\(diagnostic.code, privacy: .public) recordType=\(diagnostic.recordType ?? "n/a", privacy: .public) recordNames=\(diagnostic.recordNames.joined(separator: ","), privacy: .public) normalizedHandle=\(diagnostic.normalizedHandle ?? "n/a", privacy: .public) fields=\(diagnostic.fieldNames.joined(separator: ","), privacy: .public) retryable=\(diagnostic.isRetryable) description=\(diagnostic.localizedDescription, privacy: .public)"
            )
            #if DEBUG
                cloudKitLogger.debug(
                    "CloudKit diagnostic details: \(diagnostic.debugSummary, privacy: .public)"
                )
            #endif
            return
        }
        if let ckError = cloudKitError(from: error) {
            cloudKitLogger.error(
                "CloudKit \(context, privacy: .public) failed with domain=\(CKError.errorDomain, privacy: .public) code=\(ckError.code.rawValue) description=\(ckError.localizedDescription, privacy: .public)"
            )
            #if DEBUG
                cloudKitLogger.debug(
                    "CloudKit \(context, privacy: .public) CKError userInfo: \(String(describing: ckError.userInfo), privacy: .public)"
                )
            #endif
            return
        }
        cloudKitLogger.error(
            "CloudKit \(context, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
        )
    }

    private static func cloudKitError(from error: Error) -> CKError? {
        if let operationError = error as? SocialCloudOperationError {
            return operationError.underlyingError as? CKError
        }
        return error as? CKError
    }

    private static func isUnknownItemError(_ error: Error) -> Bool {
        cloudKitError(from: error)?.code == .unknownItem
    }

    private static func isRetryableCloudKitError(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy,
            .requestRateLimited, .notAuthenticated, .accountTemporarilyUnavailable:
            return true
        default:
            return false
        }
    }
}

