import CloudKit
import Foundation
import Observation

@MainActor
@Observable
final class SocialViewModel {
    private let cloudStore: any SocialBackend
    private let actionQueue: SocialActionQueueStore

    var availability = SocialAvailabilityState(
        isAvailable: false,
        diagnostics: .pending
    )
    var currentUser: SocialUser?
    var incomingRequests: [SocialFriendRequest] = []
    var outgoingRequests: [SocialFriendRequest] = []
    var friends: [SocialUser] = []
    var blockedUsers: [SocialUser] = []
    var feedPosts: [SocialPost] = []
    var leaderboard: [SocialChaosScore] = []
    var collabDocs: [SocialCollabDoc] = []
    var pendingCollabDraft: SocialCollabDraft?
    var activeCollabDoc: SocialCollabDoc?
    var collabConflictMessage: String?

    var isRefreshingSocialData = false
    var isSubmittingAction = false
    var statusMessage: String?
    var latestSearchResult: SocialUser?
    var latestSearchHandle: String = ""
    var leaderboardSeasonID: String = SocialViewModel.currentSeasonID()
    var backendDisplayName: String = "Unknown"
    var queuedActionCount: Int = 0
    var queuedModerationReportCount: Int = 0
    var lastAvailabilityCheckAt: Date?
    var lastQueueDrainAt: Date?
    var lastQueueDrainError: String?
    var lastSocialRefreshAt: Date?
    private var activeAccountEmail: String?
    private var activeLinkedSocialRecordName: String?

    init(
        cloudStore: any SocialBackend = SocialBackendFactory.make(),
        actionQueue: SocialActionQueueStore = SocialActionQueueStore()
    ) {
        self.cloudStore = cloudStore
        self.actionQueue = actionQueue
        Task { [weak self] in
            await self?.bootstrap()
        }
    }

    var socialFeaturesEnabled: Bool {
        availability.isAccountAvailable && currentUser != nil
    }

    static func currentSeasonID(referenceDate: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return "S1-\(formatter.string(from: referenceDate))"
    }

    static func normalizedHandle(_ value: String) -> String {
        SocialHandleNormalizer.normalize(value)
    }

    func applyAuthContext(email: String?, linkedSocialRecordName: String?) async {
        guard email != activeAccountEmail || linkedSocialRecordName != activeLinkedSocialRecordName else {
            return
        }

        let accountChanged = email != activeAccountEmail
        activeAccountEmail = email
        activeLinkedSocialRecordName = linkedSocialRecordName

        if accountChanged {
            await actionQueue.clear()
        }

        await cloudStore.setStoredCurrentUserRecordName(linkedSocialRecordName)
        clearLoadedSocialState()
        statusMessage = nil

        await refreshAvailability()
        await loadCurrentUserIfAvailable()
    }

    func bootstrap() async {
        backendDisplayName = await cloudStore.backendDisplayName()
        await refreshAvailability()
        await refreshQueueDiagnostics()
        await loadCurrentUserIfAvailable()
    }

    func refreshAvailability(preservingLastError: Bool = true) async {
        lastAvailabilityCheckAt = Date()
        let refreshed = await cloudStore.availabilityState()
        let lastError = preservingLastError ? availability.diagnostics.lastError : nil
        availability = refreshed.withLastError(lastError)
        if !availability.isAccountAvailable {
            currentUser = nil
            incomingRequests = []
            outgoingRequests = []
            friends = []
            blockedUsers = []
            feedPosts = []
            leaderboard = []
            collabDocs = []
            await refreshQueueDiagnostics()
            return
        }
        await refreshQueueDiagnostics()
        await drainQueuedActions()
    }

    func retryAvailabilityStatus() async {
        statusMessage = nil
        await refreshAvailability(preservingLastError: false)
        await loadCurrentUserIfAvailable()
    }

    @discardableResult
    func createProfile(handle: String, displayName: String) async -> Bool {
        let normalizedHandle = Self.normalizedHandle(handle)
        guard !normalizedHandle.isEmpty else {
            statusMessage = "Handle is required. Display Name is optional."
            return false
        }
        guard CloudKitStore.isValidHandle(normalizedHandle) else {
            statusMessage = SocialError.invalidHandle.localizedDescription
            return false
        }

        statusMessage = nil
        isSubmittingAction = true
        defer { isSubmittingAction = false }

        do {
            let user = try await cloudStore.getOrCreateCurrentUser(
                handle: normalizedHandle,
                displayName: displayName
            )
            currentUser = user
            statusMessage = "Profile created."
            await refreshSocialData()
            await drainQueuedActions()
            return true
        } catch {
            statusMessage = message(for: error)
            return false
        }
    }

    private func loadCurrentUserIfAvailable() async {
        guard availability.isAccountAvailable else { return }
        do {
            currentUser = try await cloudStore.fetchCurrentUserIfStored()
            if currentUser != nil {
                await refreshSocialData()
                await drainQueuedActions()
            }
        } catch {
            statusMessage = message(for: error)
        }
    }

    private func clearLoadedSocialState() {
        currentUser = nil
        incomingRequests = []
        outgoingRequests = []
        friends = []
        blockedUsers = []
        feedPosts = []
        leaderboard = []
        collabDocs = []
        pendingCollabDraft = nil
        activeCollabDoc = nil
        collabConflictMessage = nil
        latestSearchResult = nil
        latestSearchHandle = ""
    }

    func refreshSocialData() async {
        guard socialFeaturesEnabled else { return }
        isRefreshingSocialData = true
        defer { isRefreshingSocialData = false }

        do {
            async let incoming = cloudStore.fetchIncomingFriendRequests()
            async let outgoing = cloudStore.fetchOutgoingFriendRequests()
            async let friendsResult = cloudStore.fetchFriends()
            async let blocked = cloudStore.fetchBlockedUsers()

            incomingRequests = try await incoming
            outgoingRequests = try await outgoing
            friends = try await friendsResult
            blockedUsers = try await blocked
            feedPosts = await loadOptionalSocialValue(fallback: []) {
                try await cloudStore.fetchFriendsFeed()
            }
            collabDocs = await loadOptionalSocialValue(fallback: []) {
                try await cloudStore.fetchMyCollabDocs()
            }
            leaderboard = await loadOptionalSocialValue(fallback: []) {
                try await cloudStore.fetchLeaderboard(
                    seasonId: leaderboardSeasonID,
                    limit: 20
                )
            }
            lastSocialRefreshAt = Date()
            await refreshQueueDiagnostics()
        } catch {
            statusMessage = message(for: error)
        }
    }

    func retryQueuedActions() async {
        await drainQueuedActions()
    }

    func searchUserByHandle(_ handle: String) async {
        latestSearchHandle = Self.normalizedHandle(handle)
        guard !latestSearchHandle.isEmpty else {
            latestSearchResult = nil
            return
        }
        do {
            latestSearchResult = try await cloudStore.findUserByHandle(latestSearchHandle)
            if latestSearchResult == nil {
                statusMessage = "No user found for @\(latestSearchHandle)"
            }
        } catch {
            statusMessage = message(for: error)
        }
    }

    func sendFriendRequest(to user: SocialUser) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            _ = try await cloudStore.sendFriendRequest(toUser: user)
            statusMessage = "Friend request sent."
            outgoingRequests = try await cloudStore.fetchOutgoingFriendRequests()
        } catch {
            if shouldQueueForRetry(error) {
                await enqueueAction(
                    payload: .friendRequest(handle: user.handle),
                    dedupeKey: "friend:\(user.handle)"
                )
                statusMessage = "Friend request queued. It will retry automatically."
            } else {
                statusMessage = message(for: error)
            }
        }
    }

    func acceptRequest(_ request: SocialFriendRequest) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            try await cloudStore.acceptFriendRequest(request)
            statusMessage = "Friend request accepted."
            await refreshSocialData()
        } catch {
            statusMessage = message(for: error)
        }
    }

    func declineRequest(_ request: SocialFriendRequest) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            try await cloudStore.declineFriendRequest(request)
            statusMessage = "Friend request declined."
            incomingRequests = try await cloudStore.fetchIncomingFriendRequests()
        } catch {
            statusMessage = message(for: error)
        }
    }

    func block(_ user: SocialUser) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            try await cloudStore.blockUser(user)
            statusMessage = "@\(user.handle) blocked."
            await refreshSocialData()
        } catch {
            statusMessage = message(for: error)
        }
    }

    func shareAdviceToFriends(text: String) async {
        await shareToFriends(text: text, type: .advice)
    }

    func shareQuoteToFriends(text: String) async {
        await shareToFriends(text: text, type: .quote)
    }

    private func shareToFriends(text: String, type: SocialPostType) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            _ = try await cloudStore.createPost(type: type, text: text)
            statusMessage = "Shared with friends."
            feedPosts = try await cloudStore.fetchFriendsFeed()
        } catch {
            if shouldQueueForRetry(error) {
                await enqueueAction(
                    payload: .sharePost(type: type, text: text),
                    dedupeKey: nil
                )
                statusMessage = "Share queued. It will retry automatically."
            } else {
                statusMessage = message(for: error)
            }
        }
    }

    func submitChaosScore(_ score: Int64) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            try await cloudStore.submitChaosScore(seasonId: leaderboardSeasonID, score: score)
            leaderboard = try await cloudStore.fetchLeaderboard(
                seasonId: leaderboardSeasonID,
                limit: 20
            )
            statusMessage = "Score submitted."
        } catch {
            if shouldQueueForRetry(error) {
                await enqueueAction(
                    payload: .chaosScore(seasonId: leaderboardSeasonID, score: score),
                    dedupeKey: nil
                )
                statusMessage = "Score queued. It will retry automatically."
            } else {
                statusMessage = message(for: error)
            }
        }
    }

    func refreshLeaderboard() async {
        do {
            leaderboard = try await cloudStore.fetchLeaderboard(
                seasonId: leaderboardSeasonID,
                limit: 20
            )
        } catch {
            statusMessage = message(for: error)
        }
    }

    func queueCollabDraft(type: SocialPostType, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingCollabDraft = SocialCollabDraft(type: type, content: String(trimmed.prefix(2_000)))
    }

    func createCollabDoc(
        docID: String? = nil,
        type: SocialPostType,
        content: String,
        contributors: [SocialUser],
        expectedVersion: Int64? = nil
    ) async -> SocialCollabDoc? {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            let doc = try await cloudStore.createOrUpdateCollabDoc(
                docID: docID,
                type: type,
                content: content,
                contributorIDs: contributors.map(\.recordID),
                expectedVersion: expectedVersion
            )
            activeCollabDoc = doc
            pendingCollabDraft = nil
            collabConflictMessage = nil
            collabDocs = try await cloudStore.fetchMyCollabDocs()
            statusMessage = docID == nil ? "Collab created." : "Collab saved."
            return doc
        } catch SocialError.versionConflict {
            collabConflictMessage = SocialError.versionConflict(current: 0).localizedDescription
            if let docID {
                activeCollabDoc = try? await cloudStore.fetchCollabDoc(id: docID)
            }
            return nil
        } catch {
            statusMessage = message(for: error)
            return nil
        }
    }

    func openCollabDoc(_ doc: SocialCollabDoc) async {
        do {
            activeCollabDoc = try await cloudStore.fetchCollabDoc(id: doc.id) ?? doc
        } catch {
            statusMessage = message(for: error)
            activeCollabDoc = doc
        }
    }

    func report(post: SocialPost) {
        let reporter = currentUser?.handle ?? "unknown"
        SocialReportLogger.log("post=\(post.id) reporter=@\(reporter)")
        let report = SocialModerationReport(
            id: UUID().uuidString,
            targetType: .post,
            targetRecordName: post.id,
            reporterHandle: reporter,
            reason: nil,
            createdAt: Date()
        )
        Task {
            await enqueueAction(
                payload: .moderationReport(report),
                dedupeKey: "report:\(report.id)"
            )
        }
        statusMessage = "Report noted. Thanks."
    }

    func report(user: SocialUser) {
        let reporter = currentUser?.handle ?? "unknown"
        SocialReportLogger.log("user=@\(user.handle) reporter=@\(reporter)")
        let report = SocialModerationReport(
            id: UUID().uuidString,
            targetType: .user,
            targetRecordName: user.id,
            reporterHandle: reporter,
            reason: nil,
            createdAt: Date()
        )
        Task {
            await enqueueAction(
                payload: .moderationReport(report),
                dedupeKey: "report:\(report.id)"
            )
        }
        statusMessage = "Report noted. Thanks."
    }

    private func shouldQueueForRetry(_ error: Error) -> Bool {
        if let socialError = error as? SocialError {
            switch socialError {
            case .rateLimited, .iCloudUnavailable:
                return true
            case .missingProfile, .invalidHandle, .handleTaken, .userNotFound, .cannotFriendYourself,
                .duplicateRequest, .permissionDenied, .versionConflict, .invalidRecord:
                return false
            }
        }
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy,
                .requestRateLimited, .notAuthenticated, .accountTemporarilyUnavailable:
                return true
            default:
                return false
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func enqueueAction(payload: SocialQueuedActionPayload, dedupeKey: String?) async {
        let action = SocialQueuedAction(
            id: UUID(),
            dedupeKey: dedupeKey,
            createdAt: Date(),
            nextRetryAt: Date(),
            attemptCount: 0,
            payload: payload
        )
        await actionQueue.enqueue(action)
        await refreshQueueDiagnostics()
        await drainQueuedActions()
    }

    private func drainQueuedActions() async {
        guard availability.isAvailable else {
            await refreshQueueDiagnostics()
            return
        }

        let ready = await actionQueue.readyActions(limit: 12)
        guard !ready.isEmpty else {
            await refreshQueueDiagnostics()
            return
        }

        for action in ready {
            do {
                try await execute(action: action)
                await actionQueue.markSucceeded(id: action.id)
                lastQueueDrainError = nil
            } catch {
                if shouldQueueForRetry(error) {
                    let retryAt = Date().addingTimeInterval(retryDelay(forAttempt: action.attemptCount))
                    await actionQueue.reschedule(id: action.id, retryAt: retryAt)
                    lastQueueDrainError = message(for: error)
                } else {
                    await actionQueue.markSucceeded(id: action.id)
                    lastQueueDrainError = nil
                }
            }
        }

        lastQueueDrainAt = Date()
        await refreshQueueDiagnostics()
    }

    private func retryDelay(forAttempt attempt: Int) -> TimeInterval {
        let boundedAttempt = max(0, min(attempt, 8))
        return min(900, pow(2.0, Double(boundedAttempt)) * 5.0)
    }

    private func execute(action: SocialQueuedAction) async throws {
        switch action.payload {
        case .friendRequest(let handle):
            guard let target = try await cloudStore.findUserByHandle(handle) else {
                throw SocialError.userNotFound
            }
            _ = try await cloudStore.sendFriendRequest(toUser: target)
        case .sharePost(let type, let text):
            _ = try await cloudStore.createPost(type: type, text: text)
        case .chaosScore(let seasonId, let score):
            try await cloudStore.submitChaosScore(seasonId: seasonId, score: score)
        case .moderationReport(let report):
            try await cloudStore.submitModerationReport(report)
        }
    }

    private func refreshQueueDiagnostics() async {
        queuedActionCount = await actionQueue.totalCount()
        queuedModerationReportCount = await actionQueue.pendingModerationReportCount()
    }

    private func loadOptionalSocialValue<T>(
        fallback: T,
        operation: () async throws -> T
    ) async -> T {
        do {
            return try await operation()
        } catch {
            let resolvedMessage = message(for: error)
            if !shouldSuppressOptionalSocialSchemaError(error) {
                statusMessage = resolvedMessage
            }
            return fallback
        }
    }

    private func shouldSuppressOptionalSocialSchemaError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        guard
            ckError.code == .invalidArguments
                || ckError.code == .constraintViolation
                || ckError.code == .serverRejectedRequest
                || ckError.code == .unknownItem
        else {
            return false
        }
        let details = ckError.localizedDescription.lowercased()
        return details.contains("cannot create new type")
            || details.contains("production schema")
            || details.contains("queryable")
            || details.contains("index")
            || details.contains("field")
            || details.contains("unknown item")
    }

    private func message(for error: Error) -> String {
        if let socialError = error as? SocialError, let description = socialError.errorDescription {
            return description
        }
        if let ckError = error as? CKError {
            availability = availability.withLastError(
                SocialCloudKitErrorDiagnostic.make(from: ckError, context: "friends")
            )
            return cloudKitMessage(for: ckError)
        }
        if let localized = (error as NSError?)?.localizedDescription, !localized.isEmpty {
            return localized
        }
        return "Something went wrong. Please try again."
    }

    private func cloudKitMessage(for error: CKError) -> String {
        switch error.code {
        case .notAuthenticated:
            return "iCloud is not signed in. Open Settings, sign in to iCloud, then retry."
        case .permissionFailure:
            return "CloudKit permissions are not configured for this build. Check iCloud capability and container access in Xcode."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy, .requestRateLimited:
            return "CloudKit is temporarily unavailable. Check your network and retry."
        case .invalidArguments, .constraintViolation, .serverRejectedRequest:
            return error.localizedDescription
        case .unknownItem:
            return "CloudKit social records are not initialized yet. Try again in a moment."
        case .quotaExceeded, .limitExceeded:
            return "CloudKit storage limits were reached. Free up iCloud storage and try again."
        case .accountTemporarilyUnavailable, .zoneNotFound, .userDeletedZone:
            return "CloudKit is not ready right now. Check your network and retry."
        default:
            return error.localizedDescription
        }
    }
}
