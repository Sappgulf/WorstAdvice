import CloudKit
import XCTest
@testable import Badvice

@MainActor
final class SocialRegressionTests: XCTestCase {
    private func makeTestUser(handle: String = "friends_test_user") -> SocialUser {
        SocialUser(
            recordID: CKRecord.ID(recordName: "test_\(handle)"),
            handle: handle,
            displayName: "Test User",
            createdAt: Date()
        )
    }

    private func awaitFriendsLoadState(
        matching predicate: @escaping (SocialLoadState) -> Bool,
        timeout: TimeInterval = 1.2,
        for viewModel: SocialViewModel
    ) async -> SocialLoadState {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate(viewModel.friendsLoadState) {
                return viewModel.friendsLoadState
            }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return viewModel.friendsLoadState
    }

    func testRetryFriendsLoadReconcilesStaleStateAfterICloudAuthLoss() async {
        let defaults = UserDefaults(suiteName: "SocialRegressionTests.AuthLost.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.authLostRegression"
        )
        let staleUser = makeTestUser(handle: "legacy_friend")
        let backend = InspectableSocialBackend(
            storedUser: staleUser,
            incomingError: CKError(.notAuthenticated)
        )
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        viewModel.currentUser = staleUser
        viewModel.incomingRequests = [
            SocialFriendRequest(
                recordID: CKRecord.ID(recordName: "req-reg-1"),
                fromUserID: CKRecord.ID(recordName: "from"),
                toUserID: staleUser.recordID,
                status: .pending,
                createdAt: Date(),
                fromUser: staleUser,
                toUser: staleUser
            )
        ]
        viewModel.outgoingRequests = [
            SocialFriendRequest(
                recordID: CKRecord.ID(recordName: "req-reg-2"),
                fromUserID: staleUser.recordID,
                toUserID: CKRecord.ID(recordName: "to"),
                status: .pending,
                createdAt: Date(),
                fromUser: staleUser,
                toUser: staleUser
            )
        ]
        viewModel.friends = [staleUser]
        viewModel.blockedUsers = [makeTestUser(handle: "blocked_friend")]

        await viewModel.retryFriendsLoad()
        let terminalState = await awaitFriendsLoadState(
            matching: {
                if case .failed = $0 { return true }
                return false
            },
            for: viewModel
        )

        XCTAssertNil(viewModel.currentUser)
        XCTAssertTrue(viewModel.incomingRequests.isEmpty)
        XCTAssertTrue(viewModel.outgoingRequests.isEmpty)
        XCTAssertTrue(viewModel.friends.isEmpty)
        XCTAssertTrue(viewModel.blockedUsers.isEmpty)
        XCTAssertFalse(viewModel.socialFeaturesEnabled)
        if case .failed(let message) = terminalState {
            XCTAssertEqual(
                message,
                "iCloud is not signed in. Open Settings, sign in to iCloud, then retry."
            )
        } else {
            XCTFail("Expected failed friends load after stale-auth loss. got: \(terminalState)")
        }
    }
}
