import CloudKit
import Foundation
import Observation
import OSLog
import SwiftUI

@MainActor
@Observable
final class SocialViewModel {
    static let unavailableEnvironmentMessage = "Social features are not available yet for this build environment."

    private let cloudStore: any SocialBackend
    private let actionQueue: SocialActionQueueStore

    var availability = SocialAvailabilityState(
        isAvailable: false,
        diagnostics: .pending
    )
    var friendsLoadState: SocialLoadState = .idle
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
    var lastLeaderboardRefreshAt: Date?
    private var isBootstrapping = false
    private var isRefreshingLeaderboard = false
    private var socialRefreshGeneration: Int = 0
    @ObservationIgnored private var hasLoadedBackendDisplayName = false
    private var activeAccountEmail: String?
    private var activeLinkedSocialRecordName: String?

    init(
        cloudStore: any SocialBackend = SocialBackendFactory.make(),
        actionQueue: SocialActionQueueStore = SocialActionQueueStore()
    ) {
        self.cloudStore = cloudStore
        self.actionQueue = actionQueue
    }

    var socialFeaturesEnabled: Bool {
        availability.isAccountAvailable
            && currentUser != nil
            && friendsLoadState.allowsSocialActions
    }

    var needsProfileSetup: Bool {
        if case .needsProfileSetup = friendsLoadState {
            return true
        }
        // Don't prompt for profile setup while schema is still bootstrapping
        if case .idle = friendsLoadState { return false }
        return availability.isAccountAvailable && currentUser == nil && !isEnvironmentUnavailable
    }

    var isEnvironmentUnavailable: Bool {
        if case .failed(let message) = friendsLoadState {
            return message == Self.unavailableEnvironmentMessage
        }
        return false
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

        socialRefreshGeneration &+= 1
        let accountChanged = email != activeAccountEmail
        activeAccountEmail = email
        activeLinkedSocialRecordName = linkedSocialRecordName

        if accountChanged {
            await actionQueue.clear()
        }

        await cloudStore.setStoredCurrentUserRecordName(linkedSocialRecordName)
        clearLoadedSocialState()
        statusMessage = nil

        await reloadFriendsFlow(preservingLastError: false)
    }

    func bootstrap() async {
        guard !isBootstrapping else { return }
        isBootstrapping = true
        defer { isBootstrapping = false }
        backendDisplayName = await cloudStore.backendDisplayName()
        await reloadFriendsFlow(preservingLastError: true)
    }

    func loadBackendDisplayNameIfNeeded() async {
        guard !hasLoadedBackendDisplayName else { return }
        hasLoadedBackendDisplayName = true
        backendDisplayName = await cloudStore.backendDisplayName()
    }

    func refreshAvailability(preservingLastError: Bool = true) async {
        lastAvailabilityCheckAt = Date()
        let refreshed = await cloudStore.availabilityState()
        let lastError = preservingLastError ? availability.diagnostics.lastError : nil
        availability = refreshed.withLastError(lastError)
        if !availability.isAccountAvailable {
            clearLoadedSocialState()
            await refreshQueueDiagnostics()
            return
        }
        await refreshQueueDiagnostics()
    }

    func retryAvailabilityStatus() async {
        await reloadFriendsFlow(preservingLastError: false)
    }

    func retryFriendsLoad() async {
        await reloadFriendsFlow(preservingLastError: false)
    }

    @discardableResult
    func createProfile(
        handle: String,
        displayName: String,
        refreshAfterCreate: Bool = true
    ) async -> Bool {
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
        friendsLoadState = .bootstrappingProfile
        defer { isSubmittingAction = false }

        do {
            let creationGeneration = socialRefreshGeneration
            let user = try await cloudStore.getOrCreateCurrentUser(
                handle: normalizedHandle,
                displayName: displayName
            )
            guard creationGeneration == socialRefreshGeneration else { return false }
            currentUser = user
            statusMessage = "Profile created."
            if refreshAfterCreate {
                await refreshSocialData()
            } else {
                friendsLoadState = .ready
                Task(priority: .utility) { [weak self] in
                    await self?.refreshSocialData()
                }
            }
            return true
        } catch {
            let resolved = message(for: error)
            statusMessage = resolved
            friendsLoadState = .failed(message: resolved)
            return false
        }
    }

    private func loadCurrentUserIfAvailable() async {
        guard availability.isAccountAvailable else {
            friendsLoadState = .failed(message: availability.message)
            return
        }
        do {
            let loadGeneration = socialRefreshGeneration
            let fetchedUser = try await cloudStore.fetchCurrentUserIfStored()
            guard loadGeneration == socialRefreshGeneration else { return }
            currentUser = fetchedUser
            if currentUser != nil {
                friendsLoadState = .ready
                Task {
                    await refreshSocialData()
                }
            } else {
                resetLoadedCollections()
                friendsLoadState = .needsProfileSetup
            }
        } catch {
            handlePipelineError(error)
        }
    }

    private func clearLoadedSocialState() {
        currentUser = nil
        resetLoadedCollections()
        friendsLoadState = availability.isAccountAvailable ? .needsProfileSetup : .idle
    }

    private func resetLoadedCollections() {
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
        lastSocialRefreshAt = nil
        lastLeaderboardRefreshAt = nil
    }

    func refreshSocialData() async {
        guard availability.isAccountAvailable else {
            friendsLoadState = .failed(message: availability.message)
            return
        }
        guard currentUser != nil else {
            friendsLoadState = .needsProfileSetup
            return
        }
        guard !isRefreshingSocialData else {
            return
        }

        friendsLoadState = .loadingFriends
        isRefreshingSocialData = true
        defer { isRefreshingSocialData = false }
        let refreshGeneration = socialRefreshGeneration

        do {
            async let incoming = cloudStore.fetchIncomingFriendRequests()
            async let outgoing = cloudStore.fetchOutgoingFriendRequests()
            async let friendsResult = cloudStore.fetchFriends()
            async let blocked = cloudStore.fetchBlockedUsers()
            async let feedResult = loadOptionalSocialValue(fallback: []) {
                try await cloudStore.fetchFriendsFeed()
            }
            async let collabResult = loadOptionalSocialValue(fallback: []) {
                try await cloudStore.fetchMyCollabDocs()
            }
            async let leaderboardResult = loadOptionalSocialValue(fallback: []) {
                try await cloudStore.fetchLeaderboard(
                    seasonId: leaderboardSeasonID,
                    limit: 20
                )
            }

            incomingRequests = try await incoming
            outgoingRequests = try await outgoing
            friends = try await friendsResult
            blockedUsers = try await blocked
            feedPosts = try await feedResult
            collabDocs = try await collabResult
            leaderboard = try await leaderboardResult
            guard refreshGeneration == socialRefreshGeneration else { return }
            lastSocialRefreshAt = Date()
            // Clear any transient lastError from optional fetches — the core load succeeded.
            availability = availability.withLastError(nil)
            friendsLoadState =
                incomingRequests.isEmpty
                && outgoingRequests.isEmpty
                && friends.isEmpty
                && blockedUsers.isEmpty
                ? .empty : .ready
            guard refreshGeneration == socialRefreshGeneration else { return }
            await refreshQueueDiagnostics()
            guard refreshGeneration == socialRefreshGeneration else { return }
            await drainQueuedActions()
        } catch {
            handlePipelineError(error)
        }
    }

    func retryQueuedActions() async {
        await drainQueuedActions()
    }

    func searchUserByHandle(_ handle: String) async {
        guard socialFeaturesEnabled else {
            latestSearchResult = nil
            latestSearchHandle = Self.normalizedHandle(handle)
            return
        }
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
        guard socialFeaturesEnabled else {
            return
        }
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            _ = try await cloudStore.sendFriendRequest(toUser: user)
            statusMessage = "Friend request sent."
            await refreshSocialData()
        } catch {
            if shouldQueueForRetry(error) {
                await enqueueAction(
                    payload: .friendRequest(handle: user.handle),
                    dedupeKey: "friend:\(user.handle)"
                )
                statusMessage = "Friend request queued. It will retry automatically."
            } else {
                handleSocialActionError(error)
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
            handleSocialActionError(error)
        }
    }

    func declineRequest(_ request: SocialFriendRequest) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            try await cloudStore.declineFriendRequest(request)
            statusMessage = "Friend request declined."
            await refreshSocialData()
        } catch {
            handleSocialActionError(error)
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
            handleSocialActionError(error)
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
                handleSocialActionError(error)
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
                handleSocialActionError(error)
            }
        }
    }

    func refreshLeaderboard(force: Bool = false) async {
        guard !isRefreshingLeaderboard else {
            return
        }
        if !force, let lastLeaderboardRefreshAt,
            Date().timeIntervalSince(lastLeaderboardRefreshAt) < 45
        {
            return
        }
        isRefreshingLeaderboard = true
        defer { isRefreshingLeaderboard = false }
        do {
            leaderboard = try await cloudStore.fetchLeaderboard(
                seasonId: leaderboardSeasonID,
                limit: 20
            )
            lastLeaderboardRefreshAt = Date()
        } catch {
            handleSocialActionError(error)
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
            handleSocialActionError(error)
            return nil
        }
    }

    func openCollabDoc(_ doc: SocialCollabDoc) async {
        do {
            activeCollabDoc = try await cloudStore.fetchCollabDoc(id: doc.id) ?? doc
        } catch {
            handleSocialActionError(error)
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
        if let operationError = error as? SocialCloudOperationError {
            if let diagnostic = operationError.diagnostic {
                return diagnostic.isRetryable
            }
            if let ckError = operationError.underlyingError as? CKError {
                return cloudKitRetryable(ckError)
            }
        }
        if let ckError = error as? CKError {
            return cloudKitRetryable(ckError)
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

    private func handleSocialActionError(_ error: Error) {
        if shouldClearLoadedSocialState(for: error) {
            handlePipelineError(error)
            return
        }
        statusMessage = message(for: error)
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
        guard socialFeaturesEnabled else {
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

    private func reloadFriendsFlow(preservingLastError: Bool) async {
        statusMessage = nil
        friendsLoadState = .checkingCloudKit
        await refreshAvailability(preservingLastError: preservingLastError)
        guard availability.isAccountAvailable else {
            friendsLoadState = .failed(message: availability.message)
            return
        }
        await loadCurrentUserIfAvailable()
    }

    private func handlePipelineError(_ error: Error) {
        if let socialError = error as? SocialError {
            switch socialError {
            case .missingProfile:
                currentUser = nil
                resetLoadedCollections()
                statusMessage = nil
                friendsLoadState = .needsProfileSetup
                return
            default:
                break
            }
        }
        if shouldClearLoadedSocialState(for: error) {
            currentUser = nil
            resetLoadedCollections()
        }
        // Schema not deployed yet — stamp diagnostic for debugging but stay idle so
        // users never see a scary error. The seeder will bootstrap the schema and post
        // a notification that triggers retryFriendsLoad() automatically.
        let opDiagnostic = (error as? SocialCloudOperationError)?.diagnostic
        if let ckErr = cloudKitError(from: error),
            isEnvironmentUnavailableError(ckErr, diagnostic: opDiagnostic)
        {
            if let opDiagnostic {
                availability = availability.withLastError(opDiagnostic)
            }
            friendsLoadState = .idle
            return
        }
        let resolved = message(for: error)
        statusMessage = resolved
        friendsLoadState = .failed(message: resolved)
    }

    private func shouldClearLoadedSocialState(for error: Error) -> Bool {
        if let socialError = error as? SocialError {
            switch socialError {
            case .iCloudUnavailable:
                return true
            default:
                break
            }
        }
        guard let ckError = cloudKitError(from: error) else { return false }
        switch ckError.code {
        case .notAuthenticated, .permissionFailure:
            return true
        default:
            return false
        }
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
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            if shouldClearLoadedSocialState(for: error) {
                throw error
            }
            let suppressed = shouldSuppressOptionalSocialSchemaError(error)
            if !suppressed {
                // Only surface non-schema errors in the status message; don't
                // update availability.lastError for optional-fetch failures so
                // we don't show a persistent "last request failed" banner after
                // a successful core refresh.
                statusMessage = localizedDescription(for: error)
            }
            return fallback
        }
    }

    /// Produces a human-readable error string without the side effect of
    /// stamping availability.lastError. Use this for non-critical, optional
    /// social fetch failures.
    private func localizedDescription(for error: Error) -> String {
        if let socialError = error as? SocialError, let description = socialError.errorDescription {
            return description
        }
        if let operationError = error as? SocialCloudOperationError,
            let ckError = operationError.underlyingError as? CKError
        {
            return cloudKitMessage(for: ckError, diagnostic: operationError.diagnostic)
        }
        if let ckError = error as? CKError {
            return cloudKitMessage(for: ckError, diagnostic: nil)
        }
        return (error as NSError?)?.localizedDescription ?? "Something went wrong."
    }

    private func shouldSuppressOptionalSocialSchemaError(_ error: Error) -> Bool {
        guard let ckError = cloudKitError(from: error) else { return false }
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
        if let operationError = error as? SocialCloudOperationError {
            if let diagnostic = operationError.diagnostic {
                availability = availability.withLastError(diagnostic)
            }
            if let ckError = operationError.underlyingError as? CKError {
                return cloudKitMessage(for: ckError, diagnostic: operationError.diagnostic)
            }
        }
        if let ckError = error as? CKError {
            let diagnostic = SocialCloudKitErrorDiagnostic.make(
                from: ckError,
                context: .generic(operation: "friends"),
                isRetryable: cloudKitRetryable(ckError)
            )
            availability = availability.withLastError(diagnostic)
            return cloudKitMessage(for: ckError, diagnostic: diagnostic)
        }
        if let localized = (error as NSError?)?.localizedDescription, !localized.isEmpty {
            return localized
        }
        return "Something went wrong. Please try again."
    }

    private func cloudKitMessage(
        for error: CKError,
        diagnostic: SocialCloudKitErrorDiagnostic? = nil
    ) -> String {
        if isEnvironmentUnavailableError(error, diagnostic: diagnostic) {
            return Self.unavailableEnvironmentMessage
        }
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
            return currentUser == nil
                ? "Finish setting up your Friends profile to continue."
                : "Some Friends data is unavailable right now."
        case .quotaExceeded, .limitExceeded:
            return "CloudKit storage limits were reached. Free up iCloud storage and try again."
        case .accountTemporarilyUnavailable, .zoneNotFound, .userDeletedZone:
            return "CloudKit is not ready right now. Check your network and retry."
        default:
            return error.localizedDescription
        }
    }

    private func cloudKitError(from error: Error) -> CKError? {
        if let operationError = error as? SocialCloudOperationError {
            return operationError.underlyingError as? CKError
        }
        return error as? CKError
    }

    private func cloudKitRetryable(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy,
            .requestRateLimited, .notAuthenticated, .accountTemporarilyUnavailable:
            return true
        default:
            return false
        }
    }

    private func isEnvironmentUnavailableError(
        _ error: CKError,
        diagnostic: SocialCloudKitErrorDiagnostic?
    ) -> Bool {
        let details = error.localizedDescription.lowercased()
        let recordType = diagnostic?.recordType ?? ""
        if details.contains("production schema")
            || details.contains("cannot create new type")
            || details.contains("queryable")
            || details.contains("index")
            || details.contains("field")
        {
            return true
        }
        if error.code == .unknownItem,
            CloudKitSocialSchema.coreFriendsRecordTypes.contains(recordType)
        {
            return true
        }
        return false
    }
}

// MARK: - Feed Reactions (#1)
// In-memory reaction state on SocialViewModel + helper methods.

extension SocialViewModel {

    // Keyed by post recordName → array of reactions from all users
    var postReactions: [String: [FeedReaction]] {
        get { _postReactions }
    }

    // Uses a stored property via associated-object pattern — backed by a simple dictionary
    // on the ViewModel since @Observable doesn't support stored extension properties.
    // Instead, reactions are owned by SocialViewModel's private backing dict defined below.

    func reactToPost(postID: String, reaction: SocialReactionType) {
        let handle = currentUser?.handle ?? "anon"
        var bucket = _postReactions[postID, default: []]

        // Toggle: remove existing reaction of same type from same user
        if let idx = bucket.firstIndex(where: { $0.userHandle == handle && $0.type == reaction }) {
            bucket.remove(at: idx)
        } else {
            // Remove any previous reaction type from this user for this post (one reaction per user)
            bucket.removeAll { $0.userHandle == handle }
            bucket.append(FeedReaction(id: UUID(), postID: postID, userHandle: handle, type: reaction, createdAt: Date()))
        }
        _postReactions[postID] = bucket
    }

    func currentUserReaction(for postID: String) -> SocialReactionType? {
        let handle = currentUser?.handle ?? ""
        return _postReactions[postID]?.first { $0.userHandle == handle }?.type
    }

    func reactionCount(for postID: String, type: SocialReactionType) -> Int {
        _postReactions[postID]?.filter { $0.type == type }.count ?? 0
    }
}

// Backing storage for reactions — a simple var on a global actor-isolated dictionary.
// In production this would persist to CloudKit via a PostReaction record type.
// Since Swift doesn't allow stored properties in extensions, we use a nonisolated static cache.
private var _allPostReactions: [ObjectIdentifier: [String: [FeedReaction]]] = [:]

extension SocialViewModel {
    fileprivate var _postReactions: [String: [FeedReaction]] {
        get { _allPostReactions[ObjectIdentifier(self)] ?? [:] }
        set { _allPostReactions[ObjectIdentifier(self)] = newValue }
    }
}

// MARK: - FeedReactionBar (#1)
// Reusable reaction bar view for the friend feed.



struct FeedReactionBar: View {
    let postID: String
    @Bindable var social: SocialViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SocialReactionType.allCases, id: \.self) { type in
                reactionButton(for: type)
            }
        }
    }

    private func reactionButton(for type: SocialReactionType) -> some View {
        let count = social.reactionCount(for: postID, type: type)
        let isSelected = social.currentUserReaction(for: postID) == type

        return Button {
            social.reactToPost(postID: postID, reaction: type)
            HapticsManager.play(style: .light, isEnabled: true)
        } label: {
            HStack(spacing: 3) {
                Text(type.emoji).font(.body)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(Theme.springSnappy, value: count)
    }
}
