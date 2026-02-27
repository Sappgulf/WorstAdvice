import CloudKit
import XCTest
@testable import Badvice

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
}
