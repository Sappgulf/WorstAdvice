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

@MainActor
final class SocialViewModelTests: XCTestCase {
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

    func testCreateProfileMapsProductionSchemaErrorToActionableMessage() async {
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

        XCTAssertEqual(
            viewModel.statusMessage,
            "CloudKit production schema is missing required social record types. Deploy the Development schema to Production in CloudKit Dashboard, then try again."
        )
    }

    func testCreateProfileMapsIndexingErrorToActionableMessage() async {
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

        XCTAssertEqual(
            viewModel.statusMessage,
            "CloudKit social schema/indexes are not fully set up yet. Deploy the schema in CloudKit Dashboard, then try again."
        )
    }
}
