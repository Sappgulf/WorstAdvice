import CloudKit
import XCTest
@testable import Badvice

actor FailingProfileBackend: SocialBackend {
    let profileError: Error

    init(profileError: Error) {
        self.profileError = profileError
    }

    func backendDisplayName() async -> String { "Failing Backend" }

    func availabilityState() async -> SocialAvailabilityState {
        .available
    }

    func setStoredCurrentUserRecordName(_ recordName: String?) async {}

    func fetchCurrentUserIfStored() async throws -> SocialUser? {
        nil
    }

    func getOrCreateCurrentUser(handle: String, displayName: String?) async throws -> SocialUser {
        throw profileError
    }

    func findUserByHandle(_ handle: String) async throws -> SocialUser? {
        nil
    }

    func sendFriendRequest(toUser target: SocialUser) async throws -> SocialFriendRequest {
        throw SocialError.invalidRecord
    }

    func fetchIncomingFriendRequests() async throws -> [SocialFriendRequest] {
        []
    }

    func fetchOutgoingFriendRequests() async throws -> [SocialFriendRequest] {
        []
    }

    func acceptFriendRequest(_ request: SocialFriendRequest) async throws {
        throw SocialError.invalidRecord
    }

    func declineFriendRequest(_ request: SocialFriendRequest) async throws {
        throw SocialError.invalidRecord
    }

    func blockUser(_ user: SocialUser) async throws {
        throw SocialError.invalidRecord
    }

    func fetchBlockedUsers() async throws -> [SocialUser] {
        []
    }

    func fetchFriends() async throws -> [SocialUser] {
        []
    }

    func createPost(type: SocialPostType, text: String) async throws -> SocialPost {
        throw SocialError.invalidRecord
    }

    func fetchFriendsFeed() async throws -> [SocialPost] {
        []
    }

    func submitChaosScore(seasonId: String, score: Int64) async throws {
        throw SocialError.invalidRecord
    }

    func fetchLeaderboard(seasonId: String, limit: Int) async throws -> [SocialChaosScore] {
        []
    }

    func createOrUpdateCollabDoc(
        docID: String?,
        type: SocialPostType,
        content: String,
        contributorIDs: [CKRecord.ID],
        expectedVersion: Int64?
    ) async throws -> SocialCollabDoc {
        throw SocialError.invalidRecord
    }

    func fetchMyCollabDocs() async throws -> [SocialCollabDoc] {
        []
    }

    func fetchCollabDoc(id: String) async throws -> SocialCollabDoc? {
        nil
    }

    func submitModerationReport(_ report: SocialModerationReport) async throws {
        throw SocialError.invalidRecord
    }
}

actor InspectableSocialBackend: SocialBackend {
    private let availabilityValue: SocialAvailabilityState
    private let incomingError: Error?
    private var storedUser: SocialUser?
    private var incomingCalls = 0
    private var outgoingCalls = 0
    private var friendsCalls = 0
    private var blockedCalls = 0

    init(
        storedUser: SocialUser?,
        availabilityValue: SocialAvailabilityState = .available,
        incomingError: Error? = nil
    ) {
        self.storedUser = storedUser
        self.availabilityValue = availabilityValue
        self.incomingError = incomingError
    }

    func backendDisplayName() async -> String { "Inspectable Backend" }

    func availabilityState() async -> SocialAvailabilityState {
        availabilityValue
    }

    func setStoredCurrentUserRecordName(_ recordName: String?) async {
        guard let recordName, !recordName.isEmpty else {
            storedUser = nil
            return
        }
        if storedUser?.recordID.recordName != recordName {
            storedUser = SocialUser(
                recordID: CKRecord.ID(recordName: recordName),
                handle: "restored_\(recordName)",
                displayName: "Restored",
                createdAt: Date()
            )
        }
    }

    func fetchCurrentUserIfStored() async throws -> SocialUser? {
        storedUser
    }

    func getOrCreateCurrentUser(handle: String, displayName: String?) async throws -> SocialUser {
        if let storedUser {
            return storedUser
        }
        let normalized = SocialHandleNormalizer.normalize(handle)
        let user = SocialUser(
            recordID: CKRecord.ID(recordName: "inspectable_\(normalized)"),
            handle: normalized,
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? displayName!.trimmingCharacters(in: .whitespacesAndNewlines)
                : normalized,
            createdAt: Date()
        )
        storedUser = user
        return user
    }

    func findUserByHandle(_ handle: String) async throws -> SocialUser? {
        nil
    }

    func sendFriendRequest(toUser target: SocialUser) async throws -> SocialFriendRequest {
        throw SocialError.invalidRecord
    }

    func fetchIncomingFriendRequests() async throws -> [SocialFriendRequest] {
        incomingCalls += 1
        if let incomingError {
            throw incomingError
        }
        return []
    }

    func fetchOutgoingFriendRequests() async throws -> [SocialFriendRequest] {
        outgoingCalls += 1
        return []
    }

    func acceptFriendRequest(_ request: SocialFriendRequest) async throws {
        throw SocialError.invalidRecord
    }

    func declineFriendRequest(_ request: SocialFriendRequest) async throws {
        throw SocialError.invalidRecord
    }

    func blockUser(_ user: SocialUser) async throws {
        throw SocialError.invalidRecord
    }

    func fetchBlockedUsers() async throws -> [SocialUser] {
        blockedCalls += 1
        return []
    }

    func fetchFriends() async throws -> [SocialUser] {
        friendsCalls += 1
        return []
    }

    func createPost(type: SocialPostType, text: String) async throws -> SocialPost {
        throw SocialError.invalidRecord
    }

    func fetchFriendsFeed() async throws -> [SocialPost] {
        []
    }

    func submitChaosScore(seasonId: String, score: Int64) async throws {
        throw SocialError.invalidRecord
    }

    func fetchLeaderboard(seasonId: String, limit: Int) async throws -> [SocialChaosScore] {
        []
    }

    func createOrUpdateCollabDoc(
        docID: String?,
        type: SocialPostType,
        content: String,
        contributorIDs: [CKRecord.ID],
        expectedVersion: Int64?
    ) async throws -> SocialCollabDoc {
        throw SocialError.invalidRecord
    }

    func fetchMyCollabDocs() async throws -> [SocialCollabDoc] {
        []
    }

    func fetchCollabDoc(id: String) async throws -> SocialCollabDoc? {
        nil
    }

    func submitModerationReport(_ report: SocialModerationReport) async throws {
        throw SocialError.invalidRecord
    }

    func mandatoryFetchInvocationCount() async -> Int {
        incomingCalls + outgoingCalls + friendsCalls + blockedCalls
    }
}

@MainActor
final class SocialViewModelTests: XCTestCase {
    private func makeTestUser(handle: String = "friends_test_user") -> SocialUser {
        SocialUser(
            recordID: CKRecord.ID(recordName: "test_\(handle)"),
            handle: handle,
            displayName: "Test User",
            createdAt: Date()
        )
    }

    func testMockBackendProfileCreationSeedsIncomingRequests() async {
        let defaults = UserDefaults(suiteName: "SocialViewModelTests.Seeded.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.seeded.\(UUID().uuidString)"
        )
        let backend = UITestSocialBackend(forceUnavailable: false, seededIncomingRequests: 2)
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        await viewModel.bootstrap()
        await viewModel.createProfile(handle: "seed_test_user", displayName: "Seed Test")

        XCTAssertEqual(viewModel.currentUser?.handle, "seed_test_user")
        XCTAssertEqual(viewModel.incomingRequests.count, 2)
        XCTAssertEqual(viewModel.backendDisplayName, "UI Test Mock")
        XCTAssertTrue(viewModel.socialFeaturesEnabled)
    }

    func testReportPathQueuesAndDrainsWithMockBackend() async throws {
        let defaults = UserDefaults(suiteName: "SocialViewModelTests.Report.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.report.\(UUID().uuidString)"
        )
        let backend = UITestSocialBackend(forceUnavailable: false, seededIncomingRequests: 0)
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        await viewModel.bootstrap()
        await viewModel.createProfile(handle: "report_test_user", displayName: "Report Tester")
        let current = try XCTUnwrap(viewModel.currentUser)

        let post = SocialPost(
            recordID: CKRecord.ID(recordName: "post_report_target"),
            authorUserID: current.recordID,
            author: current,
            type: .advice,
            text: "Test",
            visibility: .friends,
            createdAt: Date()
        )

        viewModel.report(post: post)
        try await Task.sleep(for: .milliseconds(250))
        await viewModel.retryQueuedActions()

        XCTAssertEqual(viewModel.queuedModerationReportCount, 0)
        XCTAssertEqual(viewModel.queuedActionCount, 0)
        XCTAssertNotNil(viewModel.lastQueueDrainAt)
    }

    func testCreateProfileStoresProductionSchemaDiagnostic() async {
        let defaults = UserDefaults(suiteName: "SocialViewModelTests.Schema.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.schema.\(UUID().uuidString)"
        )
        let profileError = CKError(
            .serverRejectedRequest,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Error saving record. Cannot create new type User in production schema.",
            ]
        )
        let backend = FailingProfileBackend(profileError: profileError)
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        await viewModel.createProfile(handle: "frosty_app", displayName: "Frosty")

        let diagnostic = try? XCTUnwrap(viewModel.availability.diagnostics.lastError)
        XCTAssertNotNil(diagnostic)
        XCTAssertTrue(diagnostic?.code.contains("serverRejectedRequest") == true)
        XCTAssertTrue(diagnostic?.localizedDescription.contains("production schema") == true)
        XCTAssertEqual(viewModel.availability.diagnostics.containerIdentifier, CloudKitSocialConfig.containerIdentifier)
        XCTAssertEqual(viewModel.availability.diagnostics.databaseScope, CloudKitManager.socialDatabaseScope)
    }

    func testCreateProfileStoresIndexingDiagnostic() async {
        let defaults = UserDefaults(suiteName: "SocialViewModelTests.Index.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.index.\(UUID().uuidString)"
        )
        let profileError = CKError(
            .invalidArguments,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Query filter requires field handle to be marked queryable in schema index.",
            ]
        )
        let backend = FailingProfileBackend(profileError: profileError)
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        await viewModel.createProfile(handle: "frosty_app", displayName: "Frosty")

        let diagnostic = try? XCTUnwrap(viewModel.availability.diagnostics.lastError)
        XCTAssertNotNil(diagnostic)
        XCTAssertTrue(diagnostic?.code.contains("invalidArguments") == true)
        XCTAssertTrue(diagnostic?.localizedDescription.contains("queryable") == true)
    }

    func testNormalizedHandleKeepsInvalidCharactersForValidationAndLowercases() {
        XCTAssertEqual(
            SocialHandleNormalizer.normalize("  @Bad.Friend-01!! "),
            "bad.friend-01!!"
        )
        XCTAssertFalse(CloudKitStore.isValidHandle("bad.friend-01!!"))
    }

    func testNormalizedHandleKeepsOverlongInputForValidation() {
        XCTAssertEqual(
            SocialHandleNormalizer.normalize("@ABCDEFGHIJKLMNOPQRST"),
            "abcdefghijklmnopqrst"
        )
        XCTAssertFalse(CloudKitStore.isValidHandle("abcdefghijklmnopqrst"))
    }

    func testCreateProfileSanitizesHandleBeforeSaving() async {
        let defaults = UserDefaults(suiteName: "SocialViewModelTests.NormalizeCreate.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.normalizeCreate.\(UUID().uuidString)"
        )
        let backend = UITestSocialBackend(forceUnavailable: false, seededIncomingRequests: 0)
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        await viewModel.bootstrap()
        let created = await viewModel.createProfile(handle: "  @Frosty ", displayName: "Frosty")

        XCTAssertTrue(created)
        XCTAssertEqual(viewModel.currentUser?.handle, "frosty")
        XCTAssertEqual(viewModel.statusMessage, "Profile created.")
    }

    func testProfileSetupStillShowsWhenAvailabilityUnavailable() async {
        let defaults = UserDefaults(suiteName: "SocialViewModelTests.Availability.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.availability.\(UUID().uuidString)"
        )
        let backend = UITestSocialBackend(forceUnavailable: true, seededIncomingRequests: 0)
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        await viewModel.bootstrap()

        XCTAssertFalse(viewModel.availability.isAvailable)
        XCTAssertNil(viewModel.currentUser)
        XCTAssertEqual(viewModel.availability.diagnostics.accountStatus, .couldNotDetermine)
    }

    func testRetryFriendsLoadDoesNotQueryFriendsBeforeProfileExists() async {
        let defaults = UserDefaults(suiteName: "SocialViewModelTests.NoProfile.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.noProfile.\(UUID().uuidString)"
        )
        let backend = InspectableSocialBackend(storedUser: nil)
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        await viewModel.retryFriendsLoad()

        XCTAssertNil(viewModel.currentUser)
        XCTAssertEqual(viewModel.friendsLoadState, .needsProfileSetup)
        XCTAssertTrue(viewModel.needsProfileSetup)
        XCTAssertFalse(viewModel.socialFeaturesEnabled)
        let fetchCount = await backend.mandatoryFetchInvocationCount()
        XCTAssertEqual(fetchCount, 0)
    }

    func testRetryFriendsLoadTransitionsExistingProfileToEmptyState() async {
        let defaults = UserDefaults(suiteName: "SocialViewModelTests.Empty.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.empty.\(UUID().uuidString)"
        )
        let backend = InspectableSocialBackend(storedUser: makeTestUser())
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        await viewModel.retryFriendsLoad()

        XCTAssertEqual(viewModel.currentUser?.handle, "friends_test_user")
        XCTAssertEqual(viewModel.friendsLoadState, .empty)
        XCTAssertTrue(viewModel.socialFeaturesEnabled)
        XCTAssertTrue(viewModel.incomingRequests.isEmpty)
        XCTAssertTrue(viewModel.outgoingRequests.isEmpty)
        XCTAssertTrue(viewModel.friends.isEmpty)
        XCTAssertTrue(viewModel.blockedUsers.isEmpty)
    }

    func testCreateProfileTransitionsToEmptyStateAfterBootstrap() async {
        let defaults = UserDefaults(suiteName: "SocialViewModelTests.CreateThenEmpty.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.createThenEmpty.\(UUID().uuidString)"
        )
        let backend = InspectableSocialBackend(storedUser: nil)
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        let created = await viewModel.createProfile(handle: "fresh_user", displayName: "Fresh User")

        XCTAssertTrue(created)
        XCTAssertEqual(viewModel.currentUser?.handle, "fresh_user")
        XCTAssertEqual(viewModel.friendsLoadState, .empty)
        XCTAssertTrue(viewModel.socialFeaturesEnabled)
        XCTAssertEqual(viewModel.statusMessage, "Profile created.")
        let fetchCount = await backend.mandatoryFetchInvocationCount()
        XCTAssertGreaterThanOrEqual(fetchCount, 4)
    }

    func testSchemaFailureFailsSoftAndStoresOperationDiagnostics() async throws {
        let defaults = UserDefaults(suiteName: "SocialViewModelTests.OperationError.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.operationError.\(UUID().uuidString)"
        )
        let error = CKError(
            .invalidArguments,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Query filter requires field toUser to be marked queryable in schema index.",
            ]
        )
        let context = SocialCloudKitOperationContext(
            operation: "listIncomingFriendRequests",
            recordType: CloudKitSocialSchema.RecordType.friendRequest,
            predicateSummary: "toUser == currentUser AND status == pending",
            sortKeys: [CloudKitSocialSchema.Field.createdAt],
            containerIdentifier: CloudKitSocialConfig.containerIdentifier,
            databaseScope: CloudKitManager.socialDatabaseScope,
            environmentName: CloudKitSocialConfig.environmentName
        )
        let diagnostic = try XCTUnwrap(
            SocialCloudKitErrorDiagnostic.make(from: error, context: context, isRetryable: false)
        )
        let backend = InspectableSocialBackend(
            storedUser: makeTestUser(handle: "schema_user"),
            incomingError: SocialCloudOperationError(
                underlyingError: error,
                diagnostic: diagnostic
            )
        )
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        await viewModel.retryFriendsLoad()

        if case .failed(let message) = viewModel.friendsLoadState {
            XCTAssertEqual(message, SocialViewModel.unavailableEnvironmentMessage)
        } else {
            XCTFail("Expected failed Friends state for schema unavailable path")
        }
        let lastError = try XCTUnwrap(viewModel.availability.diagnostics.lastError)
        XCTAssertEqual(lastError.operation, "listIncomingFriendRequests")
        XCTAssertEqual(lastError.recordType, CloudKitSocialSchema.RecordType.friendRequest)
        XCTAssertEqual(lastError.predicateSummary, "toUser == currentUser AND status == pending")
        XCTAssertEqual(lastError.sortKeys, [CloudKitSocialSchema.Field.createdAt])
        XCTAssertEqual(lastError.containerIdentifier, CloudKitSocialConfig.containerIdentifier)
        XCTAssertEqual(lastError.databaseScope, CloudKitManager.socialDatabaseScope)
        XCTAssertFalse(lastError.isRetryable)
        XCTAssertEqual(viewModel.statusMessage, SocialViewModel.unavailableEnvironmentMessage)
    }

    func testMockBackendPreventsDuplicateFriendRequests() async throws {
        let backend = UITestSocialBackend(forceUnavailable: false, seededIncomingRequests: 0)
        let requester = try await backend.getOrCreateCurrentUser(
            handle: "requester.one",
            displayName: "Requester"
        )

        await backend.setStoredCurrentUserRecordName(nil)
        let target = try await backend.getOrCreateCurrentUser(
            handle: "target_friend",
            displayName: "Target"
        )

        await backend.setStoredCurrentUserRecordName(requester.recordID.recordName)
        _ = try await backend.sendFriendRequest(toUser: target)

        do {
            _ = try await backend.sendFriendRequest(toUser: target)
            XCTFail("Expected duplicate friend request to be rejected")
        } catch let socialError as SocialError {
            guard case .duplicateRequest = socialError else {
                XCTFail("Expected duplicateRequest, got \(socialError)")
                return
            }
        }
    }
}
